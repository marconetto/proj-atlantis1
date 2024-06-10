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


Once you have your container image tested locally, you can use the
`container_end2end.sh` script to perform the following tasks:
- create resource group, vnet, subnets, ACR, user managed identity
- push image to ACR
- create a container

Note, in this script we are using user managed identity. If you want to use
service principal, check the Appendix below.

This script can make use of a file called `myips.txt`, in which each line of
this file contains a public IP address that is allowed to push images to ACR.
By default, we add your public IP address obtained from `curl -s -4
ifconfig.co`. But the `myips.txt` may be useful if you have a more restricted
network in which the your public IP address may be different (e.g. due to NAT).

Usage:

```
./Usage: ./container_end2end.sh -r <resourcegroup>  -a <ipaddress> [ -n <containername> ]
  -r <resourcegroup>  Resource group
  -n <containername>  Container name (optional)
  -a <ipaddress>      VNet IP address (e.g. 10.51.0.0)
```

Example:

```
./container_end2end.sh -r myresourcegroup -a 10.30.0.0 -n mycontainer1
```


ACR, vnet/subnets, user identity will be based on resource group name.



To delete the running container:

```
az container delete --resource-group <ResourceGroupName> --name
<ContainerInstanceName>
```

To delete the resource group:

```
az group delete --name myResourceGroup
```


### Appendix: using service principal


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
                    --image $loginserver/myapp::latest \
                    --cpu 1 --memory 1 --registry-login-server $loginserver \
                    --registry-username <service-principal-ID> --registry-password <service-principal-password> --ip-address Public
```

To delete the service principal:

```
az ad sp list --display-name MyServicePrincipal --query "[].{appId:appId, displayName:displayName}"
az ad sp delete --id <id>
```


## References
- container and managed identity: <https://learn.microsoft.com/en-us/azure/container-instances/container-instances-managed-identity>
- container and managed identity: <https://learn.microsoft.com/en-us/azure/container-registry/container-registry-tasks-authentication-managed-identity>
- limitations container registry and managed identity
<https://learn.microsoft.com/en-us/azure/container-instances/using-azure-container-registry-mi#limitations>
- create  container registry: <https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-azure-cli>
