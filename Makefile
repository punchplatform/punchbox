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

# PUNCHBOX DIRS
PUNCHBOX_CONF_DIR=${DIR}/configurations
PUNCHBOX_LOG_MANAGEMENT_RESOURCES_DIR=$${PUNCHBOX_BUILD_DIR}/${PUNCH_EXAMPLES_NAME}/conf/platforms/log_management_platform/resources
PUNCHBOX_LOG_MANAGEMENT_TENANTS_DIR=$${PUNCHBOX_BUILD_DIR}/${PUNCH_EXAMPLES_NAME}/conf/platforms/log_management_platform/tenants

# PUNCHBOX ENVIRONMENT
ACTIVATE_SH=${DIR}/activate.sh
ACTIVATE_TEMPLATE=${DIR}/.activate.template
VENV_INSTALLED_MARKERFILE=${DIR}/.venv/.installed
DEPLOYER_INSTALLED_MARKERFILE=${DIR}/.deployer_installed
ENV_INSTALLED_MARKERFILE=${DIR}/.env_installed

# PUNCHBOX CONFIGURATIONS
DEFAULT_TLS_CONFIG_DIR=${PUNCHBOX_CONF_DIR}/default_tls

# PUNCH SOURCES
DEFAULT_DEPLOYER_ZIP_PATH=$${PUNCH_DIR}/packagings/punch-deployer/target/${PUNCH_DEPLOYER_NAME}.zip
DEFAULT_EXAMPLES_PATH=$${PUNCH_DIR}/examples/target/${PUNCH_EXAMPLES_NAME}.zip





# PUNCHBOX VALIDATION
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

ifeq (, $(shell which python3))
 $(error "No python3 installed, it is required. Make sure you also install python3 venv")
endif

##@ Welcome to PunchBox CLI
##@ With this Makefile, you will be able to setup a running PunchPlatform in no time
##@ Sequences of commands to be made are defined by steps, just follow them and let the magic happen !

##@ ***************************************************************************************************

##@ Step 1

## Environment

.PHONY: install install-env check-env install-python

${VENV_INSTALLED_MARKERFILE}:
	@$(call green, "Check python3 virtualenv")
	@if [ ! -e "${DIR}/.venv/bin/activate" ] ; then python3 -m venv ${DIR}/.venv ; fi
	@. ${DIR}/.venv/bin/activate && pip install -U pip wheel setuptools -q && pip install -r ${DIR}/requirements.txt --quiet
	@touch $@


${ACTIVATE_SH}: ${ACTIVATE_TEMPLATE} Makefile
	@$(call green, "Check shell environment")
	@sed 's#.*PUNCHBOX_DIR=.*#export PUNCHBOX_DIR='${DIR}'#g' "${ACTIVATE_TEMPLATE}" > "${ACTIVATE_SH}"

${ENV_INSTALLED_MARKERFILE}: ${VENV_INSTALLED_MARKERFILE} ${ACTIVATE_SH}
	@touch $@

${DEPLOYER_INSTALLED_MARKERFILE}: ${ENV_INSTALLED_MARKERFILE}
	@$(call green, "Check deployer")
	@. ${DIR}/activate.sh && unzip -n -qq $${PUNCH_DIR}/packagings/punch-deployer/target/punch-deployer-*.zip -d $${PUNCHBOX_BUILD_DIR}
	@touch $@

