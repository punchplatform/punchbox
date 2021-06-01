.DEFAULT_GOAL:=help
SHELL:=/bin/bash

# Static vars
# shells
DIR=$(shell pwd)
MAKE=$(shell which make)
BASH=$(shell which bash)
SH=$(shell which sh)
VAGRANT=$(shell which vagrant)

# PUNCHBOX NAMES
PUNCHBOX_PY=punchbox.py

# PUNCHBOX DIRS
PUNCHBOX_CONF_DIR=${DIR}/configurations
PUNCHBOX_BIN_DIR=${DIR}/bin
PUNCHBOX_DEPLOYER_DIR=$(shell find $$PUNCHBOX_BUILD_DIR -name "${PUNCH_DEPLOYER_NAME}" -type d | xargs realpath)
PUNCHBOX_LOG_MANAGEMENT_RESOURCES_DIR=$${PUNCHBOX_BUILD_DIR}/${PUNCH_EXAMPLES_NAME}/conf/platforms/log_management_platform/resources
PUNCHBOX_LOG_MANAGEMENT_TENANTS_DIR=$${PUNCHBOX_BUILD_DIR}/${PUNCH_EXAMPLES_NAME}/conf/platforms/log_management_platform/tenants

# PUNCHBOX ENVIRONMENT
ACTIVATE_SH=${DIR}/activate.sh
ACTIVATE_TEMPLATE=${DIR}/.activate.template
VENV_INSTALLED_MARKERFILE=${DIR}/.venv/.installed
DEPLOYER_INSTALLED_MARKERFILE=${DIR}/.deployer_installed
ENV_INSTALLED_MARKERFILE=${DIR}/.env_installed

# PUNCHBOX CONFIGURATIONS
DEFAULT_PUNCH_CONFIG_DIR=${PUNCHBOX_CONF_DIR}/default
DEFAULT_TLS_CONFIG_DIR=${PUNCHBOX_CONF_DIR}/default_tls

# PUNCH NAMES
PUNCH_DEPLOYER_NAME=punch-deployer-*
PUNCH_EXAMPLES_NAME=punch-examples-*

# PUNCH SOURCES
DEFAULT_DEPLOYER_ZIP_PATH=$${PUNCH_DIR}/packagings/punch-deployer/target/${PUNCH_DEPLOYER_NAME}.zip
DEFAULT_EXAMPLES_PATH=$${PUNCH_DIR}/examples/target/${PUNCH_EXAMPLES_NAME}.zip
PUNCH_DEPLOYMENT_RESOURCES=$${PUNCH_DIR}/packagings/punch-deployment/resources

# Color Functions
ECHO=$(shell which echo)
cyan=${ECHO} -e "\x1b[36m $1\x1b[0m$2"
blue=${ECHO} -e "\x1b[34m $1\x1b[0m$2"
green=${ECHO} -e "\x1b[32m $1\x1b[0m$2"
red=${ECHO} -e "\x1b[31m $1\x1b[0m$2"

ifeq (, $(shell which python3))
 $(error "No python3 installed, it is required. Make sure you also install python3 venv")
endif

##@ Welcome to PunchBox Makefile
##@ Make sure to compile a punch version and set PUNCHBOX_DIR to its folder location !

##@ All in one procedure :

.PHONY: default-punch default-tls

default: config start-vagrant deploy ## Install a basic deployment configuration, start vagrant boxes and deploy

default-tls: config-tls start-vagrant deploy-secured ## Install a TLS deployment configuration, start vagrant boxes and deploy

##@ Step-by-step procedure :

##@ 1. Configuration

.PHONY: config config-tls

config: install ## Install a basic deployment environment, deployer, configuration and vagrant file
	@$(call green, "Install default deployment configuration")
	@. ${ACTIVATE_SH} && cp -r "${DEFAULT_PUNCH_CONFIG_DIR}/resolv.hjson" \
		"${DEFAULT_PUNCH_CONFIG_DIR}/punchplatform-deployment.settings" \
		"$${PUNCHPLATFORM_CONF_DIR}/" && \
		cp "${DEFAULT_PUNCH_CONFIG_DIR}/Vagrantfile" $${PUNCHBOX_VAGRANT_DIR}

