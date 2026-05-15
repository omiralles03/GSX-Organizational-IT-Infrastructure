#!/bin/bash

# Ahora el script recibe la URL como parámetro
URL=$1

if [ -z "$URL" ]; then
  echo "❌ Error: Te falta poner la URL."
  echo "Uso correcto: ./traffic.sh http://127.0.0.1:PUERTO"
  exit 1
fi

echo "🚀 Iniciando generador de tráfico contra: $URL"
echo "📊 Abre Grafana y Prometheus. Pulsa [Ctrl+C] para detener."
echo "--------------------------------------------------------"

REQ_COUNT=0
ERR_COUNT=0

while true; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
  REQ_COUNT=$((REQ_COUNT+1))

  if [ "$HTTP_STATUS" = "200" ]; then
    echo -ne "🟢 Peticiones: $REQ_COUNT | ❌ Errores 500: $ERR_COUNT (Último: OK)\r"
  elif [ "$HTTP_STATUS" = "500" ]; then
    ERR_COUNT=$((ERR_COUNT+1))
    echo -ne "🟢 Peticiones: $REQ_COUNT | ❌ Errores 500: $ERR_COUNT (Último: ERROR 500)\r"
  else
    echo -ne "⚠️ Estado Inesperado ($HTTP_STATUS) - Peticiones: $REQ_COUNT\r"
  fi
  
  sleep 0.05
done