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

ifeq (, $(shell which python3))
	$(error "No python3 installed, it is required. Make sure you also install python3 venv")
endif

${VENV_MARKERFILE}:
	@echo "************  CREATE PYTHON 3 VIRTUALENV  ************"
	if [ ! -e "${DIR}/.venv/bin/activate" ] ; then python3 -m venv ${DIR}/.venv ; fi
	. ${DIR}/.venv/bin/activate && pip install -U pip wheel setuptools -q
	@echo "************  GENERATING ACTIVATE.SH  ************"
	@touch $@

${ACTIVATE_SH}: ${ACTIVATE_TEMPLATE} Makefile
	@echo "************  GENERATING ACTIVATE.SH  ************"
	@sed 's#.*PUNCHBOX_DIR=.*#export PUNCHBOX_DIR='${DIR}'#g' "${ACTIVATE_TEMPLATE}" > "${ACTIVATE_SH}"

${PEX_GENERATED_MARKERFILE}: ${VENV_MARKERFILE} ${PUNCHBOX_PEX_REQUIREMENTS} ${ANSIBLE_PEX_REQUIREMENTS} requirements.txt bin/punchbox.py
	@. ${DIR}/.venv/bin/activate && pip install -r requirements.txt -q
	@echo "************  BUILDING PEX PACKAGES  ************"
	@. ${DIR}/.venv/bin/activate && pex -r ${PUNCHBOX_PEX_REQUIREMENTS} --disable-cache -o ${PUNCHBOX_PEX}
	@. ${DIR}/.venv/bin/activate && pex -r ${ANSIBLE_PEX_REQUIREMENTS} --disable-cache -o ${ANSIBLE_PEX}
	@touch $@

${DEPENDENCIES_INSTALLED_MARKERFILE}:
	@which vagrant 1>/dev/null || { echo "'vagrant' command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@echo "************  ADDING VAGRANT DEPENDENCIES  ************"
	@cd ${DIR}/vagrant && ${VAGRANT} plugin install vagrant-disksize
	@cd ${DIR}/vagrant && ${VAGRANT} plugin install vagrant-vbguest
	@touch $@

${ALLTOOLS_INSTALLED_MARKERFILE}: ${VENV_MARKERFILE} ${DEPENDENCIES_INSTALLED_MARKERFILE} ${PEX_GENERATED_MARKERFILE} ${ACTIVATE_SH}
	@touch $@

##@ Welcome to PunchBox project.
##@ With this Makefile, you will be able to setup a running punch in no time.
##@ *************************************************************************

.PHONY: install

install: ${ALLTOOLS_INSTALLED_MARKERFILE} ## build the punchbox tool
	@echo "************  INSTALL STATUS  ************"
	@[ -e "${HOME}/.ssh/id_rsa.pub" ] || { echo ".ssh/id_rsa.pub not found in user home directory. Maybe try running 'ssh-keygen' without specific option." 2>&1 && exit 42 ; }
	@which jq 1>/dev/null || { echo "jq command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which curl 1>/dev/null || { echo "curl command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which unzip 1>/dev/null || { echo "unzip command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@which python 1>/dev/null || { echo "python (>3.6.8) must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	@printf "\x1b[32mpunchbox pex\x1b[0m"
	@printf ": ${PUNCHBOX_PEX}\n"
	@printf "\x1b[32mansible pex \x1b[0m"
	@printf ": ${ANSIBLE_PEX}\n"
	@printf "\x1b[32mactivate.sh \x1b[0m"
	@printf ": ${ACTIVATE_SH}\n"
	@printf "\x1b[32mvirtualenv  \x1b[0m"
	@printf ": ${DIR}/.venv\n"
	

.PHONY: clean clean-vagrant
clean-vagrant:  ## remove vagrant boxes and the generated Vagrantfile
	@echo "************  CLEAN VAGRANT  ************"
	@eval ${CLEANUP_COMMAND}
	@rm -rf ${DIR}/vagrant/Vagrantfile

clean-python:  ## clean the python tools.
	@echo "************  CLEAN PYTHON  ************"
	@rm -rf ${DIR}/.venv
	@rm -rf ${DIR}/bin/pex/punchbox_pex/punchbox.pex
	@rm -rf ${DIR}/bin/pex/ansible_pex/ansible.pex
	@rm -rf ${PEX_GENERATED_MARKERFILEX}
	@rm -rf ${DIR}/ansible/punchbox.*
	@-find ${DIR} -name '*.pyc' -exec rm -f {} +
	@-find ${DIR} -name '*.pyo' -exec rm -f {} +
	@-find ${DIR} -name '*~' -exec rm -f {} +
	@-find ${DIR} -name '__pycache__' -exec rm -fr {} +

clean: clean-vagrant clean-python ## clean everything.
	@echo "************  CLEAN   ************"
	@rm -rf ${DIR}/activate.sh
	@rm -rf ${DEPENDENCIES_INSTALLED_MARKERFILE}
	@rm -rf ${ALLTOOLS_INSTALLED_MARKERFILE}

venv: ${VENV_MARKERFILE}
.PHONY: help
help:  ## Display help menu
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
