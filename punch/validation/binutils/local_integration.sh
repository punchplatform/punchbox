#! /bin/bash

# This shell launch automaticaly punchbox with current pp-punch. Results are published in slack 
# Two vars are mandatory and specific to this script: 
#   - PUNCHBOX_DIR=/home/punch/workspace/pp-integration-vagrant
#   - PUNCH_DIR=/home/punch/workspace/craig/pp-punch
# Vars from current user are also used by maven and pex when building repository. Be sure that they are available 
# if you use a non-interactive shell (cron for example)

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

if [[ $# -eq 0 ]] ; then
    echo -e "${RED}ERROR:${RESET} You must provide a branch version (same for punchbox and pp-punch) $1"
    exit 1
fi

echo -e "${GREEN}INFO:${RESET} Build pp-punch branch $1"

cd $PUNCH_DIR
git checkout $1
git pull
mvn clean install -DskipTests -T 2C


cd $PUNCHBOX_DIR
git checkout $1
git pull
DEPLOYER_ZIP=$(ls -of $PUNCH_DIR/pp-packaging/punchplatform-deployer/target/punchplatform-deployer-*.zip)
PUNCHCONF=$(realpath $PUNCH_DIR/pp-packaging/punchplatform-standalone/punchplatform-standalone-linux/target/tmp/punchplatform-standalone-*/conf)

echo -e "${GREEN}INFO:${RESET} Launch punchbox with deployer : $DEPLOYER_ZIP and config : $PUNCHCONF"

make install
source activate.sh
punchbox --deployer $DEPLOYER_ZIP --config configurations/complete_punch_32G.json --punch-conf $PUNCHCONF --generate-vagrantfile --start-vagrant
source $PUNCHBOX_DIR/activate.sh
punchplatform-deployer.sh --generate-platform-config --templates-dir $PUNCHBOX_DIR/punch/platform_template/ --model $PUNCHBOX_DIR/punch/build/model.json
punchplatform-deployer.sh -gi
punchplatform-deployer.sh deploy -u vagrant

echo -e "${GREEN}INFO:${RESET} Launch check platform "

cd $PUNCHBOX_DIR/vagrant
vagrant ssh server1 -c "/home/vagrant/pp-conf/check_platform.sh; exit"

echo -e "${GREEN}INFO:${RESET} Destroy boxes"
vagrant destroy --force

echo -e "${GREEN}INFO:${RESET} End of automatic test, check slack integration channel to get results"
exit 1
