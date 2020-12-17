#! /bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

echo -e "${BLUE}INFO:${RESET} Run archiving check"

echo -e "${BLUE}INFO:${RESET} Start archiving channels"
channelctl -t mytenant start --channel archiving

echo -e "${BLUE}INFO:${RESET} Injecting archiving logs"
{% if storm in punch %}
{% for server in punch.storm.slaves %}
nohup punchplatform-log-injector.sh -c $PUNCHPLATFORM_CONF_DIR/resources/injectors/mytenant/archiving_injector.json -H {{ server }} &
{% endfor %}
{% else %}
{% for server in punch.shiva.servers %}
nohup punchplatform-log-injector.sh -c $PUNCHPLATFORM_CONF_DIR/resources/injectors/mytenant/archiving_injector.json -H {{ server }} &
{% endfor %}
{% endif %}