config-tls: install ## Install a TLS deployment environment, deployer, configuration and vagrant file
	@$(call green, "Install default TLS deployment configuration")
	@. ${ACTIVATE_SH} && cp -r "${DEFAULT_TLS_CONFIG_DIR}/resolv.yaml" \
		"${DEFAULT_TLS_CONFIG_DIR}/security" \
		"${DEFAULT_TLS_CONFIG_DIR}/punchplatform-deployment.settings" \
		"$${PUNCHPLATFORM_CONF_DIR}/" && \
		cp "${DEFAULT_TLS_CONFIG_DIR}/Vagrantfile" $${PUNCHBOX_VAGRANT_DIR}
	@$(call green, "Install default TLS resources configuration")
	@. ${ACTIVATE_SH} && unzip -n -qq "${DEFAULT_EXAMPLES_PATH}" -d "$${PUNCHBOX_BUILD_DIR}" && \
		cp -r ${PUNCHBOX_LOG_MANAGEMENT_RESOURCES_DIR} "$${PUNCHPLATFORM_CONF_DIR}" && \
		cp -r ${PUNCHBOX_LOG_MANAGEMENT_TENANTS_DIR} "$${PUNCHPLATFORM_CONF_DIR}"

config-dev: install
	@$(call green, "Install default deployment configuration")
	. ${ACTIVATE_SH} && python3 ${PUNCHBOX_BIN_DIR}/${PUNCHBOX_PY} --config ${PUNCHBOX_CONF_DIR}/default/default_config.json

##@ 2. Vagrant

.PHONY: start-vagrant clean-vagrant

start-vagrant: ${ENV_INSTALLED_MARKERFILE} ## Start vagrant boxes
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && cd $${PUNCHBOX_VAGRANT_DIR} && vagrant up

reload-vagrant: ${ENV_INSTALLED_MARKERFILE} ## Reload vagrant boxes
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && cd $${PUNCHBOX_VAGRANT_DIR} && vagrant reload

clean-vagrant: ${ENV_INSTALLED_MARKERFILE} ## Destroy vagrant boxes
	@$(call red, "Destroy vagrant machines")
	@source ${DIR}/.venv/bin/activate && source ${ACTIVATE_SH} && cd $${PUNCHBOX_VAGRANT_DIR} && ${VAGRANT} destroy -f

##@ 3. Deployment

.PHONY: deploy deploy-secured

deploy: ${ENV_INSTALLED_MARKERFILE} ## Launch a deployment
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && punchplatform-deployer.sh deploy -u vagrant

deploy-secured: ## Launch a deployment using secrets in $PUNCHPLATFORM_CONF_DIR/security/deployment_secrets.json
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && punchplatform-deployer.sh deploy -u vagrant -e @$${PUNCHPLATFORM_CONF_DIR}/security/deployment_secrets.json

# User configuration

.PHONY: deploy-config local-integration-vagrant update-deployer-configuration

deploy-config:  ${ENV_INSTALLED_MARKERFILE}
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchplatform-deployer.sh -cp -u vagrant
 
update-deployer-configuration: ${ENV_INSTALLED_MARKERFILE}
	@. ${ACTIVATE_SH} && punchbox --platform-config-file $(shell cat ${DIR}/.deployed_configuration) \
								--punch-user-config ${DIR}/punch/configurations/validation


##@ Developer usage :

# Environment

.PHONY: install-dependencies install print-env

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
	@. ${DIR}/activate.sh && unzip -n -qq ${DEFAULT_DEPLOYER_ZIP_PATH} -d $${PUNCHBOX_BUILD_DIR}
	@touch $@

