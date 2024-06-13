### Example with Azure Batch+Container+PythonSDK


#### Example 1

This example, runs a bash script from a container, in which its image comes from an existing Azure Container
Registry (ACR). It:
- creates a batch account
- creates a pool
- creates a job
- creates a task

Assumptions:
- there is no storage account here to work with input and output files
- there is gonna be only one batch account in the resource group (created by the
script).
- there is an ACR with a container image (publically accessible)
- there is a user managed identity to allow AcrPull from ACR
- image definition (ubuntu) is hardcoded
- number of nodes is hardcoded
- this code creates one pool, one job, and one task. Anything different, needs
to be modified
- this is just a simple python-based code to run batch+container; it is not
a production ready solution


```
git clone https://github.com/marconetto/proj-atlantis1.git
cd proj-atlantis1/batchexample1/
```

Install these libraries:

```
pip install azure-mgmt-batch \
            azure-mgmt-authorization \
            azure-mgmt-containerregistry \
            azure-identity azure-mgmt-resource
```

```
cp config_template.json config.json
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



