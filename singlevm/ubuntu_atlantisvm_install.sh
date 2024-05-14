#!/bin/bash

# wait for the lock to be released
alias apt-get='apt-get -o DPkg::Lock::Timeout=-1'

function retry_installer() {
  local attempts=0
  local max=15
  local delay=25

  while true; do
    ((attempts++))
    "$@" && {
      echo "CLI installed"
      break
    } || {
      if [[ $attempts -lt $max ]]; then
        echo "CLI installation failed. Attempt $attempts/$max."
        sleep $delay
      else
        echo "CLI installation has failed after $attempts attempts."
        break
      fi
    }
  done
}

function install_azure_cli() {
  install_script="/tmp/azurecli_installer.sh"
  curl -sL https://aka.ms/InstallAzureCLIDeb -o "$install_script"
  retry_installer sudo bash "$install_script"
  rm $install_script
}

echo "This script expects Ubuntu Server 20.04.2 LTS (Focal Fossa)"
echo "Will install all dependencies, libraries, Rstudio and needed packages to run Atlantis and analyze output"

sudo timedatectl set-timezone America/Los_Angeles

sudo apt-get update -y
sudo apt-get dist-upgrade -y

sudo apt-get -y --no-install-recommends install \
  autoconf \
  automake \
  libcurl4 \
  libcurl4-openssl-dev \
  curl \
  gdal-bin \
  flip \
  libcairo2 \
  libharfbuzz-dev \
  libfribidi-dev \
  libcairo-5c0 \
  libapparmor1 \
  libhdf5-dev \
  libnetcdf-dev \
  libxml2-dev \
  libssl-dev \
  libv4l-0 \
  libgeotiff5 \
  libglu1-mesa-dev \
  libpoppler-cpp-dev \
  libprotobuf-dev \
  librsvg2-dev \
  libx11-dev \
  lsscsi \
  openjdk-8-jdk \
  python2 \
  proj-data \
  protobuf-compiler \
  htop \
  openssl \
  rpm \
  mesa-common-dev \
  netcdf-bin \
  ntp \
  ntpdate \
  texlive-latex-extra \
  nco \
  cdo \
  unzip \
  gfortran

sudo apt-get install -y subversion make

cd /tmp || exit
svn co http://svn.osgeo.org/metacrs/proj/branches/4.8/proj/ --non-interactive --trust-server-cert-failures unknown-ca,cn-mismatch,expired,not-yet-valid,other
cd /tmp/proj/nad || exit
sudo wget http://download.osgeo.org/proj/proj-datumgrid-1.5.zip

unzip -o -q proj-datumgrid-1.5.zip

#make distclean

cd /tmp/proj/ || exit

./configure && make -j$(nproc) && sudo make install && sudo ldconfig

#these might be needed to install spatial R programs but can conflict with Atlantis proj4

#https://github.com/r-spatial/sf#multiple-gdal-geos-andor-proj-versions-on-your-system
#https://stackoverflow.com/questions/60759865/error-when-installing-sf-in-r-double-free-or-corruption
#to remove a respository https://askubuntu.com/questions/866901/what-can-i-do-if-a-repository-ppa-does-not-have-a-release-file
#sudo add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable
#sudo apt-get update -y
#sudo apt-get upgrade -y
#sudo apt-get dist-upgrade -y
#sudo apt-get install libudunits2-dev libgdal-dev libgeos-dev -y

#sudo add-apt-repository -y ppa:opencpu/jq
#sudo apt-get update -qq
#sudo apt-get install libjq-dev -y

sudo apt-get -f install -y # missing dependencies
sudo apt autoremove -y     #unused packages

echo "Install R"
#http://cran.rstudio.com/bin/linux/ubuntu/
# update indices
sudo apt update -qq
# install two helper packages we need
sudo apt install --no-install-recommends software-properties-common dirmngr
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
# add the R 4.0 repo from CRAN -- adjust 'focal' to 'groovy' or 'bionic' as needed
sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
sudo apt install --no-install-recommends r-base -y
sudo add-apt-repository ppa:c2d4u.team/c2d4u4.0+ -y

echo "Install R studio"

sudo apt-get install gdebi-core -y
wget https://download2.rstudio.org/server/focal/amd64/rstudio-server-2023.12.1-402-amd64.deb

# try gdebi multiple times 10 times as there may be some lock issues
attempts=10
while ! sudo gdebi --n rstudio-server-2023.12.1-402-amd64.deb; do
  ((attempts--))
  if [ $attempts -eq 0 ]; then
    echo "Failed to install RStudio"
    exit 1
  fi
  echo "Failed to install RStudio. Retrying..."
  sleep 5
done

echo "Install AzCopy"

#to uninstall azcopy use https://github.com/MicrosoftDocs/azure-docs/issues/18771
wget -O azcopy_linux_amd64_10.20.1.tar https://aka.ms/downloadazcopy-v10-linux
tar -xzf azcopy_linux_amd64_10.20.1.tar
sudo cp ./azcopy_linux_amd64_*/azcopy /usr/bin/

if ! command -v az &>/dev/null; then
  echo "Installing Azure CLI"
  install_azure_cli
fi

# sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg
#
# sudo mkdir -p /etc/apt/keyrings
# curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
#   gpg --dearmor |
#   sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
# sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
#
# AZ_REPO=$(lsb_release -cs)
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
#   sudo tee /etc/apt/sources.list.d/azure-cli.list

# sudo apt-get update
# if [ -d "$HOME"/bin ]; then
#   PATH=$PATH:$HOME/bin
# fi
