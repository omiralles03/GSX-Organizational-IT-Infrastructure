
output "nginx_node_port" {
  description = "El puerto externo para acceder a la aplicación"
  value       = kubernetes_service.nginx_service.spec[0].port[0].node_port
}

output "minikube_command" {
  description = "Comando para abrir el servicio automáticamente en Minikube"
  value       = "minikube service gsx-nginx-service"
}

output "app_status" {
  description = "Número de réplicas configuradas para el backend"
  value       = var.replicas_backend
}