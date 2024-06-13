import json
import os
import random
import sys

import azure.batch.models as batchmodels
import azure.mgmt.batch.models as batchmgmtmodels
from azure.batch import BatchServiceClient
from azure.identity import DefaultAzureCredential
from azure.mgmt.batch import BatchManagementClient
from azure.mgmt.batch.models import (
    BatchAccountCreateParameters,
    PoolAllocationMode,
    ResourceIdentityType,
)
from azure.mgmt.resource import ResourceManagementClient, SubscriptionClient

from azure_identity_credential_adapter import AzureIdentityCredentialAdapter

myconfig = {}


def get_subscription_id(subscription_name):
    credential = DefaultAzureCredential()

    subscription_client = SubscriptionClient(credential)

    for sub in subscription_client.subscriptions.list():
        if sub.display_name == subscription_name:
            return sub.subscription_id

    return None


def create_batch_account(subscription, rg, account_name, region):

    batch_account_params = BatchAccountCreateParameters(
        location=region,
        auto_storage=None,
        identity={
            "type": ResourceIdentityType.system_assigned,
        },
    )
    batch_mgmt_client = BatchManagementClient(credential, subscription)

    batch_account = batch_mgmt_client.batch_account.begin_create(
        rg, account_name, batch_account_params
    ).result()

    batch_url = batch_account.account_endpoint
    print("Batch URL: " + str(batch_url))


def setup_config(configfile):

    if not os.path.exists(configfile):
        print("Config file not found: " + configfile)
        sys.exit(1)

    with open(configfile) as f:
        myconfig = json.load(f)

    required_keys = [
        "subscription",
        "rg",
        "region",
        "acrserver",
        "acrimage",
        "acrimage_tag",
    ]

    for key in required_keys:
        if key not in myconfig:
            print(f"Missing key in config file: {key}")
            sys.exit(1)

    myconfig["subscription_name"] = myconfig["subscription"]
    myconfig["subscription"] = get_subscription_id(myconfig["subscription"])
    myconfig["batch_account_name"] = myconfig["rg"] + "ba"

    return myconfig


def _get_credentials():
    return DefaultAzureCredential()


def _get_batch_endpoint(credentials, subscription_id, resource_group):
    """assumes single batch account in resource group"""

    rm_client = ResourceManagementClient(credentials, subscription_id)
    items = rm_client.resources.list_by_resource_group(resource_group)

    for resource in items:
        if resource.type == "Microsoft.Batch/batchAccounts":
            return f"https://{resource.name}.{resource.location}.batch.azure.com"

    print(f"Cannot obtain batch endpoint: rg={resource_group} subid={subscription_id}")

    return None


def _get_batch_mgmt_client(subscription_id, resource_group):

    credentials = _get_credentials()
    batch_mgmt_client = BatchManagementClient(credentials, subscription_id)

    return batch_mgmt_client


def _get_batch_client(subscription_id, resource_group):
    """https://github.com/Azure/azure-sdk-for-python/issues/15330
    https://github.com/Azure/azure-sdk-for-python/issues/14499
    """

    credentials = _get_credentials()
    batch_endpoint = _get_batch_endpoint(credentials, subscription_id, resource_group)

    batch_client = BatchServiceClient(
        AzureIdentityCredentialAdapter(
            credentials, resource_id="https://batch.core.windows.net/"
        ),
        batch_endpoint,
    )

    return batch_client


