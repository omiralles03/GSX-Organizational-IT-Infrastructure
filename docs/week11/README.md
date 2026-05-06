# Setmana 11: Infraestructura com a Codi (IaC) i CI/CD Avançat

Aquest document detalla la implementació de la infraestructura automatitzada de GreenDevCorp mitjançant **Terraform** i el pipeline de lliurament continu (CI/CD) amb **GitHub Actions**, seguint els requisits de la Setmana 11.

## 1. Justificació de l'Eina: Terraform

Per a aquesta pràctica hem seleccionat **Terraform** com a eina d'IaC en lloc d'Ansible per les següents raons tècniques:
* **Model Declaratiu:** Terraform permet definir l'estat desitjat del clúster de Kubernetes. Si l'estat real canvia (per exemple, si un pod s'esborra), Terraform el restaura.
* **Gestió d'Estat (State File):** Terraform manté un fitxer `.tfstate` que actua com a font de veritat, facilitant la detecció de canvis en la infraestructura.
* **Proveïdor de Kubernetes Natiu:** El proveïdor de Kubernetes de Terraform és extremadament potent i ens permet traduir els YAML de la Setmana 10 a codi estructurat sense dependre de scripts externs.

## 2. Estructura del Projecte IaC

El codi de Terraform s'ha organitzat modularment per evitar el "hardcoding":
* **`providers.tf`**: Configuració de la connexió amb el clúster de Minikube.
* **`variables.tf`**: Definició de les variables d'entrada (usuari de Docker Hub, tags d'imatge, rèpliques).
* **`main.tf`**: Definició de tots els recursos (ConfigMaps, Deployments i Services).
* **`outputs.tf`**: Informació útil que es mostra en finalitzar el desplegament (ports, comandes).
* **`dev.tfvars` i `staging.tfvars`**: Fitxers de valors específics per a diferents entorns.

## 3. Pipeline de CI/CD Avançat (GitHub Actions)

Hem dissenyat un workflow de GitHub Actions que s'executa automàticament a cada `push` a la branca `main`:

### Seguretat i Qualitat (CI)
1. **Validació de Terraform:** Executa `terraform fmt` i `terraform validate` per assegurar que el codi d'infraestructura és correcte abans d'aplicar-lo.
2. **Caché de Docker (Buildx):** Utilitzem `cache-from` i `cache-to` per accelerar les construccions d'imatges.
3. **Escaneig de Seguretat (Trivy):** Analitzem les imatges construïdes a la recerca de vulnerabilitats crítiques. El pipeline fallarà si es detecta algun risc inacceptable.
4. **Generació de SBOM (Syft):** Generem un "Software Bill of Materials" (SPDX) que detalla totes les llibreries internes dels nostres contenidors, disponible com a artefacte de GitHub.

### Lliurament Multiusuari
El pipeline identifica automàticament si el `push` l'ha fet **Rafita-pino** o **omiralles03**, utilitzant els secrets i els comptes de Docker Hub corresponents de manera dinàmica.

## 4. Guia de Desplegament i Automatització

### Requisits Previs
* Minikube en funcionament.
* Terraform instal·lat localment.

### Passos manuals (Mètode clàssic)
1. Inicialitzar: 
```bash
terraform init
```
2. Validar: 
```bash
terraform validate
```
3. Desplegar (Exemple Dev): 
```bash
terraform apply -var-file="dev.tfvars"
```

### Automatització amb Script (deploy.sh)
Hem creat un script de Bash per evitar errors humans i netejar el clúster abans de cada desplegament.

## 5. Verificació de la Infraestructura

Un cop desplegat, podem comprovar l'estat amb:
* **Estat del clúster:** 
```bash
kubectl get all
```
* **Accés a la web:** Terraform mostrarà el port `30080`. Es pot accedir a `http://localhost:30080`.
* **Escalat:** Si s'usa `dev.tfvars`, veurem 1 sola rèplica. Amb `staging.tfvars`, en veurem 3.