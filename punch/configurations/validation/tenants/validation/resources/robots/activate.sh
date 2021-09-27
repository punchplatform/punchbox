#!/usr/bin/env bash

source "$PUNCHPLATFORM_OPERATOR_INSTALL_DIR/bin/commons-lib.sh"

cat << "EOF"                                                                         
 _____             _      _____     _       _      _____         _       
|  _  |_ _ ___ ___| |_   | __  |___| |_ ___| |_   |_   _|___ ___| |_ ___ 
|   __| | |   |  _|   |  |    -| . | . | . |  _|    | | | -_|_ -|  _|_ -|
|__|  |___|_|_|___|_|_|  |__|__|___|___|___|_|      |_| |___|___|_| |___|

EOF

green   "Make sure you have all punchplatform ENV defined before sourcing this shell"
info    ""
info    "Will execute all tests:"
info    ""
yellow  "    punch-robot-test \$PUNCHPLATFORM_CONF_DIR/tenants/validation/resources/robots"
info    ""
info    "If your current directory contains robot tests (.robot) files"
info    ""
yellow  "    punch-robot-test ."
info    ""
info    "Available commands:"
green   "punch-robot-test-console will output additional information on stdout"
green   "punch-robot-test-kafka will output additional information to a kafka topic"
green   "punch-robot-test-elastic will output additional information to a elastic index"
info    ""
info    "View Punch Custom Keyword documentation or list them:"
yellow  "punch-robot-doc-lib \$KEYWORD_ELASTICSEARCH_ASSERTION list"
info    "or"
yellow  "punch-robot-doc-lib \$KEYWORD_ELASTICSEARCH_ASSERTION show"
info    "View High-level robot configuration file documentation in html"
yellow  "punch-robot-doc-conf . /tmp/test.html"

PUNCHPLATFORM_TENANT="validation"
ROBOT_TENANT_DIR="$PUNCHPLATFORM_CONF_DIR/tenants/$PUNCHPLATFORM_TENANT"
ROBOT_OUTPUT_DIR="$ROBOT_TENANT_DIR/robot_output"
ROBOT_STDOUT_DIR="$ROBOT_TENANT_DIR/robot_stdout"
ROBOT_SINK_KAKFA_CONFIG="$ROBOT_TENANT_DIR/resources/robots/kafka_config.yaml"
ROBOT_SINK_ES_CONFIG="$ROBOT_TENANT_DIR/resources/robots/elasticsearch_config.yaml"


ROBOT_OUTPUT_DIR_PARAM="--outputdir $ROBOT_OUTPUT_DIR"

ROBOT_VARS_PARAM=(
    "-v OUTPUT_DIR:$ROBOT_OUTPUT_DIR"
    "-v STDOUT_DIR:$ROBOT_STDOUT_DIR"
    "-v TENANT_DIR:$ROBOT_TENANT_DIR"
    "-v TENANT_NAME:$PUNCHPLATFORM_TENANT"
)

LOG_LEVEL="DEBUG"
CMD_PREFIX="PEX_ROOT=$PUNCHPLATFORM_PEX_CACHE_DIR punch-robot --loglevel $LOG_LEVEL --consolewidth ${COLUMNS:-80}"
CMD_SUFFIX="$ROBOT_OUTPUT_DIR_PARAM ${ROBOT_VARS_PARAM[@]}"
CMD="$CMD_PREFIX $CMD_SUFFIX"
CMD_CONSOLE="$CMD_PREFIX  --listener punch_robot.listener.punch_listener.PunchListener  $CMD_SUFFIX"
CMD_KAFKA="$CMD_PREFIX  --listener punch_robot.listener.punch_listener.PunchListener:$ROBOT_SINK_KAKFA_CONFIG  $CMD_SUFFIX"
CMD_ELASTIC="$CMD_PREFIX  --listener punch_robot.listener.punch_listener.PunchListener:$ROBOT_SINK_ES_CONFIG  $CMD_SUFFIX"
CMD_GENERATE_DOC_CONF="PEX_ROOT=$PUNCHPLATFORM_PEX_CACHE_DIR PEX_INTERPRETER=1 punch-robot -m robot.testdoc"
CMD_GENERATE_DOC_LIB="PEX_ROOT=$PUNCHPLATFORM_PEX_CACHE_DIR PEX_INTERPRETER=1 punch-robot -m robot.libdoc"

# Robot expect an already created directory
mkdir -p $ROBOT_OUTPUT_DIR $ROBOT_STDOUT_DIR

# Available Custom Keywords
KEYWORD_ELASTICSEARCH_ASSERTION="punch_robot.keyword.elasticsearch_assertion.ElasticsearchAssertion"

alias punch-robot-test="$CMD"
alias punch-robot-test-console="$CMD_CONSOLE"
alias punch-robot-test-kafka="$CMD_KAFKA"
alias punch-robot-test-elastic="$CMD_ELASTIC"
alias punch-robot-doc-conf="$CMD_GENERATE_DOC_CONF"
alias punch-robot-doc-lib="$CMD_GENERATE_DOC_LIB"