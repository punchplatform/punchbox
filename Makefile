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
DEFAULT_DEPLOYER_ZIP_PATH=${DIR}/../pp-punch/packagings/punch-deployer/target/punch-deployer-*.zip
PUNCHBOX_SCRIPT_DIR=$(shell realpath ~/.config)/systemd/user
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
	@$(call green, "install", "- rebuild everything from scratch")
	@$(call green, "vagrant-dependencies", "- install necessary dependencies for vagrant")
	@$(call green, "configure-punchbox-vagrant", "- configure the punchbox to address directly the installed deployer. Mandatory to deploy")
	@$(call green, "punchbox-ubuntu-32G", "- deploy on vagrant box a 32G punchplatform for ubuntu")
	@$(call green, "punchbox-ubuntu-16G", "- deploy on vagrant box a 16G punchplatform for ubuntu")
	@$(call green, "punchbox-centos-32G", "- deploy on vagrant box a 32G punchplatform for centos")
	@$(call green, "punchbox-centos-16G", "- deploy on vagrant box a 16G punchplatform for centos")
	@$(call green, "clean", "- remove all installed binaries vagrant boxes virtualenv etc")
	@$(call green, "clean-vagrant", "- destroy vagrant machines and remove Vagrantfile")
	@$(call green, "clean-deployer", "- remove the installed deployer")
	@$(call green, "local-integration-vagrant", "- launch an integration test on an already deployed platform")
	@$(call green, "clean-validation-scheduler", "- clean systemd service and timer generated configuration")
	@$(call green, "validation-scheduler-ubuntu-32G", "- hour=4 \: setup an automatic cron for integration test each day at 4 am")
	@$(call green, "validation-scheduler-centos-32G", "- hour=2 \: setup an automatic cron for integration test each day at 2 am")

.venv:
	@$(call blue, "************  CREATE PYTHON 3 .venv  VIRTUALENV  ************")
	@if [ ! -e "${DIR}/.venv/bin/activate" ] ; then python3 -m venv ${DIR}/.venv ; fi
	@. ${DIR}/.venv/bin/activate && pip install -U pip wheel setuptools -q
	@$(call blue, "Python 3 virtualenv installed:", "${DIR}/.venv")

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

install: clean .venv
	@$(call blue, "************  INSTALL  ************")
	@. ${DIR}/.venv/bin/activate && pip install -r requirements.txt -q
	@$(call green, "PunchBox python dependencies installed in virtualenv")
	@. ${DIR}/.venv/bin/activate && pex -r ${PUNCHBOX_PEX_REQUIREMENTS} --disable-cache -o ${PUNCHBOX_PEX}
	@$(call green, "PunchBox pex:", "${PUNCHBOX_PEX}")
	@. ${DIR}/.venv/bin/activate && pex -r ${ANSIBLE_PEX_REQUIREMENTS} --disable-cache -o ${ANSIBLE_PEX}
	@$(call green, "Ansible pex:", "${ANSIBLE_PEX}")
	@echo export PUNCHBOX_DIR=${DIR} > ${ACTIVATE_SH}
	@echo export PUNCHPLATFORM_CONF_DIR=${DIR}/punch/build/pp-conf >> ${ACTIVATE_SH}
	@echo export PATH='$$PATH':${DIR}/bin >> ${ACTIVATE_SH}
	@echo export PS1="'\[\e[1;32m\]punchbox:\[\e[0m\][\W]\$ '" >> ${ACTIVATE_SH}
	@echo export PATH='$$PATH':${DIR}/bin/pex/ansible_pex >> ${ACTIVATE_SH}
	@$(call green, "activate.sh:", "${ACTIVATE_SH}")
	@$(call green, "installation complete", "you should be able to use other commands !")

vagrant-dependencies:
	@$(call green, "************ ADDING VAGRANT DEPENDENCIES ************")
	@cd ${DIR}/vagrant && ${VAGRANT} plugin install vagrant-disksize
	@cd ${DIR}/vagrant && ${VAGRANT} plugin install vagrant-vbguest

configure-punchbox-vagrant:
	@$(call green, "Deployer zip path in .deployer change it\'s content to match yours:", "${DIR}/.deployer")
	@echo ${DEFAULT_DEPLOYER_ZIP_PATH} > ${DIR}/.deployer

