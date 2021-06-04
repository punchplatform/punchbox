#!/usr/bin/env bash

# CONSTANTS
red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
cyn=$'\e[1;36m'
end=$'\e[0m'

SCRIPT_PATH="$(realpath "$0")"
DIR="$(dirname "${SCRIPT_PATH}")"
LOGFILE="/tmp/punchbox.log"
PUNCHBOX_CONF_DIR="${DIR}/configurations"
ACTIVATE_SH="${DIR}/activate.sh"
ACTIVATE_TEMPLATE="${DIR}/.activate.template"
PUNCHBOX_PY="${DIR}/bin/punchbox.py"
PYTHON_ENV_INSTALLED_MARKER="${DIR}/.python_env_installed"

# VARIABLES
conf_mode=""
vagrant_mode=""

# FUNCTIONS
function usage() {
    printf "Description

    Syntax: punchbox [options]

    options:
    ${grn}run${end} [default|tls|<path>]      If 'default' or 'tls', generate default deployment settings, start vagrant and deploy.
                                  Else generate deployment settings, start vagrant and deploy using the provided punchbox config file.

    ${cyn}config${end} [default|tls|<path>]         If 'default' or 'tls', only generate default deployment settings and Vagrantfile.
                                        Else only generate deployment settings and Vagrantfile with the provided punchbox config path.
    ${cyn}vagrant${end} [start|stop|clean|reload]   Execute the provided action on your vagrant boxes.
    ${cyn}deploy${end}                              Deploy the current settings on the running vagrant boxes.

    ${red}clean${end}                               Clean all generated files. Do not destroy vagrant boxes.

    help    Print this.
    env     Print the installed python dependencies in punchbox virtualenv and the punchbox shell environment .
    dev     Create symbolic links to \$PUNCH_DIR sources (i.e pp-punch). Set \$PUNCH_DIR first.
    "
}

