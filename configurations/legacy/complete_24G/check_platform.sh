#! /bin/bash

PROG=$(basename $0)
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

RULES_DIR="$PUNCHPLATFORM_CONF_DIR/tenants/validation/channels/elastalert_validation/rules/"

######### USAGE ######################
function usage() {
    echo "Usage: $PROG <command>"
    echo ""
    echo "  -h, --help                          Print this help menu."
    echo "  -f, --full                          Launch all the elastalert rules."
    echo "  -r, --rule <rule>                   Launch the given rule with elastalert in foreground. Rules can be found"
    echo "                                      in the elastalert_validation channel in validation tenant"
    echo
    echo "Examples:"
    echo
    echo "  $ $PROG --full"
    echo "  $ $PROG -f"
    echo "  $ $PROG --rule aggregation"
    echo "  $ $PROG -r aggregation"
    echo
}


function init() {
    echo -e "${BLUE}INFO:${RESET} Push Elasticsearch templates"

    punchplatform-push-es-templates.sh --directory $PUNCHPLATFORM_CONF_DIR/resources/elasticsearch/templates/ \
        --url server2:9200 

    echo -e "${BLUE}INFO:${RESET} Push Kibana dashboards"

    punchplatform-setup-kibana.sh --import --url server1:5601 

    echo -e "${BLUE}INFO:${RESET} Start monitoring channels"
    channelctl -t mytenant start --channel monitoring
    channelctl -t platform start --channel monitoring
}

function startRule() {
    $RULES_DIR/$1/$1_check.sh || exit 1
    ./punchplatform-elastalert.sh --start-foreground --config $RULES_DIR/../config.yaml --rule $RULES_DIR/$1/$1_success.yaml
}

function startFullTest() {
    echo -e "${BLUE}INFO:${RESET} Start checks"
    
    $RULES_DIR/exit_1_java_python/exit_1_java_python_check.sh
    
    $RULES_DIR/exit_0_java_python/exit_0_java_python_check.sh
    
    $RULES_DIR/housekeeping/housekeeping_check.sh
    
    $RULES_DIR/aggregation/aggregation_check.sh
    
    $RULES_DIR/exit_1_python/exit_1_python_check.sh
    
    $RULES_DIR/gateway/gateway_check.sh
    
    $RULES_DIR/exit_1_java/exit_1_java_check.sh
    
    $RULES_DIR/exit_0_python/exit_0_python_check.sh
    
    $RULES_DIR/exit_0_java/exit_0_java_check.sh
    
    $RULES_DIR/archiving/archiving_check.sh
    
    echo -e "${BLUE}INFO:${RESET} Start channels elastalert validation"
    channelctl -t validation start --channel elastalert_validation
}

function close() {
    echo -e "${BLUE}INFO:${RESET} Wait for 15 min, logs are being inserted in platform"
    sleep 900
    pkill -f org.thales.punch.injector.Main >/dev/null 2>/dev/null

    echo -e "${BLUE}INFO:${RESET} Stop channels"
    channelctl -t mytenant stop
    channelctl -t validation stop

    echo -e "${BLUE}INFO:${RESET} End of check platform"
    exit 0
}

if [ $# -eq 0 ]; then
    usage
    exit 0
fi

case $1 in
    -h | --help)
        usage
        exit 0
        ;;

    -f | --full)
        init
        startFullTest
        close
        ;;

    -r | --rule)
        startRule "$2"
        ;;

    *)
        usage
        fatal "Unknown command '$1'."
        ;;
esac

exit