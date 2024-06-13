### Example with Azure Batch+Container+PythonSDK


#### example 1

This example, runs a task based on a container stored in an Azure Container
Registry (ACR). It
- creates a batch account
- creates a pool
- creates a job
- creates a task

Assumptions:
- there is gonna be only one batch account in the resource group (created by the
script).
- there is an ACR with a container image (publically accessible)
- there is a user managed identity to allow AcrPull from ACR


Install these libraries:

```
pip install azure-mgmt-batch azure-mgmt-authorization azure-mgmt-containerregistry azure-identity azure-mgmt-resource
```


You need to update the `config.json` file:
```
{
  "subscription": "<replace>",
  "rg": "<replace>",
  "region": "eastus",
  "acrserver": "<replace>.azurecr.io",
  "acrimage": "<replace>",
  "acrimage_tag": "latest",
  "acruseridentity": "/subscriptions/<subscription id>/resourceGroups/<resourcegroup>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity>"
}
```



You also need the credentials of the ACR: user and password

Instead of having this info in the `config.json`, please set up the variables:

```
export ACR_USERNAME=<replace>
export ACR_PASSWORD=<replace>
```

Then run:

```
python batchexample1.py config.json
```

Don't forget to delete your resources and resource group after you finish your
testing.

### References

- Batch+Container: [link](https://learn.microsoft.com/en-us/azure/batch/batch-docker-container-workloads)
- Batch+ContainerRegistry+UserIdentity: [link](https://learn.microsoft.com/en-us/python/api/azure-batch/azure.batch.models.containerregistry?view=azure-python)
- Batch PoolAddParameter: [link](https://learn.microsoft.com/en-us/python/api/azure-batch/azure.batch.models.pooladdparameter?view=azure-python)
- Batch Management API - Pool: [link](https://learn.microsoft.com/en-us/python/api/azure-mgmt-batch/azure.mgmt.batch.models.pool?view=azure-python)
- Batch Management API - BatchManagementClient: [link](https://learn.microsoft.com/en-us/python/api/azure-mgmt-batch/azure.mgmt.batch.batchmanagementclient?view=azure-python)
- Azure control plane vs data plane:[link](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/control-plane-and-data-plane)



