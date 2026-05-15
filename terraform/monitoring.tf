# ==============================================================================
# 1. PERMISOS RBAC Y CONFIGURACIÓN DE ALERTMANAGER
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

# Configuración de Alertmanager (Usa las variables secretas)
resource "kubernetes_config_map" "alertmanager_config" {
  metadata {
    name      = "alertmanager-config"
    namespace = "default"
  }
  data = {
    "alertmanager.yml" = <<-EOT
      global:
        smtp_smarthost: 'smtp.gmail.com:587'
        smtp_from: '${var.alert_email_sender}'
        smtp_auth_username: '${var.alert_email_sender}'
        smtp_auth_password: '${var.alert_email_password}'

      route:
        # Este nombre debe ser IGUAL al que aparece abajo en receivers
        receiver: 'gsx-team' 
        group_wait: 10s
        group_interval: 5m
        repeat_interval: 3h

      receivers:
        - name: 'gsx-team'
          email_configs:
%{for email in var.alert_email_receiver~}
            - to: '${email}'
              send_resolved: true
%{endfor~}
    EOT
  }
}

# ==============================================================================
# 2. CONFIGURACIÓN DE PROMETHEUS (SCRAPING Y REGLAS)
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
      alerting:
        alertmanagers:
          - static_configs:
            - targets: ['localhost:9093']
      scrape_configs:
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_app]
              action: keep
              regex: gsx-app
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
    "alerts.yml"     = <<-EOT
      groups:
      - name: GSX_Critical_Alerts
        rules:
        - alert: HighCPUUsage
          expr: sum(rate(container_cpu_usage_seconds_total{namespace='default'}[1m])) by (pod) * 100 > 60
          for: 30s
          labels:
            severity: critical
          annotations:
            summary: "CPU alta en el pod {{ $labels.pod }}"

        - alert: HighErrorRate
          expr: (rate(http_errors_total[1m]) / rate(http_requests_total[1m])) * 100 > 5
          for: 30s
          labels:
            severity: critical
          annotations:
            summary: "Tasa de errores > 5% detectada"
    EOT
  }
}

# ==============================================================================
# 3. APROVISIONAMIENTO DE GRAFANA
# ==============================================================================
resource "kubernetes_config_map" "grafana_provisioning" {
  metadata {
    name      = "grafana-provisioning"
    namespace = "default"
  }
  data = {
    "datasource.yml"     = <<-EOT
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://prometheus-service:9090
          isDefault: true
    EOT
    "provider.yml"       = <<-EOT
      apiVersion: 1
      providers:
        - name: 'default'
          orgId: 1
          folder: ''
          type: file
          options:
            path: /var/lib/grafana/dashboards
    EOT
    "gsx_dashboard.json" = <<-EOT
      {
        "title": "GSX Production Metrics",
        "refresh": "5s",
        "time": { "from": "now-5m", "to": "now" },
        "schemaVersion": 36,
        "panels": [
          {
            "title": "SYSTEM HEALTH STATUS",
            "type": "stat",
            "gridPos": { "h": 4, "w": 24, "x": 0, "y": 0 },
            "targets": [{ "expr": "up{job='kubernetes-pods'}" }],
            "fieldConfig": {
              "defaults": {
                "color": { "mode": "thresholds" },
                "thresholds": {
                  "mode": "absolute",
                  "steps": [{ "color": "red", "value": null }, { "color": "green", "value": 1 }]
                },
                "mappings": [{ "type": "value", "options": { "0": { "text": "CRITICAL" }, "1": { "text": "HEALTHY" } } }]
              }
            }
          },
          {
            "title": "Request Rate (Req/s)",
            "type": "timeseries",
            "gridPos": { "h": 7, "w": 8, "x": 0, "y": 4 },
            "targets": [{ "expr": "rate(http_requests_total[1m])" }]
          },
          {
            "title": "Average Latency (Seconds)",
            "type": "timeseries",
            "gridPos": { "h": 7, "w": 8, "x": 8, "y": 4 },
            "targets": [{ "expr": "rate(http_request_duration_seconds_total[1m]) / rate(http_requests_total[1m])" }]
          },
          {
            "title": "Error Rate (5xx/s)",
            "type": "timeseries",
            "gridPos": { "h": 7, "w": 8, "x": 16, "y": 4 },
            "targets": [{ "expr": "rate(http_errors_total[1m])" }]
          },
          {
            "title": "CPU Usage (%)",
            "type": "timeseries",
            "gridPos": { "h": 7, "w": 8, "x": 0, "y": 11 },
            "targets": [{ "expr": "sum(rate(container_cpu_usage_seconds_total{namespace='default'}[1m])) by (pod) * 100" }],
            "fieldConfig": { "defaults": { "unit": "percent", "min": 0, "custom": { "fillOpacity": 30 } } }
          },
          {
            "title": "Memory Usage (Bytes)",
            "type": "timeseries",
            "gridPos": { "h": 7, "w": 8, "x": 8, "y": 11 },
            "targets": [{ "expr": "sum(container_memory_working_set_bytes{namespace='default'}) by (pod)" }],
            "fieldConfig": { "defaults": { "unit": "bytes", "min": 0, "custom": { "fillOpacity": 30 } } }
          },
          {
            "title": "App Uptime (Seconds)",
            "type": "stat",
            "gridPos": { "h": 7, "w": 8, "x": 16, "y": 11 },
            "targets": [{ "expr": "app_uptime_seconds" }]
          }
        ]
      }
    EOT
  }
}

