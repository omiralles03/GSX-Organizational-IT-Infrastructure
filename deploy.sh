#!/bin/bash

# Script de desplegament automatitzat per a GSX Week 11
# Aquest script neteja el clúster i aplica Terraform segons l'entorn triat.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== WEEK 11 Terraform Automation ===${NC}"

# Funció per netejar el clúster
clean_cluster() {
    echo -e "${RED}Netejant recursos existents de Kubernetes...${NC}"
    kubectl delete all --all
    kubectl delete configmaps --all
}

# Menú principal
echo "Selecciona l'entorn de desplegament:"
echo "1) Entorn de Desenvolupament (dev.tfvars - 1 rèplica)"
echo "2) Entorn de Staging (staging.tfvars - 3 rèpliques)"
echo "3) Només netejar el clúster"
echo "4) Sortir"
read -p "Opció [1-4]: " option

case $option in
    1)
        clean_cluster
        cd terraform/
        terraform init
        echo -e "${GREEN}Aplicant entorn de DEV...${NC}"
        terraform apply -var-file="dev.tfvars" -auto-approve
        ;;
    2)
        clean_cluster
        cd terraform/
        terraform init
        echo -e "${GREEN}Aplicant entorn de STAGING...${NC}"
        terraform apply -var-file="staging.tfvars" -auto-approve
        ;;
    3)
        clean_cluster
        echo -e "${GREEN}Clúster netejat.${NC}"
        ;;
    4)
        exit 0
        ;;
    *)
        echo "Opció no vàlida."
        exit 1
        ;;
esac