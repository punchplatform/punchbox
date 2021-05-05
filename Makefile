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
PUNCHBOX_DEPLOYER_DIR=${DIR}/punch/deployers
PUNCHBOX_CONF_DIR=${DIR}/configurations
PUNCHBOX_LOG_MANAGEMENT_RESOURCES_DIR=${PUNCHBOX_BUILD_DIR}/${PUNCH_EXAMPLES_NAME}/conf/platforms/log_management_platform/resources
PUNCHBOX_LOG_MANAGEMENT_TENANTS_DIR=${PUNCHBOX_BUILD_DIR}/${PUNCH_EXAMPLES_NAME}/conf/platforms/log_management_platform/tenants

# PUNCHBOX ENVIRONMENT
ACTIVATE_SH=${DIR}/activate.sh
ACTIVATE_TEMPLATE=${DIR}/.activate.template
VENV_MARKERFILE=${DIR}/.venv/.installed
ALLTOOLS_INSTALLED_MARKERFILE=${DIR}/.alltools_installed

# PUNCHBOX CONFIGURATIONS
LEGACY_TLS_CONFIG_DIR=${PUNCHBOX_CONF_DIR}/legacy/tls_24G

# PUNCH SOURCES
DEFAULT_DEPLOYER_ZIP_PATH=${DIR}/../pp-punch/packagings/punch-deployer/target/${PUNCH_DEPLOYER_NAME}.zip
DEFAULT_PUNCH_EXAMPLES_PATH=${DIR}/../pp-punch/examples/target/${PUNCH_EXAMPLES_NAME}.zip





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

.PHONY: install-env install-deployer install check-env test

${VENV_MARKERFILE}:
	@$(call green, "Install python3 virtualenv")
	@if [ ! -e "${DIR}/.venv/bin/activate" ] ; then python3 -m venv ${DIR}/.venv ; fi
	@. ${DIR}/.venv/bin/activate && pip install -U pip wheel setuptools -q && pip install -r ${DIR}/requirements.txt --quiet
	@touch $@

${ACTIVATE_SH}: ${ACTIVATE_TEMPLATE} Makefile
	@$(call green, "Install shell environment")
	@sed 's#.*PUNCHBOX_DIR=.*#export PUNCHBOX_DIR='${DIR}'#g' "${ACTIVATE_TEMPLATE}" > "${ACTIVATE_SH}"

${ALLTOOLS_INSTALLED_MARKERFILE}: ${VENV_MARKERFILE} ${ACTIVATE_SH}
	@touch $@

install: ${ALLTOOLS_INSTALLED_MARKERFILE}
	@[ -e "${HOME}/.ssh/id_rsa.pub" ] || { echo ".ssh/id_rsa.pub not found in user home directory. Maybe try running 'ssh-keygen' without specific option." 2>&1 && exit 42 ; }
	@which jq 1>/dev/null || { echo "jq command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which curl 1>/dev/null || { echo "curl command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which unzip 1>/dev/null || { echo "unzip command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which python 1>/dev/null || { echo "python (>3.6.8) must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@. ${DIR}/activate.sh && if [ ! -d "$&{PUNCHPLATFORM_CONF_DIR}" ]; then mkdir -p "$${PUNCHPLATFORM_CONF_DIR}"; fi

check-env: ${ALLTOOLS_INSTALLED_MARKERFILE}
	source ${DIR}/.venv/bin/activate && source ${ACTIVATE_SH} && env | grep PUNCH && pip freeze

## Configuration

.PHONY: legacy-tls-config test-config test

legacy-tls-config: install
	@$(call green, "Install deployment configuration")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && python3 bin/punchbox.py --config ${LEGACY_TLS_CONFIG_DIR}/legacy_tls_centos_24G.json
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && cp -r "${LEGACY_TLS_CONFIG_DIR}/resolv.yaml" "${LEGACY_TLS_CONFIG_DIR}/security" "$${PUNCHPLATFORM_CONF_DIR}/"
	@$(call green, "Install resources configuration")
# 	@unzip -n -qq "${DEFAULT_PUNCH_EXAMPLES_PATH}" -d "$${PUNCHBOX_BUILD_DIR}"
# 	@cp -r ${PUNCHBOX_LOG_MANAGEMENT_RESOURCES_DIR} "$${PUNCHPLATFORM_CONF_DIR}"
# 	@cp -r ${PUNCHBOX_LOG_MANAGEMENT_TENANTS_DIR} "$${PUNCHPLATFORM_CONF_DIR}"

##@ Step 4

.PHONY: start-vagrant

start-vagrant: ${ALLTOOLS_INSTALLED_MARKERFILE}  ## Start vagrant boxes
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && cd ${PUNCHBOX_VAGRANT_DIR} && vagrant up

##@ Step 5

.PHONY: deploy


deploy: ${ALLTOOLS_INSTALLED_MARKERFILE}
	deploy_cmd="punchplatform-deployer.sh deploy -u vagrant"
# 	if [ -d "$${PUNCHPLATFORM_CONF_DIR}/security" ]; then CMD="${CMD} -e @$${PUNCHPLATFORM_CONF_DIR}/security/deployment_secrets.json"; fi
	echo $$deploy_cmd
# 	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && punchplatform-deployer.sh deploy -u vagrant

##@ Step 6

.PHONY: deploy-config local-integration-vagrant update-deployer-configuration

deploy-config:  ${ALLTOOLS_INSTALLED_MARKERFILE}
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -cp -u vagrant
 
update-deployer-configuration: ${ALLTOOLS_INSTALLED_MARKERFILE}
	@. ${ACTIVATE_SH} && punchbox --platform-config-file $(shell cat ${DIR}/.deployed_configuration) \
								--punch-user-config ${DIR}/punch/configurations/validation

##@ All in one

.PHONY: legacy-tls

legacy-tls:	legacy-tls-configure make-start-vagrant-2 legacy-tls-deploy deploy-config

##@ Cleanup

.PHONY: clean clean-env clean-vagrant clean-all

clean:
	@$(call red, "Clean configuration: ")
	@rm -rf ${DIR}/punch/build

clean-vagrant: ${ALLTOOLS_INSTALLED_MARKERFILE}
	@$(call red, "Destroy vagrant machines")
	@source ${DIR}/.venv/bin/activate && source ${ACTIVATE_SH} && cd ${PUNCHBOX_VAGRANT_DIR} && ${VAGRANT} destroy -f

clean-env:
	@$(call red, "Clean environment and dependencies")
	@rm -rf ${DIR}/.venv
	@rm -rf ${DIR}/activate.sh

clean-all: clean-vagrant clean clean-env

##@ Helpers

.PHONY: help

help:  ## Display help menu
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
