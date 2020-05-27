#!/bin/bash -u
function red () { tput setaf 1; echo "$*" ; tput sgr0;}
function green () { tput setaf 2; echo "$*" ; tput sgr0;}

green "Starting punchbox installation"
here=`pwd`
deployerName=''

green "cleaning any previous installation"
punchBoxPex="bin/pex/punchbox_pex/punchbox.pex"
ansibleBoxPex="bin/pex/ansible_pex/ansible.pex"
rm -rf "${punchBoxPex}"
rm -rf "${ansibleBoxPex}"
rm -rf ./punch/build
rm -rf ./vagrant/Vagrantfile
rm -rf ./ansible/punchbox.*
rm -rf ./activate.sh

green "generating ${punchBoxPex}"
pex -r ./bin/pex/punchbox_pex/requirements.txt --disable-cache --inherit-path -v -o ./bin/pex/punchbox_pex/punchbox.pex
green "generating ${ansibleBoxPex}"
pex -r ./bin/pex/ansible_pex/requirements.txt --disable-cache --inherit-path -v -o ./bin/pex/ansible_pex/ansible.pex

if [ $? -eq 0 ]; then
    cd ${here}
    green "Successfully generated pex files ${punchBoxPex} ${ansibleBoxPex}"
    echo "export PUNCHBOX_DIR=${here}" > ./activate.sh
    echo "export PUNCHPLATFORM_CONF_DIR=${here}/punch/build/pp-conf" >> ./activate.sh
    echo "export PATH=\${PATH}:${here}/bin" >> ./activate.sh 
    echo "export PS1='\[\e[1;32m\]punchbox:\[\e[0m\][\W]\$ '" >> ./activate.sh
    echo "export PATH=${here}/bin/pex/ansible_pex:\${PATH}" >> ./activate.sh
    green "Make sure you source ./activate.sh before continuing"
    exit 0
else
    red "Failed to generate pex files ${punchBoxPex} ${ansibleBoxPex}"
    exit 1
fi