install-env: ${ENV_INSTALLED_MARKERFILE}
	@[ -e "${HOME}/.ssh/id_rsa.pub" ] || { echo ".ssh/id_rsa.pub not found in user home directory. Maybe try running 'ssh-keygen' without specific option." 2>&1 && exit 42 ; }
	@which jq 1>/dev/null || { echo "jq command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which curl 1>/dev/null || { echo "curl command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which unzip 1>/dev/null || { echo "unzip command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which python 1>/dev/null || { echo "python (>3.6.8) must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }

install: install-env ${DEPLOYER_INSTALLED_MARKERFILE}
	@. ${DIR}/activate.sh && if [ ! -d "$&{PUNCHPLATFORM_CONF_DIR}" ]; then mkdir -p "$${PUNCHPLATFORM_CONF_DIR}"; fi

check-env: ${ENV_INSTALLED_MARKERFILE}
	@$(call blue, "Python environment")
	@source ${DIR}/.venv/bin/activate && pip freeze
	@$(call blue, "Shell environment")
	@source ${ACTIVATE_SH} && env | grep PUNCH

## Configuration

.PHONY: legacy-tls-config test-config test

default-tls-config: install
	@$(call green, "Install deployment configuration")
	@. ${ACTIVATE_SH} && cp -r "${DEFAULT_TLS_CONFIG_DIR}/resolv.yaml" \
		"${DEFAULT_TLS_CONFIG_DIR}/security" \
		"${DEFAULT_TLS_CONFIG_DIR}/punchplatform-deployment.settings" \
		"$${PUNCHPLATFORM_CONF_DIR}/" && \
		cp "${DEFAULT_TLS_CONFIG_DIR}/Vagrantfile" $${PUNCHBOX_VAGRANT_DIR}
	@$(call green, "Install resources configuration")
	@. ${ACTIVATE_SH} && unzip -n -qq "${DEFAULT_EXAMPLES_PATH}" -d "$${PUNCHBOX_BUILD_DIR}" && \
		cp -r ${PUNCHBOX_LOG_MANAGEMENT_RESOURCES_DIR} "$${PUNCHPLATFORM_CONF_DIR}" && \
		cp -r ${PUNCHBOX_LOG_MANAGEMENT_TENANTS_DIR} "$${PUNCHPLATFORM_CONF_DIR}"

##@ Step 4

.PHONY: start-vagrant

start-vagrant: ${ENV_INSTALLED_MARKERFILE}  ## Start vagrant boxes
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && cd $${PUNCHBOX_VAGRANT_DIR} && vagrant up

##@ Step 5

.PHONY: deploy

default-tls-deploy: default-tls-config start-vagrant
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && punchplatform-deployer.sh deploy -u vagrant -e @$${PUNCHPLATFORM_CONF_DIR}/security/deployment_secrets.json

deploy: ${ENV_INSTALLED_MARKERFILE}
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && punchplatform-deployer.sh deploy -u vagrant

##@ Step 6

.PHONY: deploy-config local-integration-vagrant update-deployer-configuration

deploy-config:  ${ENV_INSTALLED_MARKERFILE}
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -cp -u vagrant
 
update-deployer-configuration: ${ENV_INSTALLED_MARKERFILE}
	@. ${ACTIVATE_SH} && punchbox --platform-config-file $(shell cat ${DIR}/.deployed_configuration) \
								--punch-user-config ${DIR}/punch/configurations/validation

##@ All in one

.PHONY: default-tls

default-tls: default-tls-deploy

##@ Cleanup

.PHONY: clean-config clean-deployer clean-env clean

clean: ${ENV_INSTALLED_MARKERFILE}
	@$(call red, "Clean configuration")
	@source ${ACTIVATE_SH} && rm -rf $${PUNCHPLATFORM_CONF_DIR}

clean-deployer:
	@$(call red, "Clean deployer and examples")
	@source ${ACTIVATE_SH} && rm -rf $${PUNCHBOX_BUILD_DIR}/${PUNCH_DEPLOYER_NAME} && rm -rf $${PUNCHBOX_BUILD_DIR}/${PUNCH_EXAMPLES_NAME}

clean-vagrant: ${ENV_INSTALLED_MARKERFILE}
	@$(call red, "Destroy vagrant machines")
	@source ${DIR}/.venv/bin/activate && source ${ACTIVATE_SH} && cd $${PUNCHBOX_VAGRANT_DIR} && ${VAGRANT} destroy -f

clean-env:
	@$(call red, "Clean environment and dependencies")
	@rm -rf ${DIR}/.venv
	@rm -rf ${DIR}/activate.sh

clean-all: clean-config clean-deployer clean-env

##@ Helpers

.PHONY: help

help:  ## Display help menu
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
