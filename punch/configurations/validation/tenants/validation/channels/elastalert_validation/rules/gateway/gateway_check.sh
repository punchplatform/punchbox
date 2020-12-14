#! /bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

echo -e "${BLUE}INFO:${RESET} Run gateway check"

{%- if os == "ubuntu/bionic64" %}
curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >> /dev/null 2>&1
sudo apt-get install -y nodejs >> /dev/null 2>&1
{% elif os == "centos/7" %}
curl -sL https://rpm.nodesource.com/setup_lts.x | sudo bash - >> /dev/null 2>&1
sudo yum install -y nodejs >> /dev/null 2>&1
{% endif %}
sudo npm install -g newman newman-reporter-json-udp >> /dev/null 2>&1

UDP_IP=$(ping {{ punch.shiva.servers[0] }} -c 1 -q 2>&1 | grep -Po "(\d{1,3}\.){3}\d{1,3}")
newman run $PUNCHPLATFORM_CONF_DIR/tenants/validation/channels/gateway_validation/postman/collection.json \
-e $PUNCHPLATFORM_CONF_DIR/tenants/validation/channels/gateway_validation/postman/env.json \
--working-dir $PUNCHPLATFORM_CONF_DIR/tenants/validation/channels/gateway_validation/postman \
-r json-udp --reporter-json-udp-ip $UDP_IP --reporter-json-udp-port 9999 >> /dev/null 2>&1