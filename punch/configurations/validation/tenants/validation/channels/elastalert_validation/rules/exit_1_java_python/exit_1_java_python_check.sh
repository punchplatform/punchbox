#! /bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

echo -e "${BLUE}INFO:${RESET} Run exit 1 java python check"

echo -e "${BLUE}INFO:${RESET} Start spark failure channels"
channelctl -t validation start --channel spark_client_fail