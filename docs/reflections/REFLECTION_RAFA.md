# Reflection Essay: Cloud-Native Infrastructure & Distributed Systems Automation

**Course:** GSX - Organizational IT Infrastructure  
**Author:** Rafael Pino Rodriguez  
**Organization Context:** GreenDevCorp Infrastructure Deployment  

---

## 1. What was the most challenging aspect of this assignment?

Sens dubte, l'aspecte més complex i alhora gratificant d'aquest projecte ha estat la implementació i depuració d'un model de xarxa *Zero Trust* utilitzant el clúster de Kubernetes sota el motor de Calico CNI. La teoria de tancar la infraestructura sembla directa sobre el paper: s'aplica una regla de denegació per defecte (*Default Deny All*) i es van obrint camins mitjançant permisos explícits. No obstant això, traslladar aquesta lògica de manera completament declarativa a Terraform ha estat un repte immens.

El moment operatiu més crític es va produir en integrar l'stack d'observabilitat. En tancar el clúster per aïllar de forma segura la base de dades Redis i les rèpliques del backend de Node.js, vam blocar involuntàriament els "vigilants" de la pròpia xarxa. Prometheus va perdre la capacitat de realitzar el raspallat (*scraping*) de telemetria, provocant silenciosos errors de xarxa de tipus *timeout* i l'aparició de pantalles buides ("No Data") a Grafana.

Diagnosticar aquestes fallades m'ha obligat a utilitzar intensivament mètodes de depuració interactius dins dels contenidors mitjançant la CLI (`kubectl exec`) combinats amb utilitats com `nc -zv` per comprovar de manera manual quina *NetworkPolicy* exacta de Terraform estava barrant el pas al trànsit. Superar aquest bloqueig i perforar la xarxa de manera segura va requerir una comprensió absoluta del comportament de les regles d'ingrés (*Ingress*) i d'egrés (*Egress*). A més, coordinar el cicle de vida dels desplegaments lligant les imatges de Docker als hashes reals de Git (tags tipus `sha-xxxx`) gestionats dinàmicament en fitxers de variables d'entorn i secrets, ha exigit un control sintàctic i d'arquitectura molt rigorós.

## 2. What surprised you about modern infrastructure?

El que més m'ha sorprès de la infraestructura moderna és la immensa capacitat d'abstracció i la flexibilitat que ofereix el programari per governar el maquinari. Tradicionalment, la gestió de sistemes i xarxes s'associava a topologies físiques rígides, encaminadors estàtics i configuracions manuals lentes de modificar. Veure com tota l'arquitectura d'una organització (des del tallafocs central de control fins als equilibradors de càrrega de l'API) es pot codificar completament en un fitxer de text de Terraform demostra que la infraestructura ha deixat de ser un element rígid per esdevenir quelcom viu, mutable i altament elàstic.

## 3. What would you do differently if you started over?

Si hagués de tornar a començar aquest projecte des de zero, l'únic que faria diferent seria configurar i assegurar-me d'afegir tots els fitxers `.gitignore` necessaris abans de res. Això hauria evitat del tot la pujada accidental al repositori de Git de fitxers residuals de control local de Terraform (`.tfstate`) o de còpies de seguretat temporals (`.backup`), els quals són totalment innecessaris per al control de versions i poden exposar informació d'estat de la infraestructura. Tota la resta del projecte la deixaria exactament igual com l'he fet, ja que tant l'arquitectura de microserveis, la lògica de desplegament basada en scripts, com les polítiques de xarxa implementades han demostrat funcionar a la perfecció.

## 4. How has your understanding of DevOps and cloud-native systems changed?

Honestament, la meva visió fonamental sobre la cultura DevOps i els sistemes cloud-native no ha canviat en absolut amb aquesta pràctica, sinó que s'ha reforçat i consolidat de manera molt més profunda tot el que ja sabia teòricament que feien. Abans d'iniciar el projecte, ja comprenia perfectament que DevOps és una filosofia d'enginyeria integral orientada a la col·laboració, l'automatització i el disseny resilient, i que els sistemes cloud-native busquen desplegar aplicacions altament distribuïdes, desacoblades i autònomes.

El que ha aportat aquest treball ha estat una validació pràctica i molt més detallada d'aquests conceptes en un entorn real. En lloc de veure-ho com a definicions abstractes, haver de programar, desplegar i patir realment la interconnexió entre els microserveis, els balancejadors de càrrega, els fitxers de configuració i les regles de xarxa de Calico m'ha permès comprovar exactament com s'executa aquesta filosofia a la realitat. Per exemple, veure de primera mà com el codi i l'operació han de néixer estretament agermanats (com el fet que l'API de Node.js hagi d'exposar de forma nativa l'endpoint `/metrics` per a Prometheus) no ha capgirat la meva perspectiva, si no que ha demostrat amb fets concrets com de necessària, lògica i eficient és la visió SRE que ja coneixia inicialment.

## 5. What do you want to learn more about?

Amb la base tècnica ja consolidada en entorns locals orquestrats per Minikube, el pas natural cap a on vull dirigir el meu aprenentatge és la transició cap a l'ecosistema de núvol públic real d'escala enterprise. M'hauria agradat tenir l'oportunitat d'implementar i desplegar aquesta mateixa infraestructura utilitzant serveis gestionats natius de **AWS (Amazon Web Services)**, com podrien ser EKS per a l'orquestració de Kubernetes o VPC avançades per al disseny de xarxa, atès que és la plataforma hegemònica que es demana i s'utilitza majoritàriament en el teixit industrial de les grans organitzacions tecnològiques.

Considero que per complementar aquesta pràctica, seria idoni realitzar algun tipus de curs pràctic d'especialització que em preparés per obtenir una certificació oficial (com la de *AWS Certified Solutions Architect* o *SysOps*), validant així de manera formal aquests coneixements davant del mercat laboral. Es podria haver fet algun d'aquests cursos o formacions certificades dins del marc d'aquesta pròpia assignatura, aprofitant com a gran actiu el suport, la tutela i la guia del professorat per accelerar aquest procés d'aprenentatge en entorns cloud empresarials de primer nivell.
