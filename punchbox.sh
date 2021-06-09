#!/usr/bin/env bash

# CONSTANTS
red=$'\e[1;31m'
grn=$'\e[1;32m'
cyn=$'\e[1;36m'
wht=$'\e[1;37m'
end=$'\e[0m'

# filesystem
TIME=$(date +%s)
SCRIPT_PATH="$(realpath "$0")"
DIR="$(dirname "${SCRIPT_PATH}")"
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
deploy_component=""
run_mode=""

# FUNCTIONS
function usage() {
    printf "Syntax: punchbox [options]

    Options:

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

    ${cyn}deploy${end} [all|<component>] [--secured]
    If 'all', deploy all punch components with the current settings on the running vagrant boxes.
    Else deploy the provided component with the current settings on the running vagrant boxes.
    If '--secured', also use the deployment secrets file with '-e @\$PUNCHPLATFORM_CONF_DIR/security/deployment_secrets.json'

    ${red}clean${end}
    Delete \$PUNCHPLATFORM_CONF_DIR content.
    Do not clean vagrant boxes.

    ${wht}env${end}
    Print the installed python dependencies in punchbox virtualenv and the punchbox shell environment .

    ${wht}dev${end}
    Create symbolic links to \$PUNCH_DIR sources (i.e pp-punch). Set \$PUNCH_DIR first.


${wht}Examples:${end}
1. All in one - default TLS deployment
punchbox run tls

2. All in one - custom deployment
punchbox run /tmp/my_conf.json

3. Step by step - default configuration
punchbox config default
punchbox vagrant start
punchbox deploy all

4. Step by step - default TLS configuration
punchbox config tls
punchbox vagrant start
punchbox deploy all --secured

5. Step by step - custom configuration
punchbox config /tmp/my_conf.json
punchbox vagrant start
punchbox deploy zookeeper,kafka
    "
}

function do_install() {
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
function do_configure() {
    punchbox_default_confs_dir="${PUNCH_DEPLOYER}/resources/log_central/punchbox"

    # pp-conf
    if [ ! -d "${PUNCHPLATFORM_CONF_DIR}" ]; then
        mkdir -p "${PUNCHPLATFORM_CONF_DIR}"
    fi

    # The configuration may be a default name like 'default', 'tls' or 'modsecurity' packaged inside the deployer dir
    # else it is a configuration path provided by the user
    if [ "$1" == "default" ]; then
        config_file="${punchbox_default_confs_dir}/default/default_config.json"
    elif [ "$1" == "tls" ]; then
        config_file="${punchbox_default_confs_dir}/tls/tls_config.json"
        # security dir with credentials and secrets
        cp -r "${punchbox_default_confs_dir}/tls/security" "${PUNCHPLATFORM_CONF_DIR}"
        echo "${grn}Security resources${end} moved to ${PUNCHPLATFORM_CONF_DIR}/security"
    elif [ "$1" == "modsecurity" ]; then
        config_file="${punchbox_default_confs_dir}/modsecurity/modsecurity_config.json"
    else
        # the conf_mode (i.e the argument is a path given by the user)
        config_file="$1"
    fi

    # generate deployment settings
    python3 ${PUNCHBOX_PY} --config "${config_file}"
    if [ ! $? -eq 0 ]; then exit 1; fi

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
            rm -rf "${PUNCHBOX_BUILD_DIR}/.vagrant" "${PUNCHBOX_BUILD_DIR}/Vagrantfile"
        else
            echo "${red}Unsupported vagrant option !${end}"
        fi
    else
        echo "${red}FAIL: Missing Vagrantfile"
        exit 1
    fi

    cd "${DIR}"
}

# arg1 : 'all', or the punch component name to deploy (eg: kafka)
# arg2 : '--secured' or "" (empty string)
function do_deploy() {
    deployment_secrets_file="${PUNCHPLATFORM_CONF_DIR}/security/deployment_secrets.json"
    if [ "$1" == "all" ] && [ "$2" == "--secured" ]; then
        echo "all secured"
        punchplatform-deployer.sh --deploy -u vagrant -e @${deployment_secrets_file}
    elif [ "$1" != all ] && [ "$2" == "--secured" ]; then
        echo "not all secured"
        punchplatform-deployer.sh --deploy -u vagrant -e @${deployment_secrets_file} -t "$1"
    elif [ "$1" == all ] && [ "$2" != "--secured" ]; then
        echo "all not secured"
        punchplatform-deployer.sh --deploy -u vagrant
    else
        echo "not all not secured"
        punchplatform-deployer.sh --deploy -u vagrant -t "$1"
    fi
}

function do_clean() {
    echo "${red}Delete ${PUNCHPLATFORM_CONF_DIR}"
    rm -rf "${PUNCHPLATFORM_CONF_DIR}"
}

function do_dev_links(){

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

function print_env() {
    echo "${cyn}Punchbox python dependencies${end}"
	pip freeze
	echo "${cyn}Punchbox shell environment${end}"
	env | grep PUNCH
}

# PARSE OPTIONS
do_install
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
    -r | --run | run)
        run_mode=$2
        shift 2
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
        # args may be from 'deploy [all|<component>]' or 'deploy [all|<component>] --secured'
        deploy_component="$2"
        if [ ! -z "$3" ]; then
            deploy_mode="$3"
            shift 3
        else
            shift 2
        fi
        ;;
    -c | --clean | clean)
        do_clean
        exit 0
        ;;
    --dev | dev)
        do_dev_links
        exit 0
        ;;
    --env | env)
        print_env
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
if [ ! -z "${run_mode}" ]; then
    do_configure ${run_mode}
    do_vagrant "start"
    secured_arg="none"
    if [ "${run_mode}" == "tls" ]; then
        secured_arg="--secured"
    fi
    do_deploy "all" "${secured_arg}"
elif [ ! -z "${conf_mode}" ]; then
    do_configure "${conf_mode}"
elif [ ! -z "${vagrant_mode}" ]; then
    do_vagrant "${vagrant_mode}"
elif [ ! -z "${deploy_component}" ]; then
    do_deploy "${deploy_component}" "${deploy_mode}"
fi

