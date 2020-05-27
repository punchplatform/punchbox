#! /bin/bash

# This shell launch automaticaly punchbox repository with a fresh build of pp-punch. Results are published in a specific slack channel 
# Two vars are mandatory and specific to this script: 
#   - INTEGRATION_DIR
#   - PUNCH_DIR
# Vars from current user are also used by maven and pex when building repository. Be sure that they are available 
# if you use a non-interactive shell (cron for example)

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

if [[ $# -eq 0 ]] ; then
    echo -e "${RED}ERROR:${RESET} You must provide a branch version (same for punchbox and pp-punch repositories) $1"
    exit 1
fi

export INTEGRATION_DIR=/data/punchbox
export PUNCH_DIR=/data/pp-punch
ANSIBLE_PUNCHBOX_VM=adm-infra@10.10.1.11
DEPLOYER_VM=adm-infra@10.10.13.198
OPERATOR_VM=adm-infra@10.10.13.191


echo -e "${GREEN}INFO:${RESET} Build pp-punch branch $1"

cd $PUNCH_DIR
git checkout $1
git pull
#mvn clean install -Dmaven.repo.local=/data/.m2/repository -DskipTests

DEPLOYER_ZIP=$(ls -of $PUNCH_DIR/pp-packaging/punchplatform-deployer/target/punchplatform-deployer-*.zip)
PUNCHCONF=$(realpath $PUNCH_DIR/pp-packaging/punchplatform-standalone/punchplatform-standalone-linux/target/tmp/punchplatform-standalone-*/conf)

cd $INTEGRATION_DIR
git checkout $1
git pull


echo -e "${GREEN}INFO:${RESET} Launch pp-integration with deployer : $DEPLOYER_ZIP and config : $PUNCHCONF"

make install
source activate.sh
punchbox --deployer $DEPLOYER_ZIP --config configurations/CI_punch.json --punch-conf $PUNCHCONF --generate-inventory --generate-playbook
source $INTEGRATION_DIR/activate.sh
punchplatform-deployer.sh --generate-platform-config --templates-dir $INTEGRATION_DIR/punch/platform_template/ --model $INTEGRATION_DIR/punch/build/model.json


echo -e "${GREEN}INFO:${RESET} Transfert data to ansible VM"
scp -r $INTEGRATION_DIR/ansible/punchbox.* $INTEGRATION_DIR/ansible/ansible.cfg $DEPLOYER_ZIP $INTEGRATION_DIR/punch/build/pp-conf $ANSIBLE_PUNCHBOX_VM:/data/punchbox-workspace/

echo -e "${GREEN}INFO:${RESET} Create deployer and targets VM"
ssh $ANSIBLE_PUNCHBOX_VM << EOF
cd $INTEGRATION_DIR/ && git pull
ansible-playbook -i /data/punchbox-workspace/punchbox.inv ~/pp-pbx-asb/deploy-vms.yml
EOF

sleep 120 

# Workaround : 
#       - to have permission to write ansible tmp files in /data
#       - to enable non interactive shell
#       - to copy private key from ansible VM
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_ansible $DEPLOYER_VM << EOF
sudo chown adm-infra /data
sed -i '5,10d' /home/adm-infra/.bashrc
EOF
scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_ansible ~/.ssh/id_rsa_ansible $DEPLOYER_VM:/home/adm-infra/.ssh/

sleep 120

echo -e "${GREEN}INFO:${RESET} Configure deployer"
ssh $ANSIBLE_PUNCHBOX_VM << EOF
export ANSIBLE_CONFIG=/data/punchbox-workspace/ansible.cfg
ansible-playbook -i /data/punchbox-workspace/punchbox.inv /data/punchbox-workspace/punchbox.yml -l pp_deployers
EOF

echo -e "${GREEN}INFO:${RESET} Configure targets"
ssh $ANSIBLE_PUNCHBOX_VM << EOF
cd /data/punchbox/ansible/roles
ansible-playbook -i /data/punchbox-workspace/punchbox.inv /data/punchbox-workspace/punchbox.yml -l pp_targets
EOF

sleep 120

echo -e "${GREEN}INFO:${RESET} Deploy punchplatform"
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_ansible $DEPLOYER_VM << EOF
punchplatform-deployer.sh -gi
punchplatform-deployer.sh deploy -u adm-infra --private-key ~/.ssh/id_rsa_ansible
EOF

echo -e "${GREEN}INFO:${RESET} Transfert conf to operator node"
scp -r -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_ansible $INTEGRATION_DIR/punch/build/pp-conf $OPERATOR_VM:

echo -e "${GREEN}INFO:${RESET} Execute check platform on operator node"
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_ansible $OPERATOR_VM << EOF
sed -i '5,10d' /home/adm-infra/.bashrc
source ~/.bashrc
./pp-conf/check_platform.sh
EOF
    
echo -e "${GREEN}INFO:${RESET} Shutdown VMs"
boxes=$(cat $INTEGRATION_DIR/ansible/punchbox.inv | grep -v vm | grep  pbci) 
for box in $boxes; do ssh $ANSIBLE_PUNCHBOX_VM "ssh adm-infra@$box 'sudo shutdown -h now'"; done

sleep 240 

echo -e "${GREEN}INFO:${RESET} Destroy VMs"
ssh $ANSIBLE_PUNCHBOX_VM "~/pp-pbx-asb/cleanup_vm.sh pbciserver --non-interactive"
ssh $ANSIBLE_PUNCHBOX_VM "~/pp-pbx-asb/cleanup_vm.sh pbcideployer --non-interactive"

echo -e "${GREEN}INFO:${RESET} Cleaning working directory"
ssh $ANSIBLE_PUNCHBOX_VM "rm -r /data/punchbox-workspace/*"

echo -e "${GREEN}INFO:${RESET} End of automatic test, check slack integration channel to get results"
exit 1
