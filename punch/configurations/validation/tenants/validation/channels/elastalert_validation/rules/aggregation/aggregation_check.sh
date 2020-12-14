#! /bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

echo -e "${BLUE}INFO:${RESET} Run aggregation check"

echo -e "${BLUE}INFO:${RESET} Start aggregation and stormshield channels"
channelctl -t mytenant start --channel stormshield_networksecurity
channelctl -t mytenant start --channel aggregation

echo -e "${BLUE}INFO:${RESET} Injecting stormshield logs"
{% for server in punch.shiva.servers %}
nohup punchplatform-log-injector.sh -c $PUNCHPLATFORM_CONF_DIR/resources/injectors/mytenant/stormshield_networksecurity_injector.json -H {{ server }} &
{% endfor %}