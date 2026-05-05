# archivo para indicar a que sistema se conecta terraform

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# configuración local de Minikube
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}