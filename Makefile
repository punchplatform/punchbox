.DEFAULT_GOAL:=help
SHELL:=/bin/bash
# Static vars
DIR=$(shell pwd)
MAKE=$(shell which make)
BASH=$(shell which bash)
SH=$(shell which sh)
VAGRANT=$(shell which vagrant)
PUNCHBOX_PEX_REQUIREMENTS=${DIR}/bin/pex/punchbox_pex/requirements.txt
ANSIBLE_PEX_REQUIREMENTS=${DIR}/bin/pex/ansible_pex/requirements.txt
PUNCHBOX_PEX=${DIR}/bin/pex/punchbox_pex/punchbox.pex
ANSIBLE_PEX=${DIR}/bin/pex/ansible_pex/ansible.pex
ACTIVATE_SH=${DIR}/activate.sh
ACTIVATE_TEMPLATE=${DIR}/.activate.template
DEFAULT_DEPLOYER_ZIP_PATH=${DIR}/../pp-punch/packagings/punch-deployer/target/punch-deployer-*.zip
PUNCHBOX_SCRIPT_DIR=$(shell realpath ~/.config)/systemd/user
VALIDATION=""
VALIDATION_SERVICE_NAME=punch-validation.service
VALIDATION_TIMER_NAME=punch-validation.timer
VALIDATION_SERVICE_SCRIPT=${PUNCHBOX_SCRIPT_DIR}/${VALIDATION_SERVICE_NAME}
VALIDATION_TIMER_SCRIPT=${PUNCHBOX_SCRIPT_DIR}/${VALIDATION_TIMER_NAME}
MLFLOW_SERVER=$(shell jq -r ".mlflow.servers | to_entries[0].key" punch/build/pp-conf/punchplatform-deployment.settings)


VENV_MARKERFILE=${DIR}/.venv/.installed
DEPENDENCIES_INSTALLED_MARKERFILE=${DIR}/vagrant/.dependencies_installed
PEX_GENERATED_MARKERFILE=${DIR}/bin/pex/.all_pex_generated
ALLTOOLS_INSTALLED_MARKERFILE=${DIR}/.alltools_installed

# Color Functions
ECHO=$(shell which echo)
cyan=${ECHO} -e "\x1b[36m $1\x1b[0m$2"
blue=${ECHO} -e "\x1b[34m $1\x1b[0m$2"
green=${ECHO} -e "\x1b[32m $1\x1b[0m$2"
red=${ECHO} -e "\x1b[31m $1\x1b[0m$2"

ifneq ("$(wildcard ${DIR}/vagrant/Vagrantfile)","")
	CLEANUP_COMMAND="cd ${DIR}/vagrant && ${VAGRANT} destroy -f"
else
	CLEANUP_COMMAND="echo '------>  Vagrantfile does not exist yet... Nothing to wipe <------'"
endif

ifeq ("$(wildcard ${DIR}/.deployer)","")
	ifeq ($(strip $(PUNCH_DIR)),)
		GENERATE_DEPLOYER_COMMAND="echo ${DEFAULT_DEPLOYER_ZIP_PATH} > ${DIR}/.deployer"
	else
		GENERATE_DEPLOYER_COMMAND="echo ${PUNCH_DIR}/packagings/punch-deployer/target/punch-deployer-*.zip > ${DIR}/.deployer"
	endif
else
	GENERATE_DEPLOYER_COMMAND="echo '------>  .deployer already exists... nothing to do <------'"
endif

ifeq (, $(shell which python3))
 $(error "No python3 installed, it is required. Make sure you also install python3 venv")
endif

${VENV_MARKERFILE}:
	@$(call blue, "************  CREATE PYTHON 3 .venv  VIRTUALENV  ************")
	@if [ ! -e "${DIR}/.venv/bin/activate" ] ; then python3 -m venv ${DIR}/.venv ; fi
	@. ${DIR}/.venv/bin/activate && pip install -U pip wheel setuptools -q
	@$(call blue, "Python 3 virtualenv installed:", "${DIR}/.venv")
	@touch $@

