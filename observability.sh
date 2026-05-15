#!/bin/bash

echo "-----------------------------------------------------------"
echo "🚀 GSX FULL AUTOMATED ORCHESTRATOR (CROSS-PLATFORM)"
echo "-----------------------------------------------------------"

case "$OSTYPE" in
  msys*|cygwin*|win32*) OS="WINDOWS" ;;
  linux*)               OS="LINUX" ;;
  darwin*)              OS="MACOS" ;;
  *)                    OS="UNKNOWN" ;;
esac

echo "🖥️  Sistema Operativo detectado: $OS"

# 1. Limpiar basura de ejecuciones anteriores
rm -f tunnel_*.out url_*.tmp run_tunnel.sh

# 2. CREAR EL SCRIPT "RUNNER" AL VUELO
# Esto evita que Windows CMD rompa los símbolos > y &
cat << 'EOF' > run_tunnel.sh
#!/bin/bash
echo "========================================="
echo " 🌐 Túnel para $1"
echo " ⚠️  NO CERRAR ESTA VENTANA"
echo "========================================="
minikube service $1 2>&1 | tee tunnel_$1.out
EOF
chmod +x run_tunnel.sh

# 3. Función para disparar las terminales usando el Runner
open_tunnel() {
    local SERVICE=$1
    echo "Lanzando túnel para $SERVICE..."
    
    if [ "$OS" = "WINDOWS" ]; then
        # Ahora llamamos al mini-script de forma segura
        start bash -c "./run_tunnel.sh $SERVICE; exec bash"
    elif [ "$OS" = "MACOS" ]; then
        osascript -e "tell app \"Terminal\" to do script \"$(pwd)/run_tunnel.sh $SERVICE\""
    elif [ "$OS" = "LINUX" ]; then
        if command -v gnome-terminal &> /dev/null; then
            gnome-terminal -- bash -c "./run_tunnel.sh $SERVICE; exec bash"
        elif command -v xterm &> /dev/null; then
            xterm -e "./run_tunnel.sh $SERVICE" &
        else
            ./run_tunnel.sh $SERVICE &
        fi
    fi
}

# 4. Función de espera (File Polling)
wait_for_url() {
    local SERVICE=$1
    local TEMP_FILE="url_$SERVICE.tmp"
    
    echo -n "   ⏳ Esperando la IP de $SERVICE..."
    
    while ! grep -q "http://127.0.0.1:" "tunnel_$SERVICE.out" 2>/dev/null; do
        sleep 1
        echo -n "."
    done
    
    URL=$(grep -oE "http://127.0.0.1:[0-9]+" "tunnel_$SERVICE.out" | tail -n 1)
    echo "$URL" > "$TEMP_FILE"
    echo " ¡Listo! ($URL)"
}

# =========================================================
# EJECUCIÓN PRINCIPAL
# =========================================================

echo ""
# Lanzar los 3 procesos en paralelo
open_tunnel "prometheus-service"
open_tunnel "grafana-service"
open_tunnel "gsx-backend-service"

echo ""
# Esperar resultados
wait_for_url "prometheus-service"
wait_for_url "grafana-service"
wait_for_url "gsx-backend-service"

# Leer y guardar en memoria
PROM_URL=$(cat url_prometheus-service.tmp)
GRAFANA_URL=$(cat url_grafana-service.tmp)
BACKEND_URL=$(cat url_gsx-backend-service.tmp)

echo "-----------------------------------------------------------"
echo "🌍 Abriendo interfaces en el navegador..."

wait 5 

echo "🔥 Lanzando script de tráfico en segundo plano..."
if [ "$OS" = "WINDOWS" ]; then
    start bash -c "echo 'Generador de Tráfico (NO CERRAR)'; ./traffic.sh $BACKEND_URL; exec bash"
elif [ "$OS" = "MACOS" ]; then
    osascript -e "tell app \"Terminal\" to do script \"cd $(pwd) && ./traffic.sh $BACKEND_URL\""
elif [ "$OS" = "LINUX" ]; then
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal -- bash -c "./traffic.sh $BACKEND_URL; exec bash"
    elif command -v xterm &> /dev/null; then
        xterm -e "./traffic.sh $BACKEND_URL" &
    else
        ./traffic.sh $BACKEND_URL &
    fi
fi

# Limpieza final
rm -f run_tunnel.sh
rm -f url_*.tmp
rm -f tunnel_*.out

echo "-----------------------------------------------------------"
echo "✨ ORQUESTACIÓN COMPLETADA."
echo "-----------------------------------------------------------"