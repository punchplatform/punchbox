#!/usr/bin/env bash

# CONSTANTS
red=$'\e[1;31m'
grn=$'\e[1;32m'
cyn=$'\e[1;36m'
wht=$'\e[1;37m'
end=$'\e[0m'

# filesystem
SCRIPT_PATH="$(realpath "$0")"
DIR="$(dirname "${SCRIPT_PATH}")"
LOGFILE="/tmp/punchbox.log"
PUNCHBOX_CONF_DIR="${DIR}/configurations"

# installation
ACTIVATE_SH="${DIR}/activate.sh"
ACTIVATE_TEMPLATE="${DIR}/.activate.template"
PUNCHBOX_PY="${DIR}/bin/punchbox.py"
PYTHON_ENV_INSTALLED_MARKER="${DIR}/.python_env_installed"

# VARIABLES
conf_mode=""
vagrant_mode=""
deploy_mode=""

# FUNCTIONS
function usage() {
    printf "Description

    Syntax: punchbox [options]

    options:

    ${grn}help${end}
    Print this.

    ${grn}run${end} [default|tls|<path>]
    If 'default' or 'tls', generate default deployment settings, start vagrant and deploy.
    Else use the provided punchbox config path to generate deployment settings, start vagrant and deploy.

    ${cyn}config${end} [default|tls|<path>]
    If 'default' or 'tls', simply generate default deployment settings and Vagrantfile.
    Else use the provided punchbox config path to simply generate deployment settings and Vagrantfile.

    ${cyn}vagrant${end} [start|stop|clean|reload]
    Execute the provided action on your vagrant boxes.

    ${cyn}deploy${end}
    Deploy the current settings on the running vagrant boxes.

    ${red}clean${end}
    Delete \$PUNCHPLATFORM_CONF_DIR content.
    Do not clean vagrant boxes.

    ${wht}env${end}
    Print the installed python dependencies in punchbox virtualenv and the punchbox shell environment .

    ${wht}dev${end}
    Create symbolic links to \$PUNCH_DIR sources (i.e pp-punch). Set \$PUNCH_DIR first.
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
        echo "Install python environment"
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

# arg 1 : configuration mode ('default' or  'tls') or a path to a punchbox config file
function configure() {
    echo "Log inside ${LOGFILE}"
    punchbox_default_confs_dir="${PUNCH_DEPLOYER}/resources/punchbox"

    # pp-conf
    if [ ! -d "${PUNCHPLATFORM_CONF_DIR}" ]; then
        mkdir -p "${PUNCHPLATFORM_CONF_DIR}"
    fi

    # parse the configuration
    # it may be a supported mode like 'default' or 'tls'
    # else it is a configuration path provided by the user
    if [ "$1" == "default" ]; then
        # default conf
        config_file="${punchbox_default_confs_dir}/default/default_config.json"
    elif [ "$1" == "tls" ]; then
        # default tls conf
        config_file="${punchbox_default_confs_dir}/tls/tls_config.json"
        # security dir with credentials and secrets
        cp -r "${punchbox_default_confs_dir}/tls/security" "${PUNCHPLATFORM_CONF_DIR}"
        echo "${grn}Security resources${end} moved to ${PUNCHPLATFORM_CONF_DIR}/security"
    else
        # the conf_mode (i.e the argument is a path given by the user)
        config_file="$1"
    fi

    # generate deployment settings
    python3 ${PUNCHBOX_PY} --config "${config_file}" >> "${LOGFILE}" 2>&1

    if [ ! $? -eq 0 ]; then
        echo "${red}FAIL: check ${LOGFILE} for error message"
        exit 1
    fi

    echo "${grn}Vagrantfile${end} generated in ${PUNCHBOX_BUILD_DIR}"
    echo "${grn}Deployment settings${end} generated in ${PUNCHPLATFORM_CONF_DIR}"
}

# arg 1 : vagrant mode
function do_vagrant(){
    if [ -f "${PUNCHBOX_BUILD_DIR}/Vagrantfile" ]; then
        cd "${PUNCHBOX_BUILD_DIR}"
        if [ "$1" == "start" ]; then
            vagrant up
        elif [ "$1" == "stop" ]; then
            vagrant halt
        elif [ "$1" == "reload" ]; then
            vagrant reload
        elif [ "$1" == "clean" ]; then
            vagrant destroy -f
        else
            echo "${red}Unsupported vagrant option !${end}"
        fi
    else
        echo "${red}FAIL: Missing Vagrantfile"
        exit 1
    fi

    cd "${DIR}"
}

function deploy() {
    echo "Deploy using ${PUNCH_DEPLOYER}"
    punchplatform-deployer.sh deploy -u vagrant
}

function clean_conf() {
    echo "${red}Delete ${PUNCHPLATFORM_CONF_DIR}"
    rm -rf "${PUNCHPLATFORM_CONF_DIR}"
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

    echo "Created links to pp-punch in ${PUNCH_DEPLOYER}"
}

function environment() {
    echo "${cyn}Punchbox python dependencies${end}"
	pip freeze
	echo "${cyn}Punchbox shell environment${end}"
	env | grep PUNCH
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
    -c | --clean | clean)
        clean_conf
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
        echo "${red}Unknown option:${end} $1 !"
        echo "${wht}punchbox help${end} to read usage."
        exit 1
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# PROGRAM
if [ ! -z "${deploy_mode}" ]; then
    configure ${deploy_mode}
    do_vagrant "start"
    deploy ${deploy_mode}
elif [ ! -z "${conf_mode}" ]; then
    configure "${conf_mode}"
elif [ ! -z "${vagrant_mode}" ]; then
    do_vagrant "${vagrant_mode}"
fi