function install_env() {
    # check dependencies
    [ -e "${HOME}/.ssh/id_rsa.pub" ] || { echo ".ssh/id_rsa.pub not found in user home directory. Maybe try running 'ssh-keygen' without specific option." 2>&1 && exit 42 ; }
	which jq 1>/dev/null || { echo "jq command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	which curl 1>/dev/null || { echo "curl command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	which unzip 1>/dev/null || { echo "unzip command must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }
	which python 1>/dev/null || { echo "python (>3.6.8) must be available on this node (deployer prerequisite)" 2>&1 && exit 11 ; }

    # python env
    if [ ! -f "${PYTHON_ENV_INSTALLED_MARKER}" ]; then
        printf "Install python environment"
        if [ ! -e "${DIR}/.venv/bin/activate" ] ; then
            python3 -m venv ${DIR}/.venv
        fi
        source "${DIR}/.venv/bin/activate"
        pip install -U pip wheel setuptools -q
        pip install -r ${DIR}/requirements.txt --quiet
        touch "${PYTHON_ENV_INSTALLED_MARKER}"
    fi

    # shell env
    sed 's#.*PUNCHBOX_DIR=.*#export PUNCHBOX_DIR='${DIR}'#g' "${ACTIVATE_TEMPLATE}" > "${ACTIVATE_SH}"
}

function configure() {
    # pp-conf
    if [ ! -d "${PUNCHPLATFORM_CONF_DIR}" ]; then
        mkdir -p "${PUNCHPLATFORM_CONF_DIR}"
    fi

    # parse the configuration
    # it may be a supported mode like 'default' or 'tls'
    # else it is a configuration path provided by the user
    if [ "$conf_mode" == "default" ]; then
        # default conf
        config_file="${PUNCHBOX_CONF_DIR}/default/default_config.json"
    elif [ "$conf_mode" == "tls" ]; then
        # default tls conf
        config_file="${PUNCHBOX_CONF_DIR}/default/default_config.json"
    else
        # the conf_mode (i.e the argument is a path given by the user)
        config_file="${conf_mode}"
    fi

    # generate deployment settings
    echo "Generate deployment settings from ${config_file}"
    echo "Log inside ${LOGFILE}"
    python3 ${PUNCHBOX_PY} --config "${config_file}" >> "${LOGFILE}" 2>&1

    if [ ! $? -eq 0 ]; then
        printf "${red}FAIL: check ${LOGFILE} for error message"
    fi
}

function vagrant(){
    if [ -f "${PUNCHBOX_VAGRANT_DIR}/Vagrantfile" ]; then
        cd "${PUNCHBOX_VAGRANT_DIR}"
        if [ "${vagrant_mode}" == "start" ]; then
            vagrant start
        elif [ "${vagrant_mode}" == "stop" ]; then
            vagrant halt
        elif [ "${vagrant_mode}" == "reload" ]; then
            vagrant reload
        elif [ "${vagrant_mode}" == "clean" ]; then
            vagrant destroy -f
        fi
    else
        echo "${red}FAIL: Missing Vagrantfile"
    fi

    cd "${DIR}"
}

function deploy() {
    echo "Deploy using ${PUNCH_DEPLOYER}"
    punchplatform-deployer.sh deploy -u vagrant
}

function development(){

    if [ -z "${PUNCH_DIR}" ]; then
        # check for pp-punch dir next to punchbox_dir
        if [ -d "${PUNCHBOX_DIR}/../pp-punch" ]; then
            export PUNCH_DIR="${PUNCHBOX_DIR}/../pp-punch"
        else
            echo "${red}FATAL: Missing \$PUNCH_DIR. Git clone 'pp-punch' next to punchbox dir, or set \$PUNCH_DIR in your environment${end}"
            exit 1
        fi
	fi

    punch_deployment_sources="${PUNCH_DIR}/packagings/punch-deployment/resources"

    if [ -d "${PUNCH_DEPLOYER}/roles" ]; then mv "${PUNCH_DEPLOYER}/roles" "${PUNCH_DEPLOYER}/.roles.bak"; fi
    if [ -d "${PUNCH_DEPLOYER}/inventory_templates" ]; then mv "${PUNCH_DEPLOYER}/inventory_templates" "${PUNCH_DEPLOYER}/.inventory_templates.bak"; fi
    if [ -f "${PUNCH_DEPLOYER}/deploy-punchplatform-production-cluster.yml" ]; then mv "${PUNCH_DEPLOYER}/deploy-punchplatform-production-cluster.yml" "${PUNCH_DEPLOYER}/.deploy-punchplatform-production-cluster.yml.bak"; fi
    if [ -f "${PUNCH_DEPLOYER}/bin/punchplatform-deployer.sh" ]; then mv "${PUNCH_DEPLOYER}/bin/punchplatform-deployer.sh" "${PUNCH_DEPLOYER}/bin/.punchplatform-deployer.sh.bak"; fi
	
    ln -s "${punch_deployment_sources}/roles" "${PUNCH_DEPLOYER}/roles"
    ln -s "${punch_deployment_sources}/inventory_templates" "${PUNCH_DEPLOYER}/inventory_templates"
    ln -s "${punch_deployment_sources}/deploy-punchplatform-production-cluster.yml" "${PUNCH_DEPLOYER}/deploy-punchplatform-production-cluster.yml"
    ln -s "${punch_deployment_sources}/bin/punchplatform-deployer.sh" "${PUNCH_DEPLOYER}/bin/punchplatform-deployer.sh"
}

function environment() {
    echo "${cyn}Punchbox python dependencies${end}"
	pip freeze
	echo "${cyn}Punchbox shell environment${end}"
	env | grep PUNCH
}

function clean_all() {
#    echo "${PUNCHBOX_BUILD_DIR}"
    rm -rf "${PUNCHBOX_BUILD_DIR}"
}

# PARSE OPTIONS
install_env
source "${DIR}/.venv/bin/activate"
source "${ACTIVATE_SH}"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -h | --help | help)
        usage
        exit 0
        ;;
    -c | --config | config)
        conf_mode=$2
        shift 2
        ;;
    -v | --vagrant | vagrant)
        vagrant_mode=$2
        shift 2
        ;;
    -d | --deploy | deploy)
        deploy_mode=$2
        shift 2
        ;;
    --clean | clean)
        clean_all
        exit 0
        ;;
    --dev | dev)
        development
        exit 0
        ;;
    --env | env)
        environment
        exit 0
        ;;
    *) # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift              # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# PROGRAM
if [ ! -z "${deploy_mode}" ]; then
    configure deploy_mode
    vagrant_mode="start"
    vagrant
    deploy
elif [ ! -z "${conf_mode}" ]; then
    configure
elif [ ! -z "${vagrant_mode}" ]; then
    vagrant
fi

