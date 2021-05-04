.DEFAULT_GOAL:=help
SHELL:=/bin/bash

# Static vars
# shells
DIR=$(shell pwd)
MAKE=$(shell which make)
BASH=$(shell which bash)
SH=$(shell which sh)
VAGRANT=$(shell which vagrant)

# PUNCH NAMES
PUNCH_DEPLOYER_NAME=punch-deployer-*
PUNCH_EXAMPLES_NAME=punch-examples-*

# PUNCH SOURCES
DEFAULT_DEPLOYER_ZIP_PATH=${DIR}/../pp-punch/packagings/punch-deployer/target/${PUNCH_DEPLOYER_NAME}.zip
DEFAULT_PUNCH_EXAMPLES_PATH=${DIR}/../pp-punch/examples/target/${PUNCH_EXAMPLES_NAME}.zip

# PUNCHBOX DIR
PUNCHBOX_BUILD_DIR=${DIR}/punch/build
PUNCHBOX_CONF_DIR=${PUNCHBOX_BUILD_DIR}/pp-conf

PUNCHBOX_LOG_MANAGEMENT_RESOURCES_DIR=${PUNCHBOX_BUILD_DIR}/${PUNCH_EXAMPLES_NAME}/conf/platforms/log_management_platform/resources
PUNCHBOX_LOG_MANAGEMENT_TENANTS_DIR=${PUNCHBOX_BUILD_DIR}/${PUNCH_EXAMPLES_NAME}/conf/platforms/log_management_platform/tenants

# VAGRANT
PUNCHBOX_VAGRANT_DIR=${DIR}/vagrant

# env files
ACTIVATE_SH=${DIR}/activate.sh
ACTIVATE_TEMPLATE=${DIR}/.activate.template

# confs
CONF_LEGACY_DIR=${DIR}/configurations/legacy
CONF_LEGACY_TLS_DIR=${CONF_LEGACY_DIR}/tls_24G

PUNCHBOX_SCRIPT_DIR=$(shell realpath ~/.config)/systemd/user
VALIDATION=""
VALIDATION_SERVICE_NAME=punch-validation.service
VALIDATION_TIMER_NAME=punch-validation.timer
VALIDATION_SERVICE_SCRIPT=${PUNCHBOX_SCRIPT_DIR}/${VALIDATION_SERVICE_NAME}
VALIDATION_TIMER_SCRIPT=${PUNCHBOX_SCRIPT_DIR}/${VALIDATION_TIMER_NAME}

VENV_MARKERFILE=${DIR}/.venv/.installed
DEPENDENCIES_INSTALLED_MARKERFILE=${DIR}/vagrant/.dependencies_installed
ALLTOOLS_INSTALLED_MARKERFILE=${DIR}/.alltools_installed

# Color Functions
ECHO=$(shell which echo)
cyan=${ECHO} -e "\x1b[36m $1\x1b[0m$2"
blue=${ECHO} -e "\x1b[34m $1\x1b[0m$2"
green=${ECHO} -e "\x1b[32m $1\x1b[0m$2"
red=${ECHO} -e "\x1b[31m $1\x1b[0m$2"

ifeq (, $(shell which python3))
 $(error "No python3 installed, it is required. Make sure you also install python3 venv")
endif

${VENV_MARKERFILE}:
	@$(call green, "create python3 virtualenv")
	@if [ ! -e "${DIR}/.venv/bin/activate" ] ; then python3 -m venv ${DIR}/.venv ; fi
	. ${DIR}/.venv/bin/activate
	pip install -U pip wheel setuptools -q \
	pip install -r ${DIR}/requirements.txt
	@touch $@

${ACTIVATE_SH}: ${ACTIVATE_TEMPLATE} Makefile
	@$(call green, "create shell environment")
	@sed 's#.*PUNCHBOX_DIR=.*#export PUNCHBOX_DIR='${DIR}'#g' "${ACTIVATE_TEMPLATE}" > "${ACTIVATE_SH}"

${ALLTOOLS_INSTALLED_MARKERFILE}: ${VENV_MARKERFILE} ${ACTIVATE_SH}
	@touch $@

##@ Welcome to PunchBox CLI
##@ With this Makefile, you will be able to setup a running PunchPlatform in no time
##@ Sequences of commands to be made are defined by steps, just follow them and let the magic happen !

##@ ***************************************************************************************************

##@ Step 1

##@ Install a deployment environment with :
##@ - A targeted OS
##@ - A Punch configuration

## Environment

.PHONY: install-env install-deployer install check-env

