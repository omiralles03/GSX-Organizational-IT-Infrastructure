# Usamos la imagen oficial de Nginx ya preparada para no ser root
FROM nginxinc/nginx-unprivileged:alpine

# Copiamos nuestra web estática
COPY ./html /usr/share/nginx/html

# La imagen unprivileged usa el puerto 8080 por defecto por seguridad (los puertos <1024 requieren root)
EXPOSE 8080