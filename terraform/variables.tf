
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