install-env: ${ALLTOOLS_INSTALLED_MARKERFILE} ## Build Punchbox Prerequisites
	@[ -e "${HOME}/.ssh/id_rsa.pub" ] || { echo ".ssh/id_rsa.pub not found in user home directory. Maybe try running 'ssh-keygen' without specific option." 2>&1 && exit 42 ; }
	@which jq 1>/dev/null || { echo "jq command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which curl 1>/dev/null || { echo "curl command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which unzip 1>/dev/null || { echo "unzip command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which python 1>/dev/null || { echo "python (>3.6.8) must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@$(call green, "activate.sh:", "${ACTIVATE_SH}")

install-deployer: ## install the deployer from the zip file located in projet $PUNCH_DIR
	@$(call green, "Install deployer:", "${PUNCHBOX_BUILD_DIR}")
	@if [ ! -d "${PUNCHBOX_BUILD_DIR}" ]; then mkdir -p "${PUNCHBOX_BUILD_DIR}"; fi
	@unzip -n -qq "${DEFAULT_DEPLOYER_ZIP_PATH}" -d "${PUNCHBOX_BUILD_DIR}"

install: install-env install-deployer

check-env: ${ALLTOOLS_INSTALLED_MARKERFILE}
	@source ${DIR}/.venv/bin/activate
	@source ${ACTIVATE_SH}
	@env | grep PUNCH
	@pip freeze

## Configuration

.PHONY: legacy-tls-conf

configure-centos:

legacy-tls-ubuntu: install
	@$(call green, "Install Vagrantfile")
	@if [ ! -d "${PUNCHBOX_VAGRANT_DIR}" ]; then mkdir -p "${PUNCHBOX_VAGRANT_DIR}"; fi
	cp "${CONF_LEGACY_TLS_DIR}/Vagrantfile" "${PUNCHBOX_VAGRANT_DIR}"
	@$(call green, "Install deployment configuration")
	@if [ ! -d "${PUNCHBOX_CONF_DIR}" ]; then mkdir -p "${PUNCHBOX_CONF_DIR}"; fi
	cp -r "${CONF_LEGACY_TLS_DIR}/resolv.yaml" \
		"${CONF_LEGACY_TLS_DIR}/punchplatform-deployment.settings" \
		"${CONF_LEGACY_TLS_DIR}/security" \
		"${PUNCHBOX_CONF_DIR}"
	@$(call green, "Install platform configuration")
	@unzip -n -qq "${DEFAULT_PUNCH_EXAMPLES_PATH}" -d "${PUNCHBOX_BUILD_DIR}"
	cp -r ${PUNCHBOX_LOG_MANAGEMENT_RESOURCES_DIR} "${PUNCHBOX_CONF_DIR}"
	cp -r ${PUNCHBOX_LOG_MANAGEMENT_TENANTS_DIR} "${PUNCHBOX_CONF_DIR}"

##@ Step 4

.PHONY: start-vagrant

start-vagrant: ${ALLTOOLS_INSTALLED_MARKERFILE}  ## Start vagrant boxes
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
	cd ${PUNCHBOX_VAGRANT_DIR} && vagrant up


##@ Step 5

.PHONY: deploy-punch legacy-tls-deploy

deploy-punch:  ${ALLTOOLS_INSTALLED_MARKERFILE}  ## Deploy PunchPlatform to targets
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --generate-platform-config \
								  --templates-dir ${DIR}/punch/deployment_template/ \
								  --model ${DIR}/punch/build/model.json
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -gi
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --deploy -u vagrant


legacy-tls-deploy: ${ALLTOOLS_INSTALLED_MARKERFILE}
	source ${DIR}/.venv/bin/activate
	source ${ACTIVATE_SH}
	punchplatform-deployer.sh -gi



deploy-punch-security:  ${ALLTOOLS_INSTALLED_MARKERFILE}  ## Deploy PunchPlatform to targets
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --generate-platform-config \
								  --templates-dir ${DIR}/punch/deployment_template/ \
								  --model ${DIR}/punch/build/model.json
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -gi
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh --deploy -u vagrant -e @${DIR}/punch/build/pp-conf/deployment_secrets.json

##@ Step 6

.PHONY: deploy-config local-integration-vagrant update-deployer-configuration

deploy-config:  ${ALLTOOLS_INSTALLED_MARKERFILE}  ## Deploys PunchPlatform configuration files to targets
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -cp -u vagrant

local-integration-vagrant:  ## Use this rule instead of deploy-config if you are planning to do validation
	@$(call green, "Copying Needed files to server1 for local integration test", "/home/vagrant/pp-conf")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && punchplatform-deployer.sh -cp -u vagrant
	@$(call green, "Check if vagrant boxes are up", "")
	@cd ${DIR}/vagrant && ${VAGRANT} up
	@$(call green, "Executing on server1", "/home/vagrant/pp-conf/check_platform.sh")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		cd ${DIR}/vagrant && \
		${VAGRANT} ssh server1 -c "/home/vagrant/pp-conf/check_platform.sh -f; exit"
 
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

##@ All in one

.PHONY: legacy-tls

legacy-tls:	legacy-tls-configure make-start-vagrant-2 legacy-tls-deploy deploy-config

##@ Cleanup

.PHONY: clean-conf clean-deployer clean clean-vagrant clean-all

clean-conf:  ## Remove Punchplatform Configurations
	@$(call red, "Clean configuration: ", "remove ${DIR}/punch/build/pp-conf/*")
	@rm -rf ${DIR}/punch/build/pp-conf/

clean-deployer:  ## Remove the installed deployer
	@$(call red, "Clean deployer: ", "remove ${DIR}/punch/build/punch-deployer-*")
	@rm -rf ${DIR}/punch/build/punch-deployer-*

clean: ## Cleanup all built deployers, confs, exampples and environment
	@$(call red, "Clean deployer and configurations: ", "remove ${DIR}/punch/build/*")
	rm -rf ${DIR}/punch/build
	rm -rf ${DIR}/.venv
	@$(call red, "Clean python and shell environment")
	rm -rf ${DIR}/activate.sh

clean-vagrant: ${ALLTOOLS_INSTALLED_MARKERFILE}
	@$(call red, "Destroy vagrant machines", "cd ${DIR}/vagrant \&\& ${VAGRANT} destroy -f")
	@source ${DIR}/.venv/bin/activate
	source . ${ACTIVATE_SH}
	cd ${PUNCHBOX_VAGRANT_DIR} && ${VAGRANT} destroy -f

clean-all: clean-vagrant clean

##@ Helpers

.PHONY: help

help:  ## Display help menu
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
