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

ifeq (, $(shell which python3))
 $(error "No python3 installed, it is required. Make sure you also install python3 venv")
endif

help:
	@$(call cyan,"PunchBox Commands", ":")
	@$(call green, "install", "- build punchbox prerequisites")
	@$(call green, "vagrant-dependencies", "- install necessary dependencies for vagrant")
	@$(call green, "configure-deployer", "- configure the punchbox to address directly the installed deployer. Mandatory to deploy")
	@$(call green, "punchbox-ubuntu-32G", "- generate all configurations for a punch deployment on ubuntu targets - 32GB")
	@$(call green, "punchbox-ubuntu-32G-validation", "- generate all configurations for a punch validation deployment on ubuntu targets - 32GB")
	@$(call green, "punchbox-ubuntu-16G", "- generate all configurations for a punch deployment on ubuntu targets - 16GB")
	@$(call green, "punchbox-centos-32G", "- generate all configurations for a punch deployment on centos targets - 32GB")
	@$(call green, "punchbox-centos-32G-validation", "- generate all configurations for a punch validation deployment on centos targets - 32GB")
	@$(call green, "punchbox-centos-16G", "- generate all configurations for a punch deployment on centos targets - 16GB")
	@$(call green, "start-vagrant", "- start vagrant boxes with a Vagrantfile generated previously")
	@$(call green, "deploy-punch", "- deploy punchplatform to targets")
	@$(call green, "deploy-conf", "- deploy punchplatform configurations to operator nodes")
	@$(call green, "clean", "- remove all installed binaries vagrant boxes virtualenv etc")
	@$(call green, "clean-vagrant", "- destroy vagrant machines and remove Vagrantfile")
	@$(call green, "clean-deployer", "- remove the installed deployer")
	@$(call green, "clean-punch-config", "- remove punchplatform configurations")
	@$(call green, "local-integration-vagrant", "- launch an integration test on an already deployed platform")
	@$(call green, "clean-validation-scheduler", "- clean systemd service and timer generated configuration")
	@$(call green, "validation-scheduler-ubuntu-32G", "- hour=4 \: setup an automatic cron for integration test each day at 4 am")
	@$(call green, "validation-scheduler-centos-32G", "- hour=2 \: setup an automatic cron for integration test each day at 2 am")
	@$(call green, "update-deployer-configuration", "- reapply templating if modifications has been done to punch configurations")

.venv/.installed:
	@$(call blue, "************  CREATE PYTHON 3 .venv  VIRTUALENV  ************")
	@if [ ! -e "${DIR}/.venv/bin/activate" ] ; then python3 -m venv ${DIR}/.venv ; fi
	@. ${DIR}/.venv/bin/activate && pip install -U pip wheel setuptools -q
	@$(call blue, "Python 3 virtualenv installed:", "${DIR}/.venv")
	@touch $@

clean: clean-vagrant clean-deployer
	@$(call blue, "************  CLEAN  ************")
	@rm -rf ${DIR}/.venv
	@rm -rf ${DIR}/punch/build
	@rm -rf ${DIR}/activate.sh
	@rm -rf ${DIR}/bin/pex/punchbox_pex/punchbox.pex
	@rm -rf ${DIR}/bin/pex/ansible_pex/ansible.pex
	@rm -rf ${DIR}/ansible/punchbox.*
	@-find ${DIR} -name '*.pyc' -exec rm -f {} +
	@-find ${DIR} -name '*.pyo' -exec rm -f {} +
	@-find ${DIR} -name '*~' -exec rm -f {} +
	@-find ${DIR} -name '__pycache__' -exec rm -fr {} +
	@$(call red, "WIPED: build vagrantfile activate.sh punchbox.pex ansible.pex and pyc/pyo files")

${ACTIVATE_SH}:${ACTIVATE_TEMPLATE} Makefile
	@echo "  GENERATING '${ACTIVATE_SH}'..."
	@sed 's#.*PUNCHBOX_DIR=.*#export PUNCHBOX_DIR='${DIR}'#g' "${ACTIVATE_TEMPLATE}" > "${ACTIVATE_SH}"