clean-deployer:
	@$(call red, "CLEANING OLD DEPLOYER ARCHIVES", "${DIR}/punch/build/punch-deployer-*")
	@rm -rf ${DIR}/punch/build/punch-deployer-*

clean-vagrant:
	@$(call red, "WIPPING VAGRANT VM", "cd ${DIR}/vagrant \&\& ${VAGRANT} destroy -f")
	@eval ${CLEANUP_COMMAND}
	@rm -rf ${DIR}/vagrant/Vagrantfile

punchbox-ubuntu-32G: clean-deployer vagrant-dependencies
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-validation-config ${DIR}/punch/configurations/validation \
				 --deployer $(shell cat ${DIR}/.deployer) \
				 --start-vagrant
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --generate-platform-config \
								  --templates-dir ${DIR}/punch/platform_template/ \
								  --model ${DIR}/punch/build/model.json
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -gi
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --deploy -u vagrant

punchbox-ubuntu-16G: clean-deployer vagrant-dependencies
	@$(call green, "Deploying 16G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_16G.json \
				 --generate-vagrantfile \
				 --punch-validation-config ${DIR}/punch/configurations/validation \
				 --deployer $(shell cat ${DIR}/.deployer) \
				 --start-vagrant
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --generate-platform-config \
								  --templates-dir ${DIR}/punch/platform_template/ \
								  --model ${DIR}/punch/build/model.json
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -gi
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --deploy -u vagrant

punchbox-centos-32G: clean-deployer vagrant-dependencies
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-validation-config ${DIR}/punch/configurations/validation \
				 --os centos/7 \
				 --interface eth1 \
				 --deployer $(shell cat ${DIR}/.deployer) \
				 --start-vagrant
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --generate-platform-config \
								  --templates-dir ${DIR}/punch/platform_template/ \
								  --model ${DIR}/punch/build/model.json
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -gi
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --deploy -u vagrant

punchbox-centos-16G: clean-deployer vagrant-dependencies
	@$(call green, "Deploying 16G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_16G.json \
				 --generate-vagrantfile \
				 --punch-validation-config ${DIR}/punch/configurations/validation \
				 --os centos/7 \
				 --interface eth1 \
				 --deployer $(shell cat ${DIR}/.deployer) \
				 --start-vagrant
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --generate-platform-config \
								  --templates-dir ${DIR}/punch/platform_template/ \
								  --model ${DIR}/punch/build/model.json
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -gi
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --deploy -u vagrant

local-integration-vagrant:
	@$(call green, "Copying Needed files to server1 for local integration test", "/home/vagrant/pp-conf")
	@. ${ACTIVATE_SH} && punchplatform-deployer.sh -cp -u vagrant
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
	@$(call green, "Generating systemd Scheduling script", "~/.punch-script/")
	@mkdir -p ${PUNCHBOX_SCRIPT_DIR}
	@echo "[Unit]" > ${VALIDATION_SERVICE_SCRIPT}
	@echo "Description=run a local integration platform once each day at $(hour) oclock for Ubuntu 32G OS" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "[Service]" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "Type=oneshot" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "WorkingDirectory=${DIR}" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo ExecStart="${BASH} -c 'PATH=${PATH}; ${MAKE} install; ${MAKE} make configure-punchbox-vagrant; ${MAKE} punchbox-ubuntu-32G; ${MAKE} local-integration; ${MAKE} clean'" >> ${VALIDATION_SERVICE_SCRIPT}
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
	@$(call green, "Generating systemd Scheduling script", "~/.punch-script/")
	@mkdir -p ${PUNCHBOX_SCRIPT_DIR}
	@echo "[Unit]" > ${VALIDATION_SERVICE_SCRIPT}
	@echo "Description=run a local integration platform once each day at $(hour) oclock for CentOS 32G OS" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "[Service]" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "Type=oneshot" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo "WorkingDirectory=${DIR}" >> ${VALIDATION_SERVICE_SCRIPT}
	@echo ExecStart="${BASH} -c 'PATH=${PATH}; ${MAKE} install; ${MAKE} make configure-punchbox-vagrant; ${MAKE} punchbox-centos-32G; ${MAKE} local-integration; ${MAKE} clean'" >> ${VALIDATION_SERVICE_SCRIPT}
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
