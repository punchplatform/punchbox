.DEFAULT_GOAL:=help
SHELL:=/bin/bash
# Command aliases
DIR=$(shell pwd)
VAGRANT=$(shell which vagrant)
SELECT_FROM_LIST=$(DIR)/bin/select-from-list.sh

# Pex files
PUNCHBOX_PEX=$(DIR)/bin/pex/punchbox_pex/punchbox.pex
ANSIBLE_PEX=$(DIR)/bin/pex/ansible_pex/ansible.pex

# Activate scripts
VENV_ACTIVATE=$(DIR)/.venv/bin/activate
ACTIVATE=. $(VENV_ACTIVATE) && . $(DIR)/activate.sh

# Vagrant
VAGRANT_DIR=$(DIR)/vagrant
VAGRANT_FILE=$(DIR)/vagrant/Vagrantfile

# Default paths
USER_CONF=$(DIR)/punch/configurations/validation

# Targets
VENV_INSTALLED=$(DIR)/.venv/.installed
MODEL=$(DIR)/punch/build/model.json
DEPLOYMENT_SETTINGS=$(DIR)/punch/build/pp-conf/punchplatform-deployment.settings
PLATFORM_TEMPLATES=$(DIR)/punch/platform_template/*
BIN=$(DIR)/bin/*
DEPLOYMENT_SECRETS=$(DIR)/punch/build/deployment_secrets.json

# Markers
MARKERS_DIR=$(DIR)/markers
VAGRANT_DEPENDENCIES_INSTALLED=$(MARKERS_DIR)/.vagrant_dependencies_installed
PREREQUISITES_INSTALLED=$(MARKERS_DIR)/.prerequisites_installed
DEPLOYER_MARKER=$(MARKERS_DIR)/.deployer
DEPLOYED_CONFIGURATION_MARKER=$(MARKERS_DIR)/.deployed_configuration
OS_MARKER=$(MARKERS_DIR)/.os
PUNCHBOX_OPTIONS_MARKER=$(MARKERS_DIR)/.punchbox_options

# Configuration values
OS=$(shell cat $(OS_MARKER))
DEPLOYED_CONFIGURATION=$(shell cat $(DEPLOYED_CONFIGURATION_MARKER) 2> /dev/null)
PUNCHBOX_OPTIONS=$(shell cat $(PUNCHBOX_OPTIONS_MARKER))
DEPLOYER=$(shell cat $(DEPLOYER_MARKER))

# Color Functions
blue=echo -e "\033[1;34m $1 \033[0m$2"
cyan=echo -e "\033[1;36m $1 \033[0m$2"
green=echo -e "\033[1;32m $1 \033[0m$2"
red=echo -e "\033[1;31m $1 \033[0m$2"

ifeq (, $(shell which python3))
 $(error "No python3 installed, it is required. Make sure you also install python3 venv")
endif
$(shell [[ ! -d $(MARKERS_DIR) ]] && mkdir $(MARKERS_DIR))

##@ Welcome to punchbox deployer tool. Follow the steps listed below to deploy, run or test a complete punch.

##@ Step 1 : build the punchbox tools and prepare the environment.

.PHONY: install

install: $(PREREQUISITES_INSTALLED) ## Build the punchbox tools
	@$(call green, "************  Install ************")
	@$(call blue, "PunchBox pex:", "$(PUNCHBOX_PEX)")
	@$(call blue, "Ansible pex:", "$(ANSIBLE_PEX)")
	@$(call green, "Install complete")

$(PREREQUISITES_INSTALLED): $(VENV_INSTALLED) $(VAGRANT_DEPENDENCIES_INSTALLED) $(ANSIBLE_PEX) $(PUNCHBOX_PEX)
	@[ -e "$(HOME)/.ssh/id_rsa.pub" ] || { echo ".ssh/id_rsa.pub not found in user home directory. Maybe try running 'ssh-keygen' without specific option." 2>&1 && exit 42 ; }
	@which jq 1>/dev/null || { echo "jq command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which curl 1>/dev/null || { echo "curl command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which unzip 1>/dev/null || { echo "unzip command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which python 1>/dev/null || { echo "python (>3.6.8) must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@touch $@

$(PUNCHBOX_PEX): $(VENV_INSTALLED) bin/pex/punchbox_pex/requirements.txt
	@$(call blue, "Build pex packages for punchbox")
	@. $(VENV_ACTIVATE) && pex -r bin/pex/punchbox_pex/requirements.txt --disable-cache -o $(PUNCHBOX_PEX)

$(ANSIBLE_PEX): $(VENV_INSTALLED) bin/pex/ansible_pex/requirements.txt
	@$(call blue, "Build pex packages for Ansible")
	@. $(VENV_ACTIVATE) && pex -r bin/pex/ansible_pex/requirements.txt --disable-cache -o $(ANSIBLE_PEX)

$(VENV_INSTALLED): requirements.txt
	@$(call green, "************  Create python3 virtualenv ************")
	@if [ ! -e "$(VENV_ACTIVATE)" ] ; then python3 -m venv $(DIR)/.venv ; fi
	@. $(VENV_ACTIVATE) && pip install -U pip wheel setuptools -q
	@$(call green, "Installing PunchBox python dependencies virtualenv.")
	@. $(VENV_ACTIVATE) && pip install -r requirements.txt -q
	@$(call blue, "Python 3 virtualenv installed:", "$(DIR)/.venv")
	@touch $@

$(VAGRANT_DEPENDENCIES_INSTALLED):
	@which vagrant 1>/dev/null || { echo "'vagrant' command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@$(call green, "************ Add vagrant dependencies ************")
	@cd $(VAGRANT_DIR) && $(VAGRANT) plugin install vagrant-disksize
	@cd $(VAGRANT_DIR) && $(VAGRANT) plugin install vagrant-vbguest
	@touch $@

##@ Step 2 : configure the different options : deployer, configuration, os, security, validation...

.PHONY: configure

configure: install $(OS_MARKER) $(DEPLOYED_CONFIGURATION_MARKER) $(PUNCHBOX_OPTIONS_MARKER) $(DEPLOYER_MARKER) ## Set configuration
	@$(call green, "************ Selected configuration ************")
	@$(call blue, "OS : $(OS)")
	@$(call blue, "Configuration : $(DEPLOYED_CONFIGURATION)")
	@$(call blue, "Punchbox options : $(PUNCHBOX_OPTIONS)")
	@$(call blue, "Deployer : $(DEPLOYER)")

$(OS_MARKER):
	@$(call green, "************  Setup OS ************")
	@$(call blue, "Select an OS from the list using its number :")
	@os=$$($(SELECT_FROM_LIST) "ubuntu/bionic64" "centos/7" "rhel/7") \
		&& $(call blue, "OS selected : $$os") \
		&& echo $$os > $(OS_MARKER)


$(DEPLOYED_CONFIGURATION_MARKER):
	@$(call green, "************  Setup configuration ************")
	@$(call blue, "Select a configuration from the list using its number :")
	@confs=$$(find $(DIR)/configurations -name '*.json') \
		&& conf=$$($(SELECT_FROM_LIST) $$confs) \
	    && $(call blue, "Configuration selected : $$conf") \
	    && echo $$conf > $(DEPLOYED_CONFIGURATION_MARKER)

$(PUNCHBOX_OPTIONS_MARKER):
	@$(call green, "************  Setup Punchbox options ************")
	@$(call blue, "Select punchbox options :")
	@read -p "Enable security (y/n) ? " -r; \
     [[ $$REPLY =~ ^[Yy]$$ ]] && security="--security"; \
     read -p "Include validation conf (y/n) ? " -r; \
     [[ $$REPLY =~ ^[Yy]$$ ]] && validation="--validation"; \
     echo "$$security $$validation" > $(PUNCHBOX_OPTIONS_MARKER)

$(DEPLOYER_MARKER):  ## register your punch deployer
	@$(call green, "************  Setup deployer ************")
	@$(call blue, "Adding reference to your punch deployer. Check the file:", "$(DEPLOYER_MARKER)")
ifndef PUNCH_DIR
	@read -e -p "Path to deployer zip : " DEPLOYER_ZIP_PATH && echo $$DEPLOYER_ZIP_PATH > $(DEPLOYER_MARKER)
else
	$(shell echo $(PUNCH_DIR)/packagings/punch-deployer/target/punch-deployer-*.zip > $(DEPLOYER_MARKER))
endif

##@ Step 3 : generate platform model to deploy.

.PHONY: punchbox

punchbox: $(VAGRANT_FILE) $(DEPLOYMENT_SETTINGS) ## Run punchbox templating
	@$(call green, "************ Punchbox generation is done ************")

$(DEPLOYMENT_SETTINGS): $(MODEL)
	@$(call green, "************ Generate Deployment Settings ************")
	@$(ACTIVATE) && punchplatform-deployer.sh --generate-platform-config \
								              --templates-dir $(DIR)/punch/deployment_template/ \
								              --model $(MODEL)

$(VAGRANT_FILE): $(PREREQUISITES_INSTALLED) $(OS_MARKER) $(DEPLOYED_CONFIGURATION_MARKER) $(DEPLOYED_CONFIGURATION) \
				 vagrant/Vagrantfile.j2 $(BIN)  ## Render vagrant template
	@$(call green, "************ Generate Vagrantfile ************")
	@$(ACTIVATE) && punchbox --platform-config-file $(DEPLOYED_CONFIGURATION) \
							 --os $(OS) \
							 --generate-vagrantfile

$(MODEL): $(DEPLOYED_CONFIGURATION_MARKER) $(OS_MARKER) $(PUNCHBOX_OPTIONS_MARKER) $(DEPLOYED_CONFIGURATION) \
 		  $(DEPLOYER_MARKER) $(PLATFORM_TEMPLATES) $(USER_CONF)/* $(BIN)  ## Run punchbox templating
	@$(call green, "************ Generate Model ************")
	@$(ACTIVATE) && punchbox --platform-config-file $(DEPLOYED_CONFIGURATION) \
				 			 --punch-user-config $(USER_CONF) \
							 --deployer $(DEPLOYER) \
							 --os $(OS) \
							 --interface $(shell [ "$(OS)" == "centos/7" ] && echo eth1 || echo enp0s8) \
							 $(PUNCHBOX_OPTIONS)

##@ Step 4 : start (or stop) your VMs

.PHONY: start-vagrant stop-vagrant

start-vagrant: $(VAGRANT_FILE) ## Start vagrant boxes
	@$(call green, "************ Starting Vagrant Boxes ************")
	@$(ACTIVATE) && punchbox --start-vagrant

stop-vagrant: $(VAGRANT_FILE) ## Stop vagrant boxes. This is useful to simply stop, not destroying.
	@$(call green, "************ Stopping Vagrant Boxes ************")
	@$(ACTIVATE) && punchbox --stop-vagrant

##@ Step 5 : deploy the punch, i.e. deploy all the punch components to yours vms.

.PHONY: deploy

deploy: start-vagrant $(MODEL)  ## Deploy punch components to the target VMs
	@$(call green, "************ Deploying Configuration ************")
	@[[ "$(PUNCHBOX_OPTIONS)" == *"security"* ]] && security="-e $(DIR)/punch/build/pp-conf/deployment_secrets.json"; \
	$(ACTIVATE) && punchplatform-deployer.sh --deploy -u vagrant $$security


##@ Step 6 (optional) : add a user punch configuration, i.e. tenants, channels and punchlines.

.PHONY: deploy-config local-integration-vagrant update-deployer-configuration update-validation-configuration

deploy-config: start-vagrant $(MODEL)  ## Deploy punch user configuration files to the target operator
	@$(ACTIVATE) && punchplatform-deployer.sh -cp -u vagrant


##@ Step 7 (optional) : use the robot tests to validate your platform

local-integration-vagrant: deploy-config  ## Deploy user configuration and run validation
	@$(call green, "Executing on server1", "/home/vagrant/pp-conf/check_platform.sh")
	@$(ACTIVATE) && cd $(VAGRANT_DIR) && \
		$(VAGRANT) ssh server1 -c "/home/vagrant/pp-conf/check_platform.sh -f; exit"

update-validation-configuration: $(DEPLOYER_MARKER) ## Use this rule to update the validation resources/config from your standalone archive test resources
	@$(ACTIVATE) && update_validation_config.sh

##@ Clean up

.PHONY: stop clean clean-deployer clean-punch-config clean-vagrant clean-validation-scheduler clean-markers

stop: stop-vagrant ## Only stop vagrant boxes
	@$(call green, "Stopped vagrant boxes")

clean: clean-vagrant clean-deployer ## Cleanup vagrant and deployer. Watchout this wipes everything.
	@rm -rf $(DIR)/.venv
	@rm -rf $(DIR)/punch/build
	@rm -rf $(PUNCHBOX_PEX)
	@rm -rf $(ANSIBLE_PEX)
	@rm -rf $(VAGRANT_DEPENDENCIES_INSTALLED)
	@rm -rf $(PREREQUISITES_INSTALLED)
	@rm -rf $(DIR)/ansible/punchbox.*
	@-find $(DIR) -name '*.pyc' -exec rm -f {} +
	@-find $(DIR) -name '*.pyo' -exec rm -f {} +
	@-find $(DIR) -name '*~' -exec rm -f {} +
	@-find $(DIR) -name '__pycache__' -exec rm -fr {} +
	@$(call blue, "Deleting build vagrantfile activate.sh punchbox.pex ansible.pex and pyc/pyo files")
	@$(call green, "Cleaned")

clean-deployer:  ## Remove the installed deployer
	@$(call blue, "Cleaning deployer archive", "$(DIR)/punch/build/punch-deployer-*")
	@rm -rf $(DIR)/punch/build/punch-deployer-*
	@$(call red, "Will not be removed: do it manually", "$(DEPLOYER_MARKER) and $(DEPLOYED_CONFIGURATION_MARKER)")

clean-punch-config:  ## Remove Punchplatform Configurations
	@$(call blue, "Cleaning old punch configurations", "$(DIR)/punch/build/pp-conf/*")
	@rm -rf $(DIR)/punch/build/pp-conf/

clean-vagrant:  ## Remove vagrant boxes and generated Vagrantfile
	@$(call blue, "Destroying vagrant vms", "cd $(VAGRANT_DIR) \&\& $(VAGRANT) destroy -f")
	@cd $(VAGRANT_DIR) && $(VAGRANT) destroy -f
	@rm -rf $(VAGRANT_FILE)

clean-markers:  ## Remove all makefile markers
	@$(call blue, "Cleaning markers dir", "$(MARKERS_DIR)")
	@rm -rf $(MARKERS_DIR)

##@ Helpers

.PHONY: help

help:  ## Display help menu
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
