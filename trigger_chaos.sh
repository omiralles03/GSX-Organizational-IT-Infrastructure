#!/bin/bash

SERVICE_NAME="gsx-backend-service"
PORT=3000

echo "-----------------------------------------------------------"
echo "🔥 GSX ALARM TRIGGER (CHAOS SCRIPT)"
echo "-----------------------------------------------------------"
echo "Selecciona qué alarma quieres activar:"
echo "1) HighCPUUsage   (Estresar CPU > 60%)"
echo "2) HighErrorRate  (Forzar errores > 5%)"
echo "3) Detener todo"
read -p "Opción [1-3]: " OPTION

case $OPTION in

1)
    echo "☢️  LANZANDO ATAQUE DE HASHING (CPU OVERLOAD)..."
    PODS=$(kubectl get pods -l app=gsx-app -o jsonpath='{.items[*].metadata.name}')
    
    for POD in $PODS; do
      echo "🔥 Pegando la CPU al 100% en $POD..."
      # Lanzamos 5 procesos sha256sum en paralelo leyendo de /dev/zero.
      # Esto obligará al procesador a calcular hashes sin parar.
      kubectl exec $POD -- sh -c "for i in \$(seq 1 20); do (sha256sum /dev/zero > /dev/null &); done; sleep 3000" &
    done
    echo "-----------------------------------------------------------"
    echo "✅ CAOS TOTAL ENVIADO. Mira Grafana ahora."
    ;;

    2)
    echo "⚠️  Forzando tasa de errores..."
    
    # Abrimos un túnel rápido en segundo plano hacia el puerto 3000
    echo "🔗 Abriendo túnel temporal hacia el Backend..."
    kubectl port-forward service/$SERVICE_NAME 3001:3000 > /dev/null 2>&1 &
    PF_PID=$!
    sleep 2 # Esperamos a que el túnel conecte
    
    BACKEND_URL="http://127.0.0.1:3001"
    
    echo "🚀 Lanzando ráfaga de peticiones a $BACKEND_URL..."
    # Lanzamos 500 peticiones rápidas. Con el 1% de error base, 
    # esto generará algunos 500s. Para forzar el 5%, asegúrate de 
    # que el script de tráfico normal también esté corriendo.
    for i in {1..200}; do 
        curl -s "$BACKEND_URL/" > /dev/null & 
    done
    
    echo "✅ Peticiones enviadas. Revisa Prometheus Alerts."
    
    # Cerramos el túnel temporal
    kill $PF_PID
    ;;

3)
    echo "🛑 Deteniendo procesos de estrés..."
    PODS=$(kubectl get pods -l app=gsx-app -o jsonpath='{.items[*].metadata.name}')
    for POD in $PODS; do
      # Matamos los procesos de sha256sum
      kubectl exec $POD -- pkill sha256sum 2>/dev/null
    done
    echo "✅ Sistema recuperado."
    ;;
esac