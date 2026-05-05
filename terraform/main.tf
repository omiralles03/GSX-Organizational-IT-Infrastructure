
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
              cpu    = "200m"
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