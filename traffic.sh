#!/bin/bash

# Obtener la URL de la aplicación desde Minikube automáticamente
URL=$(minikube service gsx-nginx-service --url)

if [ -z "$URL" ]; then
  echo "❌ Error: No se ha podido obtener la URL. ¿Está Minikube encendido y la app desplegada?"
  exit 1
fi

echo "🚀 Iniciando generador de tráfico contra: $URL"
echo "📊 Abre Grafana y Prometheus. Pulsa [Ctrl+C] para detener."
echo "--------------------------------------------------------"

# Contadores locales
REQ_COUNT=0
ERR_COUNT=0

# Bucle infinito
while true; do
  # Ejecutar curl en silencio y extraer solo el código HTTP
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
  
  REQ_COUNT=$((REQ_COUNT+1))

  # Imprimir en consola el resultado sobrescribiendo la misma línea
  if [ "$HTTP_STATUS" = "200" ]; then
    echo -ne "🟢 Peticiones: $REQ_COUNT | ❌ Errores 500: $ERR_COUNT (Último: OK)\r"
  elif [ "$HTTP_STATUS" = "500" ]; then
    ERR_COUNT=$((ERR_COUNT+1))
    echo -ne "🟢 Peticiones: $REQ_COUNT | ❌ Errores 500: $ERR_COUNT (Último: ERROR 500)\r"
  else
    echo -ne "⚠️ Estado Inesperado ($HTTP_STATUS) - Peticiones: $REQ_COUNT\r"
  fi
  
  # Pausa de 0.05 segundos (genera unas 20 peticiones por segundo, suficiente para la alerta)
  sleep 0.05
done