# Container image creation


Based on tutorial from [here](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-tutorial-prepare-app)

### Create and test it locally

Assume you have docker in your machine.

With `myapp.sh`, `myapploop.sh`, and `Dockerfile` files in hands, plus `Docker` in your system,
let's build a container image:

In this `Dockerfile` we specified `myapp.sh` as entry pointer for the container,
that is the script used when running the container.


``` docker build -t myapp . ```

- `-t:` tag of the image
- `.:` directory to find Dockerfile

Show built images:

```
docker images
```

Test locally:

```
docker run --name my-container1 myapp
```

This command above will keep the container on. You will need to delete it.

`docker ps` to get the container id and `docker container kill <id>` to delete
it.

If you want to automatically delete the container once it exits, run it with
`--rm`:

```
docker run --rm --name my-container11 myapp
```

- `docker run` creates and starts a new container from the specified image.
- ``--name my-container1`` assigns a name to the container (optional).
- `myapp` is the name of the Docker image you built.

If you want to use the `myapploop.sh` from the container:

```
docker run --name my-container2  --entrypoint /usr/local/bin/myapploop.sh myapp
```

When executing the loop you may want to add the following flags to enable
`control-c` to exit.

```
docker run -it --name my-container2  --entrypoint /usr/local/bin/myapploop.sh myapp
```

- `-i:` Keeps STDIN open even if not attached.
- `-t:` Allocates a pseudo-TTY.

To remove all containers:

```
docker rm $(docker ps -a -q)
```

### Copy the container image to Azure Container Registry (ACR)


Create resource group and ACR

```
az group create --name myResourceGroup --location eastus
az acr create --resource-group myResourceGroup --name <acrName> --sku Basic
```

Login to acr, get its full login name, tag local docker container image with the
container registry full login name, and push the image. Then list the images in
the container registry.

```
az acr login --name <acrName>
loginserver=$(az acr show --name <acrName> --query loginServer --output tsv)
docker tag myapp $loginserver/myapp:v1
docker push $loginserver/myapp:v1
az acr repository list --name <acrName> --output table
```

Get service principal id and password with the script below as described in
[here](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-auth-aci).
The script, which is called `setup_serviceprincipal.sh`,  is also in this
folder.

```
export containerRegistry=<acrName>
export servicePrincipal=<acrName>sp
bash setup_serviceprincipal.sh
```

Use the Id and password of the service principal on the following command:

```
az container create --resource-group myResourceGroup \
                    --name mycontainer1 \
                    --image $loginserver/myapp:v1 \
                    --cpu 1 --memory 1 --registry-login-server $loginserver \
                    --registry-username <service-principal-ID> --registry-password <service-principal-password> --ip-address Public
```

You can see the stdout of this running container:

```
az container list --output table
az container logs --resource-group <ResourceGroupName> --name <ContainerInstanceName>

```

To delete the running container:

```
az container delete --resource-group <ResourceGroupName> --name
<ContainerInstanceName>
```

To delete the resource group:

```
az group delete --name myResourceGroup
```

To delete the service principal:


```
az ad sp list --display-name MyServicePrincipal --query "[].{appId:appId, displayName:displayName}"
az ad sp delete --id <id>
```
