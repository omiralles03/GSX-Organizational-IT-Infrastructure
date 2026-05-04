# Setmana 10: Orquestració amb Kubernetes

Aquest document detalla la infraestructura realitzada aquesta setmana amb Kubernetes.

## 1. Arquitectura del Sistema i Serveis

Hem definit tres manifests per a cadascun dels serveis (Nginx i Node) per separar la configuració, càrrega de treball i accés.

1.  **ConfigMap (`app-config`, `nginx-config`):**
    - Serveix per guardar i especificar la configuració amb dades no sensibles en format clau-valor.
      - Node: especifica el port per rebre peticions HTTP.
          ```yaml
          data:
          PORT: "3000"
          ```
      - Nginx: escolta al port 8080 i redirigeix les peticions fetes a `/api/` cap al servei `gsx-backend-service` al port 3000.
          ```yaml
          data:
            default.conf: |
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
          ```
2. **Deployment (`gsx-app-deployment`, `nginx-deployment`):**
   - Defineix l'estat dels Pods i gestiona el cicle de vide de l'aplicació. Si un Pod falla es reinicia automàticament. També permet fer escalat de forma instantànea.
        - Node: tenim fins a 3 rèpliques. El contenidor és la imatge del DockerHub i imposem restriccions de recursos.
          ```yaml
          spec:
            replicas: 3
          ...
          containers:
            - name: gsx-app-container
              image: omiralles03/gsx-app:v1
              ports:
                - containerPort: 3000
              envFrom:
                - configMapRef:
                    name: app-config
              resources:
                requests:
                  memory: "64Mi"
                  cpu: "100m"
                limits:
                  memory: "128Mi"
                  cpu: "200m"
          ```
      - Nginx: enim una sola rèplica perquè actua com a punt d'entrada únic de configuració. El contenidor carrega la imatge personalitzada de DockerHub i muntem un volum de configuració **ConfigMap** per injectar el fitxer `default.conf`. Això ens permet modificar el comportament del proxy sense haver de recrear la imatge de Docker.
          ```yaml
          spec:
            replicas: 1
          ...
          spec:
            containers:
              - name: nginx-container
                image: omiralles03/nginx-gsx:v1
                ports:
                  - containerPort: 8080
                volumeMounts:
                  - name: nginx-config-volume
                    mountPath: /etc/nginx/conf.d/default.conf
                    subPath: default.conf
            volumes:
              - name: nginx-config-volume
                configMap:
                  name: nginx-config
          ```
3. **Service (`gsx-backend-service`, `gsx-nginx-service`):**
   - Serveix per exposar una aplicació que s'executa en diferents Pods, on cada Pod obté la seva propia IP, i el servei actua com un punt d'entrada fix i de balançejador de càrrega per a totes les rèpliques.
     - Node (ClusterIP): Aquest servei només és accessible des de l'interior del clúster. Actua com a balançejador intern per als 3 pods de l'app.
          ```yaml
          spec:
            selector:
              app: gsx-app
            type: ClusterIP
            ports:
              - protocol: TCP
                port: 3000
                targetPort: 3000
          ```
      - Nginx (NodePort): Aquest servei exposa l'aplicació a l'exterior. Mapeja el port 80 del contenidor al port **30080** de la IP del node de Kubernetes.
          ```yaml
          spec:
            selector:
              app: nginx-gsx
            type: NodePort
            ports:
              - protocol: TCP
                port: 80
                targetPort: 8080
                nodePort: 30080
          ```
## 2. Comunicació i Flux de Dades

1. **Comunicació entre Pods (Interna)**
   
   Els Pods es comuniques mitjançant la resolució interna de DNS de Kubernetes. El servei d'Nginx fa un `proxy_pass` cap a `http://gsx-backend-service:3000`. Kubernetes s'encarrega de redirigir aquesta petició a un dels pods disponibles amb l'etiqueta `app: gsx-app`.

3. **Comunicació Externa**
   
   Hem utilitzat un servei `NodePort` per al component Nginx. Kubernetes obre el port `30080` a tots els nodes del clúster, aleshores, qualsevol client que accedeixi a la IP del clúster per aquest port serà automàticament redirigit al servei de Nginx.
   
## 3. Escalat i Resiliència

