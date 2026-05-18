# Reflection Essay: Cloud-Native Infrastructure & Distributed Systems Automation

**Course:** GSX - Organizational IT Infrastructure

**Author:** Oupman Miralles Escolà

**Organization Context:** GreenDevCorp Infrastructure Deployment

---

## 1. What was the most challenging aspect of this assignment?

El repte més gran d'aquesta pràctica ha estat, sens dubte la transició des del disseny teòric de subxarxes corporatives cap a la seva implementació lògica real en un ecosistema de microserveis mitjançant Kubernetes. Separar de forma abstracta els entorns de Development, Staging i Production en rangs d'IPs 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24 ha sigut complicat plantejar-ho desde un inici pensant els accessos a cada entorn.

Després quan s'introdueixen les NetworkPolicies per forçar el comportament de la xarxa, es torna complicat alinear de manera exacta les etiquetes (labels) dels Deployments, Services i NetworkPolicies, la qual cosa va necessitar un cert temps en proves i depuració.

El més difícil va ser entendre que una regla de tallafocs a nivell de pod és completament inútil si la infraestructura s'ha desplegat inicialment barrejada o sense una estructura de camins clara. Haver de diagnosticar connexions mitjançant comandes d'inspecció com netcat (nc) des de dins dels contenidors em va obligar a entendre l'arquitectura no com a fitxers aïllats, sinó com un sistema complet interconnectat de Capa 3 i Capa 4 de xarxa.

## 2. What surprised you about modern infrastructure?

El que més m'ha sorprès de la infraestructura moderna és la naturalesa declarativa dels sistemes cloud-native. El fet que ja no calgui configurar manualment servidors físics, cables o interfícies de xarxa tradicionals mitjançant terminals tancades, sinó que tot un workflow empresarial es pugui codificar en línies de codi text és un canvi de molt gran. Considero però, que amb una mala gestió la feina s'embolica molt.

A més, el concepte de Default Deny en Kubernetes em va semblar interessant. El fet de poder aïllar de manera completa qualsevol recurs que neixi en un ecosistema protegit fins que l'administrador dictamini les regles exactes d'Ingress o Egress és molt advantatjós, on el clúster deixa de ser un conjunt de màquines acoblades i passen a ser una unitat completa i homogènea.

## 3. What would you do differently if you started over?

Si hagués de començar el projecte des de zero, canviaria radicalment l'estratègia d'organització i modularització dels fitxers YAML de definició de recursos. Inicialment, la reutilització de plantilles genèriques a l'arrel de l'espai de treball va provocar un embolic molt gran cap al final, on hi havia problemes d'assignació d'IPs virtuals i duplicats orfes de dominis en el namespace per defecte.

## 4. How has your understanding of DevOps and cloud-native systems changed?

Abans de realitzar aquesta pràcitca, la meva concepció de DevOps i sistemes del núvol estava limitada a una visió molt simplificada de l'allotjament d'aplicacions: veia el cloud com un simple servidor remot on s'executava codi, i potser era imporant el despleguament i replicació de l'entorn.

Aquesta pràctica m'ha fet adonar-me de la gran escala i importàncie d'aquestes tasques. He entès mètodes i pràctiques com les pipes de CI/CD, que lliguen el desenvolupament directament amb les operacions automatitzades, o el valor de conceptes com Kubernetes per a l'orquestració de microserveis distribuïts.

## 5. What do you want to learn more about?

M'ha quedat un gran interès per explorar en profunditat l'univers dels CNI (Container Network Interfaces) avançats de producció real, especialment projectes com Calico o Cilium. Haver patit les limitacions del controlador de xarxa bàsic d'entorns de desenvolupament locals, el qual processa els YAMLs de les polítiques de xarxa de forma teòrica però no bloqueja el tràfic intern real per defecte, m'ha fet veure que hi ha tota una capa d'enginyeria de xarxes de baix nivell fascinant sota el pla de control de Kubernetes.

Vull aprendre més sobre l'automatització de les Infrastructures com a Codi i entendre com funcionen per sota totes aquestes eines que ajudan als desenvolupadors a desplegar els serveis al núvul.
