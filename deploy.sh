#!/bin/bash

# Script de desplegament automatitzat per a GSX Week 11
# Aquest script neteja el clúster i aplica Terraform segons l'entorn triat.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== WEEK 11 Terraform Automation ===${NC}"

# Funció per assegurar que Minikube està encès (Antifallos)
check_minikube() {
    echo -e "${YELLOW}Comprovant l'estat de Minikube...${NC}"
    # Si minikube status dona error (no està actiu), l'arranquem
    if ! minikube status &> /dev/null; then
        echo -e "${RED}Minikube està apagat. Arrencant motors automàticament...${NC}"
        minikube start --cni=calico
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error en arrencar Minikube. Assegura't que tens Minikube instal·lat i configurat correctament.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}Minikube ja està en funcionament.${NC}"
    fi
}

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
        check_minikube
        clean_cluster
        cd terraform/
        terraform init
        echo -e "${GREEN}Aplicant entorn de DEV...${NC}"
        terraform apply -var-file="dev.tfvars" -auto-approve
        ;;
    2)
        check_minikube
        clean_cluster
        cd terraform/
        terraform init
        echo -e "${GREEN}Aplicant entorn de STAGING...${NC}"
        terraform apply -var-file="staging.tfvars" -auto-approve
        ;;
    3)
        check_minikube
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