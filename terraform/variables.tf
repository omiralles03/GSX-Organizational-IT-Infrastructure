
variable "docker_username" {
  description = "Nombre de usuario de Docker Hub para las imágenes"
  type        = string
}

variable "app_image_tag" {
  description = "Versión de la imagen del backend"
  type        = string
}

variable "nginx_image_tag" {
  description = "Versión de la imagen de Nginx"
  type        = string
}

variable "replicas_backend" {
  description = "Número de réplicas para el despliegue del backend"
  type        = number
  default     = 3
}

variable "grafana_admin_user" {
  description = "Usuario admin para Grafana"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Contraseña admin para Grafana"
  type        = string
  sensitive   = true
}

variable "alert_email_receiver" {
  description = "Lista de correos que recibirán las alertas"
  type        = list(string)
}

variable "alert_email_sender" {
  description = "Correo que enviará las alertas"
  type        = string
}

variable "alert_email_password" {
  description = "Contraseña de aplicación SMTP"
  type        = string
  sensitive   = true
}