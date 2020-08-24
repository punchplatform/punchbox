# Static vars
DIR=$(shell pwd)
PUNCHBOX_PEX_REQUIREMENTS=${DIR}/bin/pex/punchbox_pex/requirements.txt
ANSIBLE_PEX_REQUIREMENTS=${DIR}/bin/pex/ansible_pex/requirements.txt
PUNCHBOX_PEX=${DIR}/bin/pex/punchbox_pex/punchbox.pex
ANSIBLE_PEX=${DIR}/bin/pex/ansible_pex/ansible.pex
ACTIVATE_SH=${DIR}/activate.sh
DEFAULT_DEPLOYER_ZIP_PATH=${DIR}/../pp-punch/packagings/punch-deployer/target/punch-deployer-*.zip

# Color Functions
ECHO=$(shell which echo)
cyan=${ECHO} -e "\x1b[36m $1\x1b[0m$2"
blue=${ECHO} -e "\x1b[34m $1\x1b[0m$2"
green=${ECHO} -e "\x1b[32m $1\x1b[0m$2"
red=${ECHO} -e "\x1b[31m $1\x1b[0m$2"

ifeq (, $(shell which python3))
 $(error "No python3 installed, it is required. Make sure you also install python3 venv")
endif

help:
	@$(call cyan,"PunchBox Commands", ":")
	@$(call green, "install", "- rebuild everything from scratch")
	@$(call green, "vagrant-dependencies", "- install necessary dependencies for vagrant")
	@$(call green, "punchbox-32G", "- deploy on vagrant box a 32G punchplatform")
	@$(call green, "clean", "- remove all installed binaries and virtualenv relicas")

.venv:
	@$(call blue, "************  CREATE PYTHON 3 .venv  VIRTUALENV  ************")
	@if [ ! -e "${DIR}/.venv/bin/activate" ] ; then python3 -m venv ${DIR}/.venv ; fi
	@. ${DIR}/.venv/bin/activate && pip install -U pip wheel setuptools -q
	@$(call blue, "Python 3 virtualenv installed:", "${DIR}/.venv")

clean: 
	@$(call blue, "************  CLEAN  ************")
	@rm -rf ${DIR}/.venv
	@rm -rf ${DIR}/punch/build
	@rm -rf ${DIR}/vagrant/Vagrantfile
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
	@vagrant plugin install vagrant-disksize
	@vagrant plugin install vagrant-vbguest

configure-punchbox-vagrant:
	@$(call green, "Deployer zip path in .deployer change it\'s content to match yours:", "${DIR}/.deployer")
	@echo ${DEFAULT_DEPLOYER_ZIP_PATH} > ${DIR}/.deployer

clean-deployer:
	@$(call red, "CLEANING OLD DEPLOYER ARCHIVES", "${DIR}/punch/build/punch-deployer-*")
	@rm -rf ${DIR}/punch/build/punch-deployer-*

clean-vagrant:
	@$(call red, "WIPPING VAGRANT VM", "cd ${DIR}/vagrant && vagrant destroy -f")
	@cd ${DIR}/vagrant && vagrant destroy -f

punchbox-ubuntu-32G: clean-deployer vagrant-dependencies
	@$(call green, "Deploying 32G PunchBox")
	@. ${DIR}/.venv/bin/activate && . ${ACTIVATE_SH} && \
		punchbox --platform-config-file ${DIR}/configurations/complete_punch_32G.json \
				 --generate-vagrantfile \
				 --punch-validation-config ${DIR}/punch/configurations/validation/ \
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
				 --punch-validation-config ${DIR}/punch/configurations/validation/ \
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




