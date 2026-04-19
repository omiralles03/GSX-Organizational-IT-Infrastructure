# Setmana 8: Estratègia de Contenidorització i Enduriment de la Seguretat

Aquest document descriu l'estratègia de contenidorització per a les aplicacions de GreenDevCorp, detallant les decisions arquitectòniques, les optimitzacions i l'enduriment de la seguretat (*security hardening*) implementats per aconseguir imatges de Docker preparades per a producció.

## 1. Decisions Arquitectòniques i Imatges Base

Hem triat contenidoritzar dos serveis principals: un **Servidor Web Nginx** i una **Aplicació Backend Node.js**.

En lloc d'utilitzar distribucions estàndard pesades (com Ubuntu o Debian), hem optat estrictament per imatges base d'**Alpine Linux** (`nginxinc/nginx-unprivileged:alpine` i `node:25-alpine`).
* **Per què Alpine?** Alpine és una distribució de Linux extremadament lleugera i centrada en la seguretat. En reduir dràsticament el nombre de paquets instal·lats, minimitzem la superfície d'atac i reduïm els temps de desplegament.
* **Resultats d'Optimització d'Emmagatzematge:** Gràcies a aquestes decisions, les mides finals de les nostres imatges estan altament optimitzades:
  * Servidor Web Nginx: **26 MB**
  * Backend Node.js: **60 MB** (en comparació amb >1GB per a imatges estàndard de Node sense optimitzar).

## 2. Aplicació Node.js: Construccions Multietapa i Dependències

La nostra aplicació `gsx-app` depèn d'una única dependència externa (`dotenv`) per gestionar les variables d'entorn de manera segura. Per empaquetar això de manera eficient, hem implementat un patró de **Construcció Multietapa (*Multistage Build*)** al nostre `Dockerfile`:
1. **Fase Builder (Constructora):** Descarrega les eines pesades de Node i executa `npm install`.
2. **Fase de Producció:** Copia només el codi font necessari i la carpeta `node_modules` generada de la fase constructora, descartant tota la memòria cau de compilació innecessària.

A més, hem implementat un `HEALTHCHECK` personalitzat que fa una petició a `localhost:3000` cada 30 segons. Això permet a l'orquestrador de Docker saber si la lògica de l'aplicació s'ha penjat, fins i tot si el procés del contenidor tècnicament continua executant-se.

## 3. Enduriment Avançat de la Seguretat (*** Advanced)

Seguint el principi del mínim privilegi, hem implementat diverses mesures de seguretat avançades per protegir l'entorn de producció:

* **Execució No-Root:** Els contenidors mai s'han d'executar com a root per evitar escalades de privilegis.
  * Per al backend, hem creat un usuari específic `gsxuser` (UID 1001) dins del Dockerfile.
  * Per al servidor web, hem utilitzat la imatge oficial `nginx-unprivileged`, que corre sense root i exposa el port `8080`.
* **Capacitats Mínimes i Sistema de Fitxers de Només Lectura:** Hem dissenyat els nostres contenidors perquè siguin totalment funcionals eliminant totes les `capabilities` del nucli i muntant el sistema de fitxers com a només lectura per evitar modificacions malintencionades en temps d'execució.

## 4. Escaneig de Vulnerabilitats

Per garantir la seguretat, hem realitzat auditories amb `docker scout cves` per a les imatges de tots dos membres de l'equip:

* `rafitapino/nginx-gsx:v1` & `omiralles03/nginx-gsx:v1`: **0 vulnerabilitats CRÍTIQUES**.
* `rafitapino/gsx-app:v1` & `omiralles03/gsx-app:v1`: **0 vulnerabilitats CRÍTIQUES**.

Tot i que es detecten algunes vulnerabilitats de nivell Alt/Mitjà inherents als paquets base d'Alpine, l'absència de vulnerabilitats Crítiques i la nostra política de *read-only* i *non-root* redueixen el risc d'explotació a nivells mínims.

---

## 5. Inici Ràpid: Construcció i Execució Local

### Servidor Web Nginx
```bash
cd nginx/
docker build -t nginx-gsx .
# Execució amb seguretat recomanada (Producció)
docker run -d --name nginx-secure -p 80:8080 --cap-drop=ALL nginx-gsx
```

### Aplicació Backend Node.js
```bash
cd app/
docker build -t gsx-app .
# Execució amb seguretat extrema (Producció)
docker run -d --name app-secure -p 3000:3000 --read-only --cap-drop=ALL gsx-app
```

## 6. Verificació Creuada entre l'Equip (Core)

Per complir amb el requisit de desplegament en màquines diferents, hem publicat les imatges a Docker Hub. Qualsevol membre de l'equip pot descarregar i executar la feina de l'altre:

**Descarregar imatges de rafitapino:**
```bash
docker pull rafitapino/nginx-gsx:v1
docker pull rafitapino/gsx-app:v1
```

**Descarregar imatges de omiralles03:**
```bash
docker pull omiralles03/nginx-gsx:v1
docker pull omiralles03/gsx-app:v1
```

*Nota: Si es rep un error d'autenticació, cal assegurar-se que el repositori a Docker Hub estigui configurat com a **Public**.*