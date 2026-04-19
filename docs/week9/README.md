# Setmana 9: Orquestració Multi-Contenidor amb Docker Compose

Aquest document detalla la infraestructura completa de GreenDevCorp, gestionada mitjançant **Docker Compose**. Hem passat de contenidors aïllats a un sistema interconnectat, resilient i limitat segons estàndards professionals.

## 1. Arquitectura del Sistema i Serveis

Hem definit tres serveis que cooperen de manera autònoma:

1.  **`web` (Nginx):** Actua com a porta d'entrada (Proxy). Utilitza una imatge `unprivileged:alpine` per seguretat.
2.  **`backend` (Node.js):** La nostra lògica de negoci. Inclou un sistema de monitorització de salut (*Healthcheck*).
3.  **`db` (Redis):** Una base de dades en memòria per a la persistència ràpida de dades.

### Justificació de l'Ordre d'Arrencada (Startup Order)
Hem implementat una jerarquia de dependències (`depends_on`) per evitar errors de connexió:
* El **Backend** espera que la **Base de Dades** estigui encesa.
* El **Web (Nginx)** espera que el **Backend** estigui no només encès, sinó "Sà" (`service_healthy`). Això garanteix que l'usuari mai rebi un error 502 perquè el servidor Nginx ha arrencat més ràpid que l'aplicació Node.

## 2. Gestió de la Configuració (.env)

Tota la configuració sensible i els ports es gestionen mitjançant un fitxer **`.env`**.
* **Justificació:** Això permet que el mateix codi es pugui desplegar en diferents entorns (desenvolupament, test, producció) només canviant el fitxer de variables, sense tocar el codi font ni l'estructura de Docker.

## 3. Xarxes i Seguretat d'Aïllament (Advanced)

Hem creat una xarxa personalitzada anomenada **`gsx_network`** amb el driver `bridge`.
* **Justificació:** En lloc d'usar la xarxa per defecte, una xarxa personalitzada proporciona un aïllament real del sistema host i permet la resolució de noms DNS interna. El contenidor `web` pot parlar amb el `backend` simplement usant el nom `http://backend:3000`.

## 4. Persistència de Dades (Volumes)

Hem declarat dos volums gestionats per Docker: `redis_data` i `nginx_logs`.
* **Justificació:** Els contenidors són efímers (si s'esborren, les dades moren). Els volums permeten que la informació de la base de dades i els registres de Nginx sobrevisquin a reinicis o actualitzacions del sistema, complint el requisit de persistència del document de pràctiques.

## 5. Gestió de Logs i Recursos (Advanced)

Per garantir l'estabilitat del servidor host, hem configurat:

### Logging Driver JSON
Hem limitat el creixement dels logs: `max-size: "10m"` i `max-file: "3"`.
* **Justificació:** En producció, un error que generi molts logs pot omplir el disc dur i fer caure tot el servidor. Aquesta configuració limita el consum total de disc per servei a 30MB.

### Límits de Recursos (CPU i RAM)
* **Backend:** Limitat a 0.5 nuclis i 256MB RAM.
* **Web/DB:** Limitats a 128MB/64MB RAM.
* **Justificació:** Si un servei té una fuita de memòria o un procés infinit, Docker el limitarà abans que bloquegi la CPU o la RAM de la resta de serveis del PC.

---

## 6. Comandes i Resultats de Verificació

Per comprovar que la instal·lació i les polítiques de seguretat funcionen correctament, s'han realitzat les següents proves de validació:

### 1. Estat de Salut i Mapeig de Ports
```bash
docker-compose ps
```
**Resultat obtingut:** Es confirma que el backend està en estat `healthy` (validant l'ordre d'arrencada) i que tots els ports d'entorn s'han enllaçat correctament amb el host (`0.0.0.0`):
```text
NAME          IMAGE                                          COMMAND                  SERVICE   CREATED          STATUS                    PORTS
gsx-backend   gsx-organizational-it-infrastructure-backend   "docker-entrypoint.s…"   backend   55 seconds ago   Up 52 seconds (healthy)   0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp
gsx-db        redis:alpine                                   "docker-entrypoint.s…"   db        56 seconds ago   Up 53 seconds             0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp
gsx-web       gsx-organizational-it-infrastructure-web       "/docker-entrypoint.…"   web       54 seconds ago   Up 22 seconds             0.0.0.0:80->8080/tcp, [::]:80->8080/tcp
```

### 2. Comprovació de la Política de Logs (Logging Driver)
```bash
docker inspect gsx-web --format '{{json .HostConfig.LogConfig}}'
```
**Resultat obtingut:** Confirmació de l'aplicació dels límits de rotació de logs per protegir l'espai en disc del servidor:
```json
{"Type":"json-file","Config":{"max-file":"3","max-size":"10m"}}
```

### 3. Comprovació de Restriccions de Hardware
```bash
docker stats --no-stream
```
**Resultat esperat:** A la columna `MEM USAGE / LIMIT` es verifica que cada contenidor està restringit segons el disseny: `gsx-backend` a `256MiB`, `gsx-web` a `128MiB` i `gsx-db` a `64MiB`.

### 4. Gestió del Cicle de Vida
```bash
# Per apagar la infraestructura (la xarxa es destrueix, però els volums de dades persisteixen)
docker-compose down
```