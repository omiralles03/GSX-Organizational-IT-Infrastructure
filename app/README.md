`Dockerfile`
Builder -> Production
Non-root user "gsxuser" (UID 1001)

`Build`
```bash
docker build -t gsx-app .
docker run --name gsx-container -p 3000:3000 gsx-app
docker run --rm --name gsx-container -p 3000:3000 gsx-app # Run and Delete on Stop
# Flag -d runs in detached mode
``` 

`Commands`
```bash
docker ps    # List containers running
docker ps -a # List all containers
docker container prune # Delete all Stopped containers
docker image prune     # Delete all unused images

curl localhost:3000 # Test node app
```