1. **Escalat Horitzontal**
   
   Amb la comanda `kubectl scale` hem pogut augmentar o disminur el nombre de rèpliques en temps real.
   ```bash
   ❯ kubectl get pods
    NAME                                  READY   STATUS    RESTARTS   AGE
    gsx-app-deployment-779557bdb8-9d8qr   1/1     Running   0          119s
    gsx-app-deployment-779557bdb8-cllvj   1/1     Running   0          2m6s
    gsx-app-deployment-779557bdb8-tbjmv   1/1     Running   0          115s
    nginx-deployment-d44c4df78-bvt7x      1/1     Running   0          2m6s

    ❯ kubectl scale deployment nginx-deployment --replicas=3
    deployment.apps/nginx-deployment scaled
   
    ❯ kubectl get pods -w
    NAME                                  READY   STATUS    RESTARTS   AGE
    gsx-app-deployment-779557bdb8-9d8qr   1/1     Running   0          4m47s
    gsx-app-deployment-779557bdb8-cllvj   1/1     Running   0          4m54s
    gsx-app-deployment-779557bdb8-tbjmv   1/1     Running   0          4m43s
    nginx-deployment-d44c4df78-57ccf      1/1     Running   0          5s
    nginx-deployment-d44c4df78-bvt7x      1/1     Running   0          4m54s
    nginx-deployment-d44c4df78-h96jv      1/1     Running   0          5s
    ```

2. **Self-Healing**
   
   Amb la comanda `kubectl delete pod <pod-name>` hem pogut observar com un Pod s'aixeca automàticament en ser aturat.
   ```bash
    ❯ kubectl get pods
    NAME                                  READY   STATUS    RESTARTS   AGE
    gsx-app-deployment-779557bdb8-9d8qr   1/1     Running   0          5m3s
    gsx-app-deployment-779557bdb8-cllvj   1/1     Running   0          5m10s
    gsx-app-deployment-779557bdb8-tbjmv   1/1     Running   0          4m59s
    nginx-deployment-d44c4df78-bvt7x      1/1     Running   0          5m10s
   
    ❯ kubectl delete pod gsx-app-deployment-779557bdb8-tbjmv
    pod "gsx-app-deployment-779557bdb8-tbjmv" deleted from default namespace
   
    ❯ kubectl get pods
    NAME                                  READY   STATUS    RESTARTS   AGE
    gsx-app-deployment-779557bdb8-9d8qr   1/1     Running   0          10m
    gsx-app-deployment-779557bdb8-cllvj   1/1     Running   0          10m
    gsx-app-deployment-779557bdb8-k4ldf   1/1     Running   0          39s
    nginx-deployment-d44c4df78-bvt7x      1/1     Running   0          10m
   ```
   Podem observar el Pod `tbjmv` es eliminat, durant el delete, el seu estat passa a ser `Terminating`, i un cop eliminat per complet, aquest es torna a aixecar.
   Però una vegada eliminat un Pod, aquest es crea de nou, sent completament diferent tal i com veiem en el seu identificador: `tbjmv` -> `k4ldf`.

## 4. Comandes i Resultats de Verificació

1. **Verificació de l'Estat del Clúster**
   
S'ha comprovat que tots els components (Pods, Services i Deployments) estiguin operatius.
```bash
❯ kubectl get all
NAME                                      READY   STATUS    RESTARTS   AGE
pod/gsx-app-deployment-779557bdb8-9d8qr   1/1     Running   0          67m
pod/gsx-app-deployment-779557bdb8-cllvj   1/1     Running   0          67m
pod/gsx-app-deployment-779557bdb8-k4ldf   1/1     Running   0          57m
pod/nginx-deployment-d44c4df78-bvt7x      1/1     Running   0          67m

NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/gsx-backend-service   ClusterIP   10.96.129.184   <none>        3000/TCP       69m
service/gsx-nginx-service     NodePort    10.97.45.203    <none>        80:30080/TCP   69m
service/kubernetes            ClusterIP   10.96.0.1       <none>        443/TCP        109m

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/gsx-app-deployment   3/3     3            3           69m
deployment.apps/nginx-deployment     1/1     1            1           69m

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/gsx-app-deployment-779557bdb8   3         3         3       67m
replicaset.apps/gsx-app-deployment-997f6bc97    0         0         0       69m
replicaset.apps/nginx-deployment-9984f7f9f      0         0         0       69m
replicaset.apps/nginx-deployment-d44c4df78      1         1         1       67m

```

2. **Connectivitat Interna (Nginx -> Backend)**

Es comprova que es pot fer una petició al backend pel seu nom DNS i el `proxy_pass` de Nginx funciona.
```bash
❯ kubectl exec -it nginx-deployment-d44c4df78-bvt7x -- sh
/ # curl http://gsx-backend-service:3000
Hello from container
/ # exit
```

3. **Verificació del Self-Healing i Logs**

Com hem vist abans, al fer `kubectl delete <pod>` el pod s'eliminava i s'aixecava correctament. Podem comprovar també el log del nou pod aixecat:
```bash
❯ kubectl logs gsx-app-deployment-779557bdb8-k4ldf
Server running on port 3000
```