install-dependencies: ${ENV_INSTALLED_MARKERFILE}
	@[ -e "${HOME}/.ssh/id_rsa.pub" ] || { echo ".ssh/id_rsa.pub not found in user home directory. Maybe try running 'ssh-keygen' without specific option." 2>&1 && exit 42 ; }
	@which jq 1>/dev/null || { echo "jq command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which curl 1>/dev/null || { echo "curl command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which unzip 1>/dev/null || { echo "unzip command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which python 1>/dev/null || { echo "python (>3.6.8) must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }

install: install-dependencies ${DEPLOYER_INSTALLED_MARKERFILE} ## Install the environment, the deployer and create empty $PUNCHPLATFORM_CONF_DIR
	@. ${ACTIVATE_SH} && if [ ! -d "$&{PUNCHPLATFORM_CONF_DIR}" ]; then mkdir -p "$${PUNCHPLATFORM_CONF_DIR}"; fi

print-env: ${ENV_INSTALLED_MARKERFILE} ## Print the python/shell user environment for debug purpose
	@$(call blue, "Python dependencies")
	@source ${DIR}/.venv/bin/activate && pip freeze
	@$(call blue, "Shell environment")
	@source ${ACTIVATE_SH} && env | grep PUNCH

dev: ${ENV_INSTALLED_MARKERFILE} ## Create symbolic links from $PUNCH_DIR's deployment sources
	@$(call green, "Create links from pp-punch sources")
	@. ${ACTIVATE_SH} && \
		if [ -d ${PUNCHBOX_DEPLOYER_DIR}/roles ]; then mv ${PUNCHBOX_DEPLOYER_DIR}/roles ${PUNCHBOX_DEPLOYER_DIR}/.roles.bak; fi && \
		if [ -d ${PUNCHBOX_DEPLOYER_DIR}/inventory_templates ]; then mv ${PUNCHBOX_DEPLOYER_DIR}/inventory_templates ${PUNCHBOX_DEPLOYER_DIR}/.inventory_templates.bak; fi && \
		if [ -f ${PUNCHBOX_DEPLOYER_DIR}/deploy-punchplatform-production-cluster.yml ]; then mv ${PUNCHBOX_DEPLOYER_DIR}/deploy-punchplatform-production-cluster.yml ${PUNCHBOX_DEPLOYER_DIR}/.deploy-punchplatform-production-cluster.yml.bak; fi && \
		if [ -f ${PUNCHBOX_DEPLOYER_DIR}/bin/punchplatform-deployer.sh ]; then mv ${PUNCHBOX_DEPLOYER_DIR}/bin/punchplatform-deployer.sh ${PUNCHBOX_DEPLOYER_DIR}/bin/.punchplatform-deployer.sh.bak; fi
	@. ${ACTIVATE_SH} && \
		ln -s ${PUNCH_DEPLOYMENT_RESOURCES}/roles ${PUNCHBOX_DEPLOYER_DIR}/roles && \
		ln -s ${PUNCH_DEPLOYMENT_RESOURCES}/inventory_templates ${PUNCHBOX_DEPLOYER_DIR}/inventory_templates && \
		ln -s ${PUNCH_DEPLOYMENT_RESOURCES}/deploy-punchplatform-production-cluster.yml ${PUNCHBOX_DEPLOYER_DIR}/deploy-punchplatform-production-cluster.yml && \
		ln -s ${PUNCH_DEPLOYMENT_RESOURCES}/bin/punchplatform-deployer.sh ${PUNCHBOX_DEPLOYER_DIR}/bin/punchplatform-deployer.sh

##@ Cleaning :

.PHONY: clean clean-all

clean: ${ENV_INSTALLED_MARKERFILE} ## Clean configuration in $PUNCHPLATFORM_CONF_DIR
	@$(call red, "Clean configuration")
	@source ${ACTIVATE_SH} && rm -rf $${PUNCHPLATFORM_CONF_DIR}

clean-all: ## Clean the configuration, the deployer and the environment
	@$(call red, "Clean the all configurations and deployer sources")
	@source ${ACTIVATE_SH} && rm -rf $${PUNCHBOX_BUILD_DIR}
	@$(call red, "Clean environment and dependencies")
	@rm -rf ${DIR}/.venv
	@rm -rf ${DIR}/activate.sh

##@ Helpers

.PHONY: help

help:  ## Display help menu
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
