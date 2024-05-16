# proj-atlantis1


Some automation for VM creation and azure batch scripts.


## Automation of atlantis VM via cloud-init


Use the `create_vm.sh` [bash](https://www.gnu.org/software/bash/) script from `singlevm` folder.

The script:
- provisions a VM, which calls a git hosted automation bash script containing
all instructions to install atlantis + rstudio and other dependencies.
- allows specification of a disk size (in GB) to be added to the VM, which will be
mounted as the new home directory.


You can run this script from an environment that supports bash, which could be:
- macos
- linux
- windows via [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) or [cygwin](https://www.cygwin.com/)
- [cloud shell via azure portal](https://shell.azure.com/)

```
git clone https://github.com/marconetto/proj-atlantis1.git
cd proj-atlantis1/singlevm
```

```
Usage: ./create_vm.sh -p <env|vm> -r <resourcegroup> -vnet <vnet> -subnet <subnet> [ -d <disksize> ] [ -a <ipaddress> ]
  -p <env|vm>         Provision environment (env) or VM (vm)
  -r <resourcegroup>  Specify resource group
  -v <vnet>           Specify virtual network
  -s <subnet>         Specify subnet
  -d <disksize>       Specify disk size in GB (optional)
  -a <ipaddress>      Specify ip address for vnet (e.g. 10.51.0.1)
```

The `env` option provisions a resource group, vnet, subnet, and the vm. Whereas
the `vm` option provisions only the vm on an existing resource group, vnet,
subnet.

Inside the script there is a variable to specify the automation script url:
`AUTOMATIONSCRIPT="https://raw.githubusercontent.com/marconetto/proj-atlantis1/main/singlevm/ubuntu_atlantisvm_install.sh"`

Once the script is executed, you will be asked to create an admin password for
the VM (twice).

Example of output run:

```
./create_vm.sh -p vm -r nettonoaa20240516v1 -v nettonoaa20240516v1VNET -s nettonoaa20240516v1SUBNET -d 50
>> Enter VM admin password:
>> Enter VM admin password(confirm):
Provisioning vm: vmatlantis_9050
{
  "fqdns": "",
  ....
  "zones": ""
}
Private IP of vmatlantis_9050: 10.51.0.14
Public IP of vmatlantis_9050: ....
```


You can then ssh into the machine:

```
ssh azureuser@<ip>
```

Once you are there, the automation script will still be running. You can see
that by typing:

```
tail -f /var/log/cloud-init-output.log
```

The `create_vm.sh` script creates a file called `automation_done` in the home
directory so you know the automation is done.


To access RStudio, open the browser with: `<ip>:8787`

<img src=".//figs/rstudio.png" title="Default title" alt="alt text" style="display: block; margin: auto;" />



