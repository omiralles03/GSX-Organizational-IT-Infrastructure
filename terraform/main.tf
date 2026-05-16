
# ---------------------------------------------------------
# BACKEND: Configuración, Despliegue y Servicio
# ---------------------------------------------------------

# ConfigMap para variables de entorno del Backend
resource "kubernetes_config_map" "app_config" {
  metadata {
    name = "app-config"
  }

  data = {
    PORT = "3000"
  }
}

# Deployment del Backend (Node.js)
resource "kubernetes_deployment" "app_deployment" {
  metadata {
    name = "gsx-app-deployment"
    labels = {
      app = "gsx-app"
    }
  }

  spec {
    replicas = var.replicas_backend

    selector {
      match_labels = {
        app = "gsx-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "gsx-app"
        }
      }

      spec {
        container {
          name  = "gsx-app-container"
          image = "${var.docker_username}/gsx-app:${var.app_image_tag}"

          port {
            container_port = 3000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "1500m" #1,5 nucleos
            }
          }
        }
      }
    }
  }
}

# Servicio interno para el Backend
resource "kubernetes_service" "app_service" {
  metadata {
    name = "gsx-backend-service"
  }

  spec {
    selector = {
      app = "gsx-app"
    }

    type = "ClusterIP"

    port {
      port        = 3000
      target_port = 3000
    }
  }
}

# ---------------------------------------------------------
# NGINX: Configuración, Despliegue y Servicio
# ---------------------------------------------------------

# ConfigMap con el archivo de configuración de Nginx
resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name = "nginx-config"
  }

  data = {
    "default.conf" = <<-EOT
      server {
        listen 8080;
        location / {
          root /usr/share/nginx/html;
          index index.html;
        }
        location /api/ {
          proxy_pass http://gsx-backend-service:3000/;
        }
      }
    EOT
  }
}

# Deployment del Proxy Nginx
resource "kubernetes_deployment" "nginx_deployment" {
  metadata {
    name = "nginx-deployment"
    labels = {
      app = "nginx-gsx"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx-gsx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-gsx"
        }
      }

      spec {
        container {
          name  = "nginx-container"
          image = "${var.docker_username}/nginx-gsx:${var.nginx_image_tag}"

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "nginx-config-volume"
            mount_path = "/etc/nginx/conf.d/default.conf"
            sub_path   = "default.conf"
          }
        }

        volume {
          name = "nginx-config-volume"
          config_map {
            name = kubernetes_config_map.nginx_config.metadata[0].name
          }
        }
      }
    }
  }
}

# Servicio externo NodePort para Nginx
resource "kubernetes_service" "nginx_service" {
  metadata {
    name = "gsx-nginx-service"
  }

  spec {
    selector = {
      app = "nginx-gsx"
    }

    type = "NodePort"

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8080
      node_port   = 30080
    }
  }
}

# ---------------------------------------------------------
# REDIS: Base de datos
# ---------------------------------------------------------

resource "kubernetes_deployment" "redis_deployment" {
  metadata {
    name = "redis-deployment"
    labels = {
      app = "redis"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis"
        }
      }

      spec {
        container {
          name  = "redis-container"
          image = "redis:alpine"

          port {
            container_port = 6379
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "redis_service" {
  metadata {
    name = "redis-service"
  }

  spec {
    selector = {
      app = "redis"
    }

    type = "ClusterIP"

    port {
      port        = 6379
      target_port = 6379
    }
  }
}



# POLÍTICA POR DEFECTO: Default Deny
resource "kubernetes_network_policy" "default_deny_all" {
  metadata {
    name = "default-deny-all"
  }

  spec {
    pod_selector {} # Aplica a TODOS
    policy_types = ["Ingress", "Egress"]
  }
}

# Permitir tráfico desde Nginx hacia el Backend
resource "kubernetes_network_policy" "allow_nginx_to_backend" {
  metadata {
    name = "allow-nginx-to-backend"
  }

  spec {
    pod_selector {
      match_labels = {
        app = "gsx-app" # Backend
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "nginx-gsx" # Solo si viene del Pod de Nginx
          }
        }
      }
      # También permitimos a los Developers (Rango 10.0.100.0/24) acceder para debugging
      from {
        ip_block {
          cidr = "10.0.100.0/24"
        }
      }

      ports {
        protocol = "TCP"
        port     = 3000
      }
    }
  }
}

# Permitir tráfico desde el Backend hacia la Base de Datos (Redis)
resource "kubernetes_network_policy" "allow_backend_to_redis" {
  metadata {
    name = "allow-backend-to-redis"
  }

  spec {
    pod_selector {
      match_labels = {
        app = "redis" # Selector del Pod de la Base de Datos
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "gsx-app" # Solo el backend puede hacer consultas
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = 6379
      }
    }
  }
}

# Bloquear conexiones hacia otros entornos
resource "kubernetes_network_policy" "restrict_egress_isolation" {
  metadata {
    name = "restrict-egress-isolation"
  }

  spec {
    pod_selector {} # Aplica a todos los pods del entorno

    policy_types = ["Egress"] # Trafico de salida

    egress {
      # Permite salida a cualquier lugar de Internet (ej. DNS público, actualizaciones)
      to {
        ip_block {
          cidr = "0.0.0.0/0"
          # EXCEPTO a los rangos de los otros entornos corporativos para evitar saltos laterales
          except = [
            "10.0.1.0/24", # Bloquea acceso a Desarrollo
            "10.0.3.0/24"  # Bloquea acceso a Producción
          ]
        }
      }
    }
  }
}

# ---------------------------------------------------------
# EXCEPCIONES DE OBSERVABILIDAD (Monitoreo)
# ---------------------------------------------------------

# 1. Permitir que Prometheus raspe métricas de TODOS los pods
resource "kubernetes_network_policy" "allow_prometheus_scraping" {
  metadata {
    name = "allow-prometheus-scraping"
  }

  spec {
    pod_selector {} # Destino: Se aplica a TODOS los pods del clúster

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "prometheus" # Origen: Solo permitimos que entre Prometheus
          }
        }
      }
      # No limitamos puertos específicos porque Prometheus necesita raspar muchos
    }
  }
}

# 2. Permitir que Grafana consulte los datos internos de Prometheus
resource "kubernetes_network_policy" "allow_grafana_to_prometheus" {
  metadata {
    name = "allow-grafana-to-prometheus"
  }

  spec {
    pod_selector {
      match_labels = {
        app = "prometheus"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "grafana"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = 9090
      }
    }
  }
}

# 3. Permitir acceso web externo a las interfaces de Grafana y Prometheus
resource "kubernetes_network_policy" "allow_public_to_observability" {
  metadata {
    name = "allow-public-to-observability"
  }

  spec {
    pod_selector {
      match_expressions {
        key      = "app"
        operator = "In"
        values   = ["grafana", "prometheus"]
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        ip_block {
          cidr = "0.0.0.0/0" # Permitimos que cualquiera pueda cargar la web
        }
      }
      ports {
        protocol = "TCP"
        port     = 3000 # Puerto web de Grafana
      }
      ports {
        protocol = "TCP"
        port     = 9090 # Puerto web de Prometheus
      }
    }
  }
}