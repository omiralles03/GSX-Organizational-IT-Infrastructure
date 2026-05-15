# ==============================================================================
# 1. PERMISOS (RBAC) PARA PROMETHEUS
# ==============================================================================
resource "kubernetes_service_account" "prometheus_sa" {
  metadata {
    name      = "prometheus-sa"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role" "prometheus_role" {
  metadata {
    name = "prometheus-role"
  }
  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus_binding" {
  metadata {
    name = "prometheus-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "prometheus-role"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "prometheus-sa"
    namespace = "default"
  }
}

# ==============================================================================
# 2. CONFIGURACIÓN DE PROMETHEUS Y ALERTAS
# ==============================================================================
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = "default"
  }
  data = {
    "prometheus.yml" = <<-EOT
      global:
        scrape_interval: 5s
      rule_files:
        - "/etc/prometheus/alerts.yml"
      scrape_configs:
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_app]
              action: keep
              regex: gsx-backend
            - source_labels: [__address__]
              action: replace
              regex: ([^:]+)(?::\d+)?
              replacement: $1:3000
              target_label: __address__
            - target_label: __metrics_path__
              replacement: /metrics
        - job_name: 'kubernetes-nodes'
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            insecure_skip_verify: true
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          kubernetes_sd_configs:
            - role: node
          relabel_configs:
            - target_label: __address__
              replacement: kubernetes.default.svc:443
            - source_labels: [__meta_kubernetes_node_name]
              regex: (.+)
              target_label: __metrics_path__
              replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
    EOT

    "alerts.yml" = <<-EOT
      groups:
      - name: GSX_Alerts
        rules:
        - alert: HighErrorRate
          expr: rate(http_errors_total[1m]) > 1
          for: 1m
          labels:
            severity: critical
    EOT
  }
}

# ==============================================================================
# 3. APROVISIONAMIENTO SEGURO DE GRAFANA (3 CONFIGMAPS SEPARADOS)
# ==============================================================================
resource "kubernetes_config_map" "grafana_datasource" {
  metadata {
    name      = "grafana-datasource"
    namespace = "default"
  }
  data = {
    "datasource.yml" = <<-EOT
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://prometheus-service:9090
          isDefault: true
    EOT
  }
}

resource "kubernetes_config_map" "grafana_provider" {
  metadata {
    name      = "grafana-provider"
    namespace = "default"
  }
  data = {
    "provider.yml" = <<-EOT
      apiVersion: 1
      providers:
        - name: 'default'
          orgId: 1
          folder: ''
          type: file
          options:
            path: /var/lib/grafana/dashboards/gsx
    EOT
  }
}

resource "kubernetes_config_map" "grafana_dashboard_json" {
  metadata {
    name      = "grafana-dashboard-json"
    namespace = "default"
  }
  data = {
    "gsx_dashboard.json" = <<-EOT
      {
        "title": "GSX Production Metrics",
        "refresh": "5s",
        "schemaVersion": 36,
        "panels": [
          {
            "title": "Request Rate (Req/s)",
            "type": "timeseries",
            "gridPos": { "h": 8, "w": 8, "x": 0, "y": 0 },
            "targets": [{ "expr": "rate(http_requests_total[1m])" }]
          },
          {
            "title": "Average Latency (Seconds)",
            "type": "timeseries",
            "gridPos": { "h": 8, "w": 8, "x": 8, "y": 0 },
            "targets": [{ "expr": "rate(http_request_duration_seconds_total[1m]) / rate(http_requests_total[1m])" }]
          },
          {
            "title": "Error Rate (5xx/s)",
            "type": "timeseries",
            "gridPos": { "h": 8, "w": 8, "x": 16, "y": 0 },
            "targets": [{ "expr": "rate(http_errors_total[1m])" }]
          },
          {
            "title": "CPU Usage (Nodes/Pods)",
            "type": "timeseries",
            "gridPos": { "h": 8, "w": 8, "x": 0, "y": 8 },
            "targets": [{ "expr": "sum(rate(container_cpu_usage_seconds_total{image!=''}[1m])) by (container)" }]
          },
          {
            "title": "Memory Usage (Working Set)",
            "type": "timeseries",
            "gridPos": { "h": 8, "w": 8, "x": 8, "y": 8 },
            "targets": [{ "expr": "sum(container_memory_working_set_bytes{image!=''}) by (container)" }]
          },
          {
            "title": "App Uptime (Seconds)",
            "type": "stat",
            "gridPos": { "h": 8, "w": 8, "x": 16, "y": 8 },
            "targets": [{ "expr": "app_uptime_seconds" }]
          }
        ]
      }
    EOT
  }
}

# ==============================================================================
# 4. DEPLOYMENTS Y SERVICIOS
# ==============================================================================
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.prometheus_sa.metadata[0].name
        container {
          name  = "prometheus"
          image = "prom/prometheus:latest"
          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus"
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "grafana"
      }
    }
    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }
      spec {
        container {
          name  = "grafana"
          image = "grafana/grafana:latest"

          env {
            name  = "GF_SECURITY_ADMIN_USER"
            value = var.grafana_admin_user
          }
          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = var.grafana_admin_password
          }

          # Montaje 1: Datasource
          volume_mount {
            name       = "ds-volume"
            mount_path = "/etc/grafana/provisioning/datasources"
          }

          # Montaje 2: Provider
          volume_mount {
            name       = "prov-volume"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }

          # Montaje 3: El JSON del Dashboard real
          volume_mount {
            name       = "json-volume"
            mount_path = "/var/lib/grafana/dashboards/gsx"
          }
        }

        volume {
          name = "ds-volume"
          config_map {
            name = kubernetes_config_map.grafana_datasource.metadata[0].name
          }
        }

        volume {
          name = "prov-volume"
          config_map {
            name = kubernetes_config_map.grafana_provider.metadata[0].name
          }
        }

        volume {
          name = "json-volume"
          config_map {
            name = kubernetes_config_map.grafana_dashboard_json.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus_service" {
  metadata {
    name      = "prometheus-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "prometheus"
    }
    port {
      port = 9090
    }
  }
}

resource "kubernetes_service" "grafana_service" {
  metadata {
    name      = "grafana-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "grafana"
    }
    type = "NodePort"
    port {
      port        = 80
      target_port = 3000
      node_port   = 30090
    }
  }
}