DIR=$(shell pwd)

ifeq (, $(shell which python3))
 $(error "No python3 installed, it is required. Make sure you also install python3 venv")
endif

help:
	@echo "install                        - rebuild everything from scratch "
	@echo "clean                          - remove all build, test, coverage and Python artifacts"

all: default
	./bin/install.sh

default: clean install

.venv:
	$(info ************  CREATE PYTHON 3 .venv  VIRTUALENV  ************)
	if [ ! -e "${DIR}/.venv/bin/activate" ] ; then python3 -m venv ${DIR}/.venv ; fi
	. ${DIR}/.venv/bin/activate && python --version

clean: 
	$(info ************  CLEAN  ************)
	rm -rf ${DIR}/punch/build
	rm -rf ${DIR}/vagrant/Vagrantfile
	rm -rf ${DIR}/activate.sh
	rm -rf ${DIR}/bin/pex/punchbox_pex/punchbox.pex
	rm -rf ${DIR}/bin/pex/ansible_pex/ansible.pex
	rm -rf ${DIR}/ansible/punchbox.*

install: clean
	$(info ************  INSTALL  ************)
	./bin/install.sh




