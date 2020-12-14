#! /bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

echo -e "${BLUE}INFO:${RESET} Run exit 0 python check"

echo -e "${BLUE}INFO:${RESET} Start spark success channels"
channelctl -t validation start --channel spark_client_success