${ACTIVATE_SH}: ${ACTIVATE_TEMPLATE} Makefile
	@echo "  GENERATING '${ACTIVATE_SH}'..."
	@sed 's#.*PUNCHBOX_DIR=.*#export PUNCHBOX_DIR='${DIR}'#g' "${ACTIVATE_TEMPLATE}" > "${ACTIVATE_SH}"

${PEX_GENERATED_MARKERFILE}: ${VENV_MARKERFILE} ${PUNCHBOX_PEX_REQUIREMENTS} ${ANSIBLE_PEX_REQUIREMENTS} requirements.txt bin/punchbox.py
	@$(call green, "Installing PunchBox python dependencies virtualenv...")
	@. ${DIR}/.venv/bin/activate && pip install -r requirements.txt -q
	@$(call green, "************ BUILDING PEX PACKAGES for punchbox and Ansible ************")
	@. ${DIR}/.venv/bin/activate && pex -r ${PUNCHBOX_PEX_REQUIREMENTS} --disable-cache -o ${PUNCHBOX_PEX}
	@. ${DIR}/.venv/bin/activate && pex -r ${ANSIBLE_PEX_REQUIREMENTS} --disable-cache -o ${ANSIBLE_PEX}
	@touch $@

${DIR}/vagrant/.dependencies_installed:
	@which vagrant 1>/dev/null || { echo "'vagrant' command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@$(call green, "************ ADDING VAGRANT DEPENDENCIES ************")
	@cd ${DIR}/vagrant && ${VAGRANT} plugin install vagrant-disksize
	@cd ${DIR}/vagrant && ${VAGRANT} plugin install vagrant-vbguest
	@touch $@


${ALLTOOLS_INSTALLED_MARKERFILE}: ${VENV_MARKERFILE} ${DEPENDENCIES_INSTALLED_MARKERFILE} ${PEX_GENERATED_MARKERFILE} ${ACTIVATE_SH}
	@touch $@

##@ Welcome to PunchBox CLI
##@ With this Makefile, you will be able to setup a running PunchPlatform in no time
##@ Sequences of commands to be made are defined by steps, just follow them and let the magic happen !

##@ ***************************************************************************************************

##@ Step 1

.PHONY: install

install: ${ALLTOOLS_INSTALLED_MARKERFILE} ## Build Punchbox Prerequisites
	@$(call blue, "************  INSTALL STATUS ************")
	@[ -e "${HOME}/.ssh/id_rsa.pub" ] || { echo ".ssh/id_rsa.pub not found in user home directory. Maybe try running 'ssh-keygen' without specific option." 2>&1 && exit 42 ; }
	@which jq 1>/dev/null || { echo "jq command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which curl 1>/dev/null || { echo "curl command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which unzip 1>/dev/null || { echo "unzip command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which python 1>/dev/null || { echo "python (>3.6.8) must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@$(call green, "PunchBox pex:", "${PUNCHBOX_PEX}")
	@$(call green, "Ansible pex:", "${ANSIBLE_PEX}")
	@$(call green, "activate.sh:", "${ACTIVATE_SH}")
	@$(call green, "install complete", "type 'make' for available targets !")

##@ Step 2

.PHONY: configure-deployer

configure-deployer:  ## Setup deployer path in .deployer, change it to yours
	@$(call green, "Deployer zip path in .deployer change it\'s content to match yours:", "${DIR}/.deployer")
	@eval ${GENERATE_DEPLOYER_COMMAND}

deployed-configuration-32G: ${ALLTOOLS_INSTALLED_MARKERFILE}
	@echo ${DIR}/configurations/complete_punch_32G.json > ${DIR}/.deployed_configuration

deployed-configuration-16G: ${ALLTOOLS_INSTALLED_MARKERFILE}
	@echo ${DIR}/configurations/complete_punch_16G.json > ${DIR}/.deployed_configuration


##@ Step 3

##@   Deploy for validation or production a Ubuntu PunchBox

.PHONY: punchbox-ubuntu-16G punchbox-ubuntu-32G punchbox-ubuntu-32G-validation

punchbox-ubuntu-16G: deployed-configuration-16G  ## Generate all configurations for a punch deployment on ubuntu targets - 16GB 
	@$(call green, "Deploying 16G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_16G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --deployer $(shell cat ${DIR}/.deployer)

punchbox-ubuntu-32G: deployed-configuration-32G  ## Generate all configurations for a punch deployment on ubuntu targets - 32GB
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --deployer $(shell cat ${DIR}/.deployer)

punchbox-ubuntu-32G-security: deployed-configuration-32G  ## Generate all configurations for a punch deployment on ubuntu targets with RBAC security over the ELK configuration - 32GB
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --deployer $(shell cat ${DIR}/.deployer) \
				 --security

punchbox-ubuntu-32G-validation: deployed-configuration-32G  ## Generate all configurations for a punch deployment on ubuntu targets - 32GB
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --deployer $(shell cat ${DIR}/.deployer) \
				 --validation

##@   Deploy for validation or production a CentOS PunchBox

.PHONY: punchbox-centos-16G punchbox-centos-32G punchbox-centos-32G-validation

punchbox-centos-16G: deployed-configuration-16G  ## Generate all configurations for a punch deployment on ubuntu targets - 16GB
	@$(call green, "Deploying 16G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_16G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --os centos/7 \
				 --interface eth1 \
				 --deployer $(shell cat ${DIR}/.deployer)

punchbox-centos-32G: deployed-configuration-32G  ## Generate all configurations for a punch deployment on ubuntu targets - 32GB
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --os centos/7 \
				 --interface eth1 \
				 --deployer $(shell cat ${DIR}/.deployer)

punchbox-centos-32G-security: deployed-configuration-32G  ## Generate all configurations for a punch deployment on ubuntu targets with RBAC security over the ELK configuration - 32GB
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --os centos/7 \
				 --interface eth1 \
				 --deployer $(shell cat ${DIR}/.deployer) \
				 --security
				
punchbox-centos-32G-validation: deployed-configuration-32G  ## Generate all configurations for a punch deployment on ubuntu targets - 32GB
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --os centos/7 \
				 --interface eth1 \
				 --deployer $(shell cat ${DIR}/.deployer) \
				 --validation

##@ Step 4

.PHONY: start-vagrant

start-vagrant:  ${ALLTOOLS_INSTALLED_MARKERFILE}  ## Start vagrant boxes
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --start-vagrant

##@ Step 5

.PHONY: deploy-punch

deploy-punch:  ${ALLTOOLS_INSTALLED_MARKERFILE}  ## Deploy PunchPlatform to targets
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --generate-platform-config \
								  --templates-dir ${DIR}/punch/deployment_template/ \
								  --model ${DIR}/punch/build/model.json
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -gi
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --deploy -u vagrant

##@ Step 6

.PHONY: deploy-config local-integration-vagrant update-deployer-configuration

deploy-config:  ${ALLTOOLS_INSTALLED_MARKERFILE}  ## Deploys PunchPlatform configuration files to targets
	@. ${ACTIVATE_SH} && punchplatform-deployer.sh -cp -u vagrant

local-integration-vagrant:  ## Use this rule instead of deploy-config if you are planning to do validation
	@$(call green, "Copying Needed files to server1 for local integration test", "/home/vagrant/pp-conf")
	@. ${ACTIVATE_SH} && punchplatform-deployer.sh -cp -u vagrant
	@$(call green, "Check if vagrant boxes are up", "")
	@cd ${DIR}/vagrant && ${VAGRANT} up
	@cd ${DIR}/vagrant &&  ${VAGRANT} ssh ${MLFLOW_SERVER} -c "/data/mlflow_provisionner_src/provision-mlflow.sh; exit"
	@$(call green, "Executing on server1", "/home/vagrant/pp-conf/check_platform.sh")
	@cd ${DIR}/vagrant && ${VAGRANT} ssh server1 -c "/home/vagrant/pp-conf/check_platform.sh; exit"

update-deployer-configuration: ${ALLTOOLS_INSTALLED_MARKERFILE}  ## Use this rule to update validation platform configuration files
	@. ${ACTIVATE_SH} && punchbox --platform-config-file $(shell cat ${DIR}/.deployed_configuration) \
								--punch-user-config ${DIR}/punch/configurations/validation

##@ Setting Validation Scheduler with SystemD

.PHONY: validation-scheduler-ubuntu-32G validation-scheduler-centos-32G

validation-scheduler-ubuntu-32G:  ## Takes as parameter ex: hour=4 and punch_dir=/my/pp-punch, which will set a timer at 4 a.m everyday
	@[ "${hour}" ] || ( $(call red, "hour not set", "example hour=4"); exit 1 )
	@[ "${punch_dir}" ] || ( $(call red, "punch_dir not set", "example punch_dir=/home/punch/pp-punch"); exit 1 )
	@$(call green, "Generating systemd Scheduling script", "${PUNCHBOX_SCRIPT_DIR}")
	@mkdir -p ${PUNCHBOX_SCRIPT_DIR}
	@echo "[Unit]" > ${VALIDATION_SERVICE_SCRIPT}
	@echo "Description=run a local integration platform once each day at $(hour) oclock for Ubuntu 32G OS" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "[Service]" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo Environment="LIVEDEMO_API_URL=${LIVEDEMO_API_URL} PUNCH_DIR=$(punch_dir)" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "Type=oneshot" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "WorkingDirectory=${DIR}" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo ExecStart="${BASH} -c 'PATH=${PATH}; ${MAKE} clean; ${MAKE} install; ${MAKE} configure-deployer; ${MAKE} punchbox-ubuntu-32G-validation; ${MAKE} start-vagrant; ${MAKE} deploy-punch; ${MAKE} local-integration-vagrant'" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "[Install]" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "WantedBy=multi-user.target" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "[Unit]" > ${VALIDATION_TIMER_SCRIPT}
	@echo "Description=run a local integration platform once each day at time for Ubuntu 32G OS" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "[Timer]" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "Unit=${VALIDATION_SERVICE_SCRIPT}" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "OnCalendar=*-*-* $(hour):00:00" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "[Install]" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "WantedBy=timers.target" >> ${VALIDATION_TIMER_SCRIPT}
	@$(call green, "Setting script permission", "777 for service and timer")
	@chmod 777 ${VALIDATION_SERVICE_SCRIPT}
	@chmod 777  ${VALIDATION_TIMER_SCRIPT}
	@systemctl --user daemon-reload
	@$(call blue, "Adding service and timer to current user only", "systemctl --user start ${VALIDATION_TIMER_NAME}")
	@systemctl --user enable --now ${VALIDATION_TIMER_NAME}
	@systemctl --user enable ${VALIDATION_SERVICE_NAME}
	@systemctl --user start ${VALIDATION_TIMER_NAME}
	@$(call blue, "Next event will be on", "")
	@systemctl --user list-timers

validation-scheduler-centos-32G:  ## Takes as parameter ex: hour=4 and punch_dir=/my/pp-punch, which will set a timer at 4 a.m everyday
	@[ "${hour}" ] || ( $(call red, "hour not set", "example hour=4"); exit 1 )
	@[ "${punch_dir}" ] || ( $(call red, "punch_dir not set", "example punch_dir=/home/punch/pp-punch"); exit 1 )
	@$(call green, "Generating systemd Scheduling script", "${PUNCHBOX_SCRIPT_DIR}")
	@mkdir -p ${PUNCHBOX_SCRIPT_DIR}
	@echo "[Unit]" > ${VALIDATION_SERVICE_SCRIPT}
	@echo "Description=run a local integration platform once each day at $(hour) oclock for CentOS 32G OS" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "[Service]" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo Environment="LIVEDEMO_API_URL=${LIVEDEMO_API_URL} PUNCH_DIR=$(punch_dir)" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "Type=oneshot" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "WorkingDirectory=${DIR}" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo ExecStart="${BASH} -c 'PATH=${PATH}; ${MAKE} clean; ${MAKE} install; ${MAKE} configure-deployer; ${MAKE} punchbox-centos-32G-validation; ${MAKE} start-vagrant; ${MAKE} deploy-punch; ${MAKE} local-integration-vagrant'" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "[Install]" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "WantedBy=multi-user.target" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "[Unit]" > ${VALIDATION_TIMER_SCRIPT}
	@echo "Description=run a local integration platform once each day at time for CentOS 32G OS" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "[Timer]" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "Unit=${VALIDATION_SERVICE_SCRIPT}" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "OnCalendar=*-*-* $(hour):00:00" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "[Install]" >> ${VALIDATION_TIMER_SCRIPT}
	@echo "WantedBy=timers.target" >> ${VALIDATION_TIMER_SCRIPT}
	@$(call green, "Setting script permission", "777 for service and timer")
	@chmod 777 ${VALIDATION_SERVICE_SCRIPT}
	@chmod 777  ${VALIDATION_TIMER_SCRIPT}
	@systemctl --user daemon-reload
	@$(call blue, "Adding service and timer to current user only", "systemctl --user start ${VALIDATION_TIMER_NAME}")
	@systemctl --user enable --now ${VALIDATION_TIMER_NAME}
	@systemctl --user enable ${VALIDATION_SERVICE_NAME}
	@systemctl --user start ${VALIDATION_TIMER_NAME}
	@$(call blue, "Next event will be on", "")
	@systemctl --user list-timers

##@ Cleanup

.PHONY: clean clean-deployer clean-punch-config clean-vagrant clean-validation-scheduler

clean: clean-vagrant clean-deployer ## Cleanup vagrant and deployer
	@$(call blue, "************  CLEAN  ************")
	@rm -rf ${DIR}/.venv
	@rm -rf ${DIR}/punch/build
	@rm -rf ${DIR}/activate.sh
	@rm -rf ${DIR}/bin/pex/punchbox_pex/punchbox.pex
	@rm -rf ${DIR}/bin/pex/ansible_pex/ansible.pex
	@rm -rf ${PEX_GENERATED_MARKERFILEX}
	@rm -rf ${DEPENDENCIES_INSTALLED_MARKERFILE}
	@rm -rf ${ALLTOOLS_INSTALLED_MARKERFILE}
	@rm -rf ${DIR}/ansible/punchbox.*
	@-find ${DIR} -name '*.pyc' -exec rm -f {} +
	@-find ${DIR} -name '*.pyo' -exec rm -f {} +
	@-find ${DIR} -name '*~' -exec rm -f {} +
	@-find ${DIR} -name '__pycache__' -exec rm -fr {} +
	@$(call red, "WIPED: build vagrantfile activate.sh punchbox.pex ansible.pex and pyc/pyo files")

clean-deployer:  ## Remove the installed deployer
	@$(call red, "CLEANING OLD DEPLOYER ARCHIVES", "${DIR}/punch/build/punch-deployer-*")
	@rm -rf ${DIR}/punch/build/punch-deployer-*
	@$(call red, "Will not be removed: do it manually", "${DIR}/.deployer and ${DIR}/.deployed_configuration")

clean-punch-config:  ## Remove Punchplatform Configurations 
	@$(call red, "CLEANING PUNCH CONFIGURATIONS", "${DIR}/punch/build/pp-conf/*")
	@rm -rf ${DIR}/punch/build/pp-conf/

clean-vagrant:  ## Remove vagrant boxes and generated Vagrantfile
	@$(call red, "WIPPING VAGRANT VM", "cd ${DIR}/vagrant \&\& ${VAGRANT} destroy -f")
	@eval ${CLEANUP_COMMAND}
	@rm -rf ${DIR}/vagrant/Vagrantfile

clean-validation-scheduler:  ## Remove installed validation scheduler for current user
	@$(call red, "Cleaning old systemd generated files", "${VALIDATION_SERVICE_SCRIPT} and ${VALIDATION_TIMER_SCRIPT}")
	@systemctl --user disable --now ${VALIDATION_TIMER_NAME}
	@systemctl --user disable --now ${VALIDATION_SERVICE_NAME}
	@rm -rf ${VALIDATION_SERVICE_SCRIPT} ${VALIDATION_TIMER_SCRIPT}
	@systemctl --user daemon-reload

##@ Helpers

.PHONY: help

help:  ## Display help menu
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
