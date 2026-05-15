# 1. PERMISOS (RBAC) PARA PROMETHEUS
resource "kubernetes_service_account" "prometheus_sa" {
  metadata { name = "prometheus-sa" }
}

resource "kubernetes_cluster_role" "prometheus_role" {
  metadata { name = "prometheus-role" }
  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus_binding" {
  metadata { name = "prometheus-binding" }
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

# 2. CONFIGURACIÓN, REGLAS DE SCRAPE Y ALERTAS (INTERMEDIATE)
resource "kubernetes_config_map" "prometheus_config" {
  metadata { name = "prometheus-config" }
  data = {
    "prometheus.yml" = <<-EOT
      global:
        scrape_interval: 10s
      rule_files:
        - "/etc/prometheus/alerts.yml"
      scrape_configs:
        # A) Scrape de tu aplicación (Request rate)
        - job_name: 'gsx-app'
          static_configs:
            - targets: ['gsx-backend-service:3000']
        
        # B) Scrape de los Nodos/Contenedores (cAdvisor: CPU y RAM)
        - job_name: 'kubernetes-cadvisor'
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            insecure_skip_verify: true
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          kubernetes_sd_configs:
            - role: node
          relabel_configs:
            - action: labelmap
              regex: __meta_kubernetes_node_label_(.+)
            - target_label: __address__
              replacement: kubernetes.default.svc:443
            - source_labels: [__meta_kubernetes_node_name]
              regex: (.+)
              target_label: __metrics_path__
              replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
    EOT

    # REGLAS DE ALERTAS (Nivel Intermediate)
    "alerts.yml" = <<-EOT
      groups:
      - name: GSX_Alerts
        rules:
        - alert: HighRequestRate
          expr: rate(http_requests_total[1m]) > 5
          for: 1m
          labels:
            severity: warning
          annotations:
            summary: "Alerta: Tráfico inusualmente alto en el Backend (>5 req/sec)"
        - alert: HighCpuUsage
          expr: sum(rate(container_cpu_usage_seconds_total{image!=""}[1m])) > 0.8
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Alerta: Consumo de CPU Crítico en el clúster"
    EOT
  }
}

# 3. DESPLIEGUE DE PROMETHEUS
resource "kubernetes_deployment" "prometheus" {
  metadata { name = "prometheus" }
  spec {
    replicas = 1
    selector { match_labels = { app = "prometheus" } }
    template {
      metadata { labels = { app = "prometheus" } }
      spec {
        service_account_name = kubernetes_service_account.prometheus_sa.metadata[0].name
        container {
          name  = "prometheus"
          image = "prom/prometheus:latest"
          port { container_port = 9090 }
          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/prometheus"
          }
        }
        volume {
          name = "config-volume"
          config_map { name = kubernetes_config_map.prometheus_config.metadata[0].name }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus_service" {
  metadata { name = "prometheus-service" }
  spec {
    selector = { app = "prometheus" }
    type     = "ClusterIP"
    port {
      port        = 9090
      target_port = 9090
    }
  }
}

# 4. DESPLIEGUE DE GRAFANA
resource "kubernetes_deployment" "grafana" {
  metadata { name = "grafana" }
  spec {
    replicas = 1
    selector { match_labels = { app = "grafana" } }
    template {
      metadata { labels = { app = "grafana" } }
      spec {
        container {
          name  = "grafana"
          image = "grafana/grafana:latest"
          port { container_port = 3000 }
          env {
            name  = "GF_SECURITY_ADMIN_USER"
            value = "admin"
          }
          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = "gsx2026"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "grafana_service" {
  metadata { name = "grafana-service" }
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