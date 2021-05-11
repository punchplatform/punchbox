# SECURITY DEPLOYMENT

## Overview

This configuration deploy a secured punch on 4 hosts of 6096 RAM usage each :

* central-front-1
* central-front-2
* central-back-1
* central-back-2

The deployed components are:

* Operators: punch-operator and guest-operator
    * central-front-1
* Zookeeper: cluster `zk_central`
    * central-front-1
    * central-front-2
    * central-back-1
    * central-back-2
* Kafka:
    * cluster `kafka_front`:
        * central-front-1
        * central-front-2
    * cluster `kafka_back`:
        * central-back-1
        * central-back-2
* Elasticsearch:
    * cluster `es_data`:
        * central-front-1
        * central-front-2
        * central-back-1
    * cluster `es_metric`:
        * central-back-2
* Gateway: cluster `gateway_central`
    * central-back-2 : tenant `onesky`
* Kibana: 
    * central-front-1:
        * domain `data-admin`: to ES cluster `es_data`
        * domain `metric-admin`: to ES cluster `es_metric`
        * domain `onesky-admin`: to Gateway cluster `gateway_central`
* Shiva: cluster `shiva_central`:
    * central-back-1: tag `shiva_external`
    * central-back-2: tag `shiva_internal`
* Metricbeat: to ES cluster `es_metric`
    * central-front-1
    * central-front-2
    * central-back-1
    * central-back-2

2-ways TLS encryption is enabled on :

* Zookeeper/Kafka clusters
* Elasticsearch clusters
* Gateway

TLS encryption is enabled on Kibana to the ES clusters but the clients do not need public keys.

## Requirements

You **MUST** have a punch deployer available on your host.

Test it :

```sh
punchplatform-deployer.sh -h 
```

## Vagrant

```sh
cd $PUNCHBOX_DIR/configurations/security_16g
vagrant up
```

## Deploy

```sh
export PUNCHPLATFORM_CONF_DIR=`pwd`
punchpltform-deployer.sh deploy -e @$PUNCHPLATFORM_CONF_DIR/security/deployment_secrets.json -u vagrant
```

