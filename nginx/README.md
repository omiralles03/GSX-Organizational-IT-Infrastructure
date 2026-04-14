https://hub.docker.com/_/nginx

`Dockerfile`
``` Dockerfile
FROM nginx
COPY static-html-directory /usr/share/nginx/html
```

`Build`
```bash
docker build -t nginx-gsx .
docker run --name nginx-container -p 80:80 nginx-gsx
docker run --rm --name nginx-container -p 80:80 nginx-gsx # Run and Delete on Stop
# Flag -d runs in detached mode
``` 

`Commands`
```bash
docker ps    # List containers running
docker ps -a # List all containers
docker container prune # Delete all Stopped containers
docker image prune     # Delete all unused images

curl localhost # Test nginx
```