${DIR}/bin/pex/.all_pex_generated: .venv/.installed ${ACTIVATE_SH} ${PUNCHBOX_PEX_REQUIREMENTS} ${ANSIBLE_PEX_REQUIREMENTS} requirements.txt bin/punchbox.py
	@$(call green, "Installing PunchBox python dependencies virtualenv...")
	@. ${DIR}/.venv/bin/activate && pip install -r requirements.txt -q
	@$(call green, "************ BUILDING PEX PACKAGES for punchbox and Ansible ************")
	@. ${DIR}/.venv/bin/activate && pex -r ${PUNCHBOX_PEX_REQUIREMENTS} --disable-cache -o ${PUNCHBOX_PEX}
	@. ${DIR}/.venv/bin/activate && pex -r ${ANSIBLE_PEX_REQUIREMENTS} --disable-cache -o ${ANSIBLE_PEX}
	@touch $@

${DIR}/vagrant/.dependencies_installed:
	@$(call green, "************ ADDING VAGRANT DEPENDENCIES ************")
	@cd ${DIR}/vagrant && ${VAGRANT} plugin install vagrant-disksize
	@cd ${DIR}/vagrant && ${VAGRANT} plugin install vagrant-vbguest
	touch $@

install: .venv/.installed ${DIR}/bin/pex/.all_pex_generated
	@$(call blue, "************  INSTALL STATUS ************")
	@[ -e "${HOME}/.ssh/id_rsa.pub" ] || { echo ".ssh/id_rsa.pub not found in user home directory. Maybe try running 'ssh-keygen' without specific option." 2>&1 && exit 42 ; }
	@which jq 1>/dev/null || { echo "jq command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which curl 1>/dev/null || { echo "curl command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which unzip 1>/dev/null || { echo "unzip command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which python 1>/dev/null || { echo "python (>3.6.8) must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@$(call green, "PunchBox pex:", "${PUNCHBOX_PEX}")
	@$(call green, "Ansible pex:", "${ANSIBLE_PEX}")
	@$(call green, "activate.sh:", "${ACTIVATE_SH}")
	@$(call green, "installation complete", "you should be able to use other commands !")


configure-deployer:
	@$(call green, "Deployer zip path in .deployer change it\'s content to match yours:", "${DIR}/.deployer")
	@echo ${DEFAULT_DEPLOYER_ZIP_PATH} > ${DIR}/.deployer

clean-deployer:
	@$(call red, "CLEANING OLD DEPLOYER ARCHIVES", "${DIR}/punch/build/punch-deployer-*")
	@rm -rf ${DIR}/punch/build/punch-deployer-*

clean-punch-config:
	@$(call red, "CLEANING PUNCH CONFIGURATIONS", "${DIR}/punch/build/pp-conf/*")
	@rm -rf ${DIR}/punch/build/pp-conf/

clean-vagrant:
	@$(call red, "WIPPING VAGRANT VM", "cd ${DIR}/vagrant \&\& ${VAGRANT} destroy -f")
	@eval ${CLEANUP_COMMAND}
	@rm -rf ${DIR}/vagrant/Vagrantfile

deployed-configuration-32G: install
	@echo ${DIR}/configurations/complete_punch_32G.json > ${DIR}/.deployed_configuration

deployed-configuration-16G: install
	@echo ${DIR}/configurations/complete_punch_16G.json > ${DIR}/.deployed_configuration

punchbox-ubuntu-32G: deployed-configuration-32G
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --deployer $(shell cat ${DIR}/.deployer)

punchbox-ubuntu-32G-validation: deployed-configuration-32G
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --deployer $(shell cat ${DIR}/.deployer) \
				 --validation

punchbox-ubuntu-16G: deployed-configuration-16G
	@$(call green, "Deploying 16G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_16G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --deployer $(shell cat ${DIR}/.deployer)

punchbox-centos-32G: deployed-configuration-32G
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --os centos/7 \
				 --interface eth1 \
				 --deployer $(shell cat ${DIR}/.deployer)
				
punchbox-centos-32G-validation: deployed-configuration-32G
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --os centos/7 \
				 --interface eth1 \
				 --deployer $(shell cat ${DIR}/.deployer) \
				 --validation

punchbox-centos-16G: deployed-configuration-16G
	@$(call green, "Deploying 16G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_16G.json \
				 --generate-vagrantfile \
				 --punch-user-config ${DIR}/punch/configurations/validation \
				 --os centos/7 \
				 --interface eth1 \
				 --deployer $(shell cat ${DIR}/.deployer) \

update-deployer-configuration:
	@. ${ACTIVATE_SH} && punchbox --platform-config-file $(shell cat ${DIR}/.deployed_configuration) \
								--punch-user-config ${DIR}/punch/configurations/validation

start-vagrant: install ${DIR}/vagrant/.dependencies_installed
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --start-vagrant

deploy-punch:
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --generate-platform-config \
								  --templates-dir ${DIR}/punch/deployment_template/ \
								  --model ${DIR}/punch/build/model.json
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -gi
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --deploy -u vagrant

deploy-config:
	@. ${ACTIVATE_SH} && punchplatform-deployer.sh -cp -u vagrant

local-integration-vagrant:
	@$(call green, "Copying Needed files to server1 for local integration test", "/home/vagrant/pp-conf")
	@. ${ACTIVATE_SH} && punchplatform-deployer.sh -cp -u vagrant
	@$(call green, "Check if vagrant boxes are up", "")
	@cd ${DIR}/vagrant && ${VAGRANT} up
	@$(call green, "Executing on server1", "/home/vagrant/pp-conf/check_platform.sh")
	@cd ${DIR}/vagrant && ${VAGRANT} ssh server1 -c "/home/vagrant/pp-conf/check_platform.sh; exit"

clean-validation-scheduler:
	@$(call red, "Cleaning old systemd generated files", "${VALIDATION_SERVICE_SCRIPT} and ${VALIDATION_TIMER_SCRIPT}")
	@systemctl --user disable --now ${VALIDATION_TIMER_NAME}
	@systemctl --user disable --now ${VALIDATION_SERVICE_NAME}
	@rm -rf ${VALIDATION_SERVICE_SCRIPT} ${VALIDATION_TIMER_SCRIPT}
	@systemctl --user daemon-reload

validation-scheduler-ubuntu-32G:
	@[ "${hour}" ] || ( $(call red, "hour not set", "example hour=4"); exit 1 )
	@$(call green, "Generating systemd Scheduling script", "${PUNCHBOX_SCRIPT_DIR}")
	@mkdir -p ${PUNCHBOX_SCRIPT_DIR}
	@echo "[Unit]" > ${VALIDATION_SERVICE_SCRIPT}
	@echo "Description=run a local integration platform once each day at $(hour) oclock for Ubuntu 32G OS" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "[Service]" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo Environment="LIVEDEMO_API_URL=${LIVEDEMO_API_URL} PUNCH_DIR=$(shell realpath ${DIR}/../pp-punch)" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "Type=oneshot" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "WorkingDirectory=${DIR}" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo ExecStart="${BASH} -c 'PATH=${PATH}; ${MAKE} install; ${MAKE} configure-deployer; ${MAKE} punchbox-ubuntu-32G-validation; ${MAKE} start-vagrant; ${MAKE} deploy-punch; ${MAKE} local-integration-vagrant; ${MAKE} clean'" >> ${VALIDATION_SERVICE_SCRIPT}
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

validation-scheduler-centos-32G:
	@[ "${hour}" ] || ( $(call red, "hour not set", "example hour=4"); exit 1 )
	@$(call green, "Generating systemd Scheduling script", "${PUNCHBOX_SCRIPT_DIR}")
	@mkdir -p ${PUNCHBOX_SCRIPT_DIR}
	@echo "[Unit]" > ${VALIDATION_SERVICE_SCRIPT}
	@echo "Description=run a local integration platform once each day at $(hour) oclock for CentOS 32G OS" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "[Service]" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo Environment="LIVEDEMO_API_URL=${LIVEDEMO_API_URL} PUNCH_DIR=$(shell realpath ${DIR}/../pp-punch)" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "Type=oneshot" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "WorkingDirectory=${DIR}" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo ExecStart="${BASH} -c 'PATH=${PATH}; ${MAKE} install; ${MAKE} configure-deployer; ${MAKE} punchbox-centos-32G-validation; ${MAKE} start-vagrant; ${MAKE} deploy-punch; ${MAKE} local-integration-vagrant; ${MAKE} clean'" >> ${VALIDATION_SERVICE_SCRIPT}
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