def create_pool(batch_client):

    pool_name = "mypool" + str(random.randint(1, 1000))
    acruseridentity = myconfig["acruseridentity"]

    image_ref_to_use = batchmgmtmodels.ImageReference(
        publisher="microsoft-dsvm", offer="ubuntu-hpc", sku="2204", version="latest"
    )

    container_registry = None
    if "ACR_USERNAME" in os.environ and "ACR_PASSWORD" in os.environ:
        print("using ACR_USERNAME and ACR_PASSWORD to authenticate to ACR")
        user_name = os.environ["ACR_USERNAME"]
        password = os.environ["ACR_PASSWORD"]

        container_registry = batchmgmtmodels.ContainerRegistry(
            registry_server=myconfig["acrserver"],
            user_name=user_name,
            password=password,
        )
    elif "acruseridentity" in myconfig:
        print(
            f"using acruseridentity from config to ACR: {myconfig['acruseridentity']}"
        )
        container_registry = batchmgmtmodels.ContainerRegistry(
            registry_server=myconfig["acrserver"],
            identity_reference=batchmgmtmodels.ComputeNodeIdentityReference(
                resource_id=acruseridentity,
            ),
        )
    else:
        print("No ACR credentials found")
        sys.exit(1)

    container_image = (
        myconfig["acrserver"]
        + "/"
        + myconfig["acrimage"]
        + ":"
        + myconfig["acrimage_tag"]
    )
    container_conf = batchmgmtmodels.ContainerConfiguration(
        type="dockerCompatible",
        container_image_names=[container_image],
        container_registries=[container_registry],
    )

    new_pool = batchmgmtmodels.Pool(
        vm_size="STANDARD_D2S_V3",
        deployment_configuration=batchmgmtmodels.DeploymentConfiguration(
            virtual_machine_configuration=batchmgmtmodels.VirtualMachineConfiguration(
                image_reference=image_ref_to_use,
                node_agent_sku_id="batch.node.ubuntu 22.04",
                container_configuration=container_conf,
            )
        ),
        scale_settings=batchmgmtmodels.ScaleSettings(
            fixed_scale=batchmgmtmodels.FixedScaleSettings(
                target_dedicated_nodes=1,
            )
        ),
        identity=batchmgmtmodels.BatchPoolIdentity(
            type="UserAssigned",
            user_assigned_identities={
                acruseridentity: batchmgmtmodels.UserAssignedIdentities()
            },
        ),
    )

    print("creating pool " + pool_name)

    batch_client.pool.create(
        myconfig["rg"], myconfig["batch_account_name"], pool_name, new_pool
    )

    return pool_name


def create_job(batch_client, pool_id):

    job_id = "myjob" + str(random.randint(1, 1000))

    job = batchmodels.JobAddParameter(
        id=job_id,
        pool_info=batchmodels.PoolInformation(
            pool_id=pool_id,
        ),
    )

    print("creating job " + job_id)
    batch_client.job.add(job)

    return job_id


def create_task(batch_client, job_id):

    acrserver = myconfig["acrserver"]
    acrimage = myconfig["acrimage"]
    acrimage_tag = myconfig["acrimage_tag"]
    image_name = acrserver + "/" + acrimage + ":" + acrimage_tag

    task_id = "mytask" + str(random.randint(1, 1000))

    command_line = f"/bin/sh -c '/usr/local/bin/myapp.sh random_input_{task_id}'"
    container_run_options = "--rm"

    container_settings = batchmodels.TaskContainerSettings(
        image_name=image_name,
        container_run_options=container_run_options,
    )

    user = batchmodels.UserIdentity(
        auto_user=batchmodels.AutoUserSpecification(
            scope=batchmodels.AutoUserScope.pool,
            elevation_level=batchmodels.ElevationLevel.admin,
        )
    )

    task = batchmodels.TaskAddParameter(
        id=task_id,
        user_identity=user,
        container_settings=container_settings,
        command_line=command_line,
    )

    batch_client.task.add(job_id=job_id, task=task)
    print("Task created: " + task_id)

    return task_id


def get_subscription(subscription_name):
    credential = DefaultAzureCredential()

    subscription_client = SubscriptionClient(credential)

    for sub in subscription_client.subscriptions.list():
        if sub.display_name == subscription_name:
            return sub

    return None


def get_tenant_id(subscription_name):
    credential = DefaultAzureCredential()
    sub = get_subscription(subscription_name)

    if sub is None:
        print("Cannot find subscription: " + subscription_name)
        sys.exit(1)

    tenant_id = sub.tenant_id
    return tenant_id


args = sys.argv
if len(args) != 2:
    print("Usage: mybatch.py <configfile>")
    sys.exit(1)

myconfig = setup_config(args[1])

credential = DefaultAzureCredential()

myconfig["tenant_id"] = get_tenant_id(myconfig["subscription_name"])

create_batch_account(
    myconfig["subscription"],
    myconfig["rg"],
    myconfig["batch_account_name"],
    myconfig["region"],
)
#
batch_client = _get_batch_client(myconfig["subscription"], myconfig["rg"])
batch_mgmt_client = _get_batch_mgmt_client(myconfig["subscription"], myconfig["rg"])

pool_id = create_pool(batch_mgmt_client)
job_id = create_job(batch_client, pool_id)
task_id = create_task(batch_client, job_id)
