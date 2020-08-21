DIR=$(shell pwd)
PUNCHBOX_PEX_REQUIREMENTS=${DIR}/bin/pex/punchbox_pex/requirements.txt
ANSIBLE_PEX_REQUIREMENTS=${DIR}/bin/pex/ansible_pex/requirements.txt
PUNCHBOX_PEX=${DIR}/bin/pex/punchbox_pex/punchbox.pex
ANSIBLE_PEX=${DIR}/bin/pex/ansible_pex/ansible.pex
ACTIVATE_SH=${DIR}/activate.sh
DEFAULT_DEPLOYER_ZIP_PATH=${DIR}/../pp-punch/packagings/punch-deployer/target/punch-deployer-*.zip

ifeq (, $(shell which python3))
 $(error "No python3 installed, it is required. Make sure you also install python3 venv")
endif

help:
	@echo "install                        - rebuild everything from scratch "
	@echo "clean                          - remove all build, test, coverage and Python artifacts"
	@echo "vagrant-dependencies           - install necessary dependencies for vagrant"

.venv:
	$(info ************  CREATE PYTHON 3 .venv  VIRTUALENV  ************)
	@if [ ! -e "${DIR}/.venv/bin/activate" ] ; then python3 -m venv ${DIR}/.venv ; fi
	@. ${DIR}/.venv/bin/activate && pip install -U pip wheel setuptools -q
	$(info Python 3 virtualenv installed in ${DIR}/.venv)

clean: 
	$(info ************  CLEAN  ************)
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
	$(info WIPED: build, vagrantfile, activate.sh, punchbox.pex, ansible.pex and pyc/pyo files)

install: clean .venv
	$(info ************  INSTALL  ************)
	@. ${DIR}/.venv/bin/activate && pip install -r requirements.txt -q
	$(info PunchBox python dependencies installed in virtualenv)
	@. ${DIR}/.venv/bin/activate && pex -r ${PUNCHBOX_PEX_REQUIREMENTS} --disable-cache --inherit-path -o ${PUNCHBOX_PEX}
	$(info PunchBox pex: ${PUNCHBOX_PEX})
	@. ${DIR}/.venv/bin/activate && pex -r ${ANSIBLE_PEX_REQUIREMENTS} --disable-cache --inherit-path -o ${ANSIBLE_PEX}
	$(info Ansible pex: ${ANSIBLE_PEX})
	@echo export PUNCHBOX_DIR=${DIR} > ${ACTIVATE_SH}
	@echo export PUNCHPLATFORM_CONF_DIR=${DIR}/punch/build/pp-conf >> ${ACTIVATE_SH}
	@echo export PATH='$$PATH':${DIR}/bin >> ${ACTIVATE_SH}
	@echo export PS1="'\[\e[1;32m\]punchbox:\[\e[0m\][\W]\$ '" >> ${ACTIVATE_SH}
	@echo export PATH='$$PATH':${DIR}/bin/pex/ansible_pex >> ${ACTIVATE_SH}
	$(info activate.sh: ${ACTIVATE_SH})
	$(info installation complete, you should be able to use other commands !)

vagrant-dependencies:
	$(info ************ ADDING VAGRANT DEPENDENCIES ************)
	@vagrant plugin install vagrant-disksize
	@vagrant plugin install vagrant-vbguest

configure-punchbox-vagrant:
	$(info Deployer zip path is set to (change it to match yours): ${DIR}/.deployer)
	@echo ${DEFAULT_DEPLOYER_ZIP_PATH} > ${DIR}/.deployer

clean-deployer:
	$(info CLEANING OLD DEPLOYER ARCHIVES)
	@rm -rf ${DIR}/punch/build/punch-deployer-*

punchbox-32G: clean-deployer
	$(info Deploying 32G PunchBox)
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

	