# ==============================================================================
# 4. DESPLIEGUE DE PROMETHEUS + ALERTMANAGER (SIDECAR)
# ==============================================================================
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "prometheus" }
    }
    template {
      metadata {
        labels = { app = "prometheus" }
      }
      spec {
        service_account_name = kubernetes_service_account.prometheus_sa.metadata[0].name

        # Contenedor 1: Prometheus
        container {
          name  = "prometheus"
          image = "prom/prometheus:latest"
          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus"
          }
        }

        # Contenedor 2: Alertmanager
        container {
          name  = "alertmanager"
          image = "prom/alertmanager:latest"
          port {
            container_port = 9093
          }
          volume_mount {
            name       = "am-config"
            mount_path = "/etc/alertmanager"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }
        volume {
          name = "am-config"
          config_map {
            name = kubernetes_config_map.alertmanager_config.metadata[0].name
          }
        }
      }
    }
  }
}

# ==============================================================================
# 5. DESPLIEGUE DE GRAFANA (LOGIN AUTOMÁTICO)
# ==============================================================================
resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "grafana" }
    }
    template {
      metadata {
        labels = { app = "grafana" }
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
          volume_mount {
            name       = "provisioning"
            mount_path = "/etc/grafana/provisioning/datasources/datasource.yml"
            sub_path   = "datasource.yml"
          }
          volume_mount {
            name       = "provisioning"
            mount_path = "/etc/grafana/provisioning/dashboards/provider.yml"
            sub_path   = "provider.yml"
          }
          volume_mount {
            name       = "provisioning"
            mount_path = "/var/lib/grafana/dashboards/gsx_dashboard.json"
            sub_path   = "gsx_dashboard.json"
          }
        }
        volume {
          name = "provisioning"
          config_map {
            name = kubernetes_config_map.grafana_provisioning.metadata[0].name
          }
        }
      }
    }
  }
}

# ==============================================================================
# 6. SERVICIOS
# ==============================================================================
resource "kubernetes_service" "prometheus_service" {
  metadata {
    name      = "prometheus-service"
    namespace = "default"
  }
  spec {
    selector = { app = "prometheus" }
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
    selector = { app = "grafana" }
    type     = "NodePort"
    port {
      port        = 80
      target_port = 3000
      node_port   = 30090
    }
  }
}