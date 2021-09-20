*** Settings ***
Documentation    Test streaming from Kafka to ES (no loss)

Metadata         Version    6.3.0-SNAPSHOT
Metadata         https://punchplatform.com
Metadata         Author: Punchplatform Team
Test Timeout     ${TIMEOUT}
Test Setup       Run Keywords
...                    Delete Index       ${CURDIR}/elasticsearch_streaming_index.yaml    AND
...                    Reset Kafka Topic    streaming_validation
Resource         ../../utils/elastic_common.robot
Resource         ../../utils/kafka_common.robot

*** Variables ***
${es_config}         ${CURDIR}/elasticsearch_streaming_index.yaml
${kafka_injector}    ${CURDIR}/kafka_injector.hjson


*** Test Cases ***
Testing First Injection of 10000 documents from Kafka to ES
    [Documentation]     Checks exact document count transferred from a Kafka topic to an ES index
    ...                 with injection before punchline execution
    [Tags]  streaming  kafka  elasticsearch  shiva

    Inject Logs     ${kafka_injector}    logs_count=10000
    Run Punchline   ${CURDIR}/kafka_to_es_10k_stormline.yaml
    Elasticsearch Documents Count Should Equal    10000
    ...                                           config_path=${es_config}


Testing No Loss On Temporary Elasticsearch Unavailability
    [Documentation]     Checks exact document count transferred from a Kafka topic to an ES index,
    ...                 with injection during an Elasticsearch unavailability
    [Tags]  streaming  kafka  elasticsearch  shiva  standalone
    [Timeout]               2 minute
    [Teardown]              Run Keywords
    ...                          Start Standalone Elasticsearch     AND
    ...                          Stop Channel                       streaming_to_es

    Inject Logs      ${kafka_injector}    logs_count=5000
    Start Channel    streaming_to_es
    Elasticsearch Documents Count Should Eventually Equal    5000
    ...                                                      config_path=${es_config}
    Inject Logs      ${kafka_injector}    logs_count=5000
    Sleep            10
    Elasticsearch Documents Count Should Equal               10000
    ...                                                      config_path=${es_config}
    Stop Standalone Elasticsearch
    Inject Logs      ${kafka_injector}    logs_count=5000
    Sleep            10
    Start Standalone Elasticsearch
    Elasticsearch Documents Count Should Eventually Equal    15000
    ...                                                      config_path=${es_config}

