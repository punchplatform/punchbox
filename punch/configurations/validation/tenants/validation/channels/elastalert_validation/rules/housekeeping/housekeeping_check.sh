#! /bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

echo -e "${BLUE}INFO:${RESET} Run housekeeping check"

echo -e "${BLUE}INFO:${RESET} Start housekeeping channels"
channelctl -t mytenant start --channel housekeeping
channelctl -t platform start --channel housekeeping