*** Settings ***
Documentation    Test Gateway endpoints
Metadata         Version    6.3.1-SNAPSHOT
Metadata         https://punchplatform.com
Metadata         Author: Punchplatform Team
Library          Collections
Library          punch_robot.keyword.httprequests.HttpRequests
Suite Setup      Create Punch Http Session    gateway    common
Test Timeout     ${TIMEOUT}
Resource         ../utils/punch_common.robot

*** Variables ***
&{json_header}        Content-Type=application/json
${extraction_path}    ${CURDIR}/request_body/extraction_v2_request.json
${resources}          ${CURDIR}/resources

*** Keywords ***
Get From Gateway
    [Documentation]  HTTP GET on gateway session
    [Arguments]  ${url}  ${expected_status}=200

    ${response}=    GET On Session    gateway    ${url}
    ...                               expected_status=${expected_status}
    [Return]        ${response}


Post To Gateway
    [Documentation]  HTTP POST on gateway session
    [Arguments]  ${url}  ${expected_status}=200  &{config}

    ${response}=    POST On Session    gateway    ${url}
    ...                                expected_status=${expected_status}
    ...                                &{config}
    [Return]        ${response}


Delete From Gateway
    [Documentation]  HTTP DELETE on gateway session
    [Arguments]  ${url}  ${expected_status}=200

    ${response}=    DELETE On Session    gateway    ${url}
    ...                                  expected_status=${expected_status}
    [Return]        ${response}


Put To Gateway
    [Documentation]  HTTP PUT on gateway session
    [Arguments]  ${url}  ${expected_status}=200  &{config}

    ${response}=    PUT On Session    gateway    ${url}
    ...                               expected_status=${expected_status}
    ...                               &{config}
    [Return]        ${response}

*** Test Cases ***
Forwarding to ES
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  elasticsearch

    Get From Gateway    /v1/mytenant/es/common/_cat/indices


Extraction using storm runtime endpoint
    [Documentation]  Extract a fixed number of documents from elasticsearch
    [Tags]  gateway  elasticsearch  storm

    ${data} =          Get File                         path=${extraction_path}
    Post To Gateway    /v1/mytenant/extraction/spark    data=${data}
    ...                headers=&{json_header}


Grok execution through Gateway
    [Documentation]  Test
    [Tags]  gateway  grok

    ${grok_input}=      Get Binary File      ${resources}/grok/input
    ${grok_pattern}=    Get Binary File      ${resources}/grok/pattern
    &{data}=            Create Dictionary    input=${grok_input}
    ...                                      pattern=${grok_pattern}
    Post To Gateway     v1/puncher/grok      files=${data}


Dissect execution through Gateway
    [Documentation]  Test
    [Tags]  gateway  dissect

    ${dissect_input}=      Get Binary File        ${resources}/dissect/input
    ${dissect_pattern}=    Get Binary File        ${resources}/dissect/pattern
    ${data}=               Create Dictionary      input=${dissect_input}
    ...                                           pattern=${dissect_pattern}
    Post To Gateway        v1/puncher/dissect     files=${data}


Punchlet execution through Gateway
    [Documentation]  Test
    [Tags]  gateway  punchlet

    ${punchlet_input}=    Get Binary File         ${resources}/punchlet/input
    ${punchlet_log}=      Get Binary File         ${resources}/punchlet/punchlet
    &{data}=              Create Dictionary       input=${punchlet_input}
    ...                                           logFile=${punchlet_log}
    Post To Gateway       /v1/puncher/punchlet    files=&{data}


Nodes scan
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  storm  spark

    Get From Gateway    /v1/mytenant/punchline/scan/analytics


Save punchline in resource manager
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  punchline  resource_manager

    ${punchline}=         Get Binary File      ${resources}/dataset_generator.pml
    &{data}=              Create Dictionary    file=${punchline}
    ${response}=          Post To Gateway      /v1/mytenant/punchline/save
    ...                                        files=&{data}
    ...                                        expected_status=201
    Set Suite Variable    ${punchline_id}      ${response.json()['id']}


Download punchline
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  punchline  resource_manager

    ${response}=                     Get From Gateway    /v1/mytenant/punchline/${punchline_id}
    ${response_json}=                Set Variable        ${response.json()}
    Dictionary Should Contain Key    ${response_json}    tenant
    Dictionary Should Contain Key    ${response_json}    version
    Dictionary Should Contain Key    ${response_json}    dag


List all punchlines uploaded
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  punchline  resource_manager

    ${response}=      Get From Gateway    /v1/mytenant/punchline
    ${list_size}=     Get Length          ${response.json()}
    Should Be True    ${list_size > 0}


Execute punchline
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  punchline  resource_manager

    ${response}=                     Post To Gateway              /v1/mytenant/punchline/${punchline_id}
    ${response_json}=                Set Variable                 ${response.json()}
    Dictionary Should Contain Key    ${response_json}             id
    Set Suite Variable               ${punchline_execution_id}    ${response_json['id']}
    Sleep                            10s


List punchline executions for a given tenant
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  punchline  resource_manager

    ${response}=      Get From Gateway    /v1/mytenant/punchline/executions
    ${list_size}=     Get Length          ${response.json()}
    Should Be True    ${list_size > 0}


List executions for a given punchline
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  punchline  resource_manager

    ${response} =          Get From Gateway                /v1/mytenant/punchline/executions/${punchline_id}
    Should Be Equal        ${response.json()[0]["id"]}     ${punchline_execution_id}


Get punchline execution events for a given punchline
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  punchline  resource_manager

    ${response} =     Get From Gateway      /v1/mytenant/punchline/executions/${punchline_execution_id}/events
    ${list_size} =    Get Length            ${response.json()}
    Should Be True    ${list_size > 0}


Get punchline execution output for a given punchline
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  punchline  resource_manager

    Get From Gateway    /v1/mytenant/punchline/executions/${punchline_execution_id}/output


Delete uploaded punchline
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  punchline  resource_manager

    Delete From Gateway    /v1/mytenant/punchline/${punchline_id}
    Get From Gateway       /v1/mytenant/punchline/${punchline_id}    expected_status=404


Generate and save extraction punchline in resource manager
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  punchline  resource_manager        extraction

    ${extraction_body}=    Get Binary File    ${resources}/extraction_body.json
    ${response} =          Post To Gateway    /v1/mytenant/extraction
    ...                                       data=${extraction_body}
    ...                                       headers=&{json_header}
    Get From Gateway       /v1/mytenant/punchline/${response.json()['id']}


Upload resources
    [Documentation]  Check if Elasticsearch responds through the Gateway
    [Tags]  gateway  resource_manager

    ${resource}=      Get Binary File                       ${resources}/resource.txt
    &{data}=          Create Dictionary                     input=${resource}
    Put To Gateway    /v1/mytenant/resources/upload/test    files=&{data}
    ...                                                     expected_status=201
