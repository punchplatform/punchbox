*** Settings ***
Documentation    Test that services are alive with green status using platformctl
Metadata         Version    6.3.0-SNAPSHOT
Metadata         https://punchplatform.com
Metadata         Author: Punchplatform Team
Test Timeout     ${TIMEOUT}
Resource         ../utils/punch_common.robot

*** Keywords ***
Service Should Have Green Status
    [Documentation]  Run platformctl on a service and check health code
    [Arguments]  ${service}
    ${result} =       Run Command         platformctl    health
    ...                                   --service    ${service}
    ...                                   --verbose
    ...                                   label=platformctl
    Should Contain    ${result.stdout}    "health_code": 1

*** Test Cases ***
Clickhouse Should Have Green Status
    [Documentation]  Run platformctl on clickhouse and check health code
    [Tags]  clickhouse
    Service Should Have Green Status    clickhouse


Elasticsearch Should Have Green Status
    [Documentation]  Run platformctl on elasticsearch and check health code
    [Tags]  elasticsearch
    Service Should Have Green Status    elasticsearch


Gateway Should Have Green Status
    [Documentation]  Run platformctl on gateway and check health code
    [Tags]  gateway
    Service Should Have Green Status    gateway


Kafka Should Have Green Status
    [Documentation]  Run platformctl on kafka and check health code
    [Tags]  kafka
    Service Should Have Green Status    kafka


Minio Should Have Green Status
    [Documentation]  Run platformctl on minio and check health code
    [Tags]  minio
    Service Should Have Green Status    minio


Shiva Should Have Green Status
    [Documentation]  Run platformctl on shiva and check health code
    [Tags]  shiva
    Service Should Have Green Status    shiva


Spark Should Have Green Status
    [Documentation]  Run platformctl on spark and check health code
    [Tags]  spark
    Service Should Have Green Status    spark


Storm Should Have Green Status
    [Documentation]  Run platformctl on storm and check health code
    [Tags]  storm
    Service Should Have Green Status    storm


Zookeeper Should Have Green Status
    [Documentation]  Run platformctl on zookeeper and check health code
    [Tags]  zookeeper
    Service Should Have Green Status    zookeeper
