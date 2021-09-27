*** Settings ***
Documentation    Integration test for punchlines
...
...              This file regroups common keywords and imports
...              needed to run integration tests
Resource         punch_common.robot
Library          punch_robot.keyword.elasticsearch_assertion.ElasticsearchAssertion

*** Keywords ***
Stop Standalone Elasticsearch
    Run Command                         punchplatform-elasticsearch.sh     --stop


Start Standalone Elasticsearch
    Run Command                         punchplatform-elasticsearch.sh      --start
    Wait Until Keyword Succeeds         1 min                               3s
    ...                                 Http Endpoint Available             localhost:9200


Ensure Elasticsearch Is Alive
    [Documentation]  Takes an elasticsearch.yaml configuration as parameter and an expected bool result:
    ...              is_alive: bool (whether you expect elastic is alive or not)
    ...              elastic_config_path: str (absolute path to your yaml file)
    [Arguments]  ${elastic_config_path}  ${is_alive}=True

    ${result}=        Elasticsearch Is Alive      ${elastic_config_path}
    Should Be True    ${result} == ${is_alive}


Number Of Documents Should Be GorE
    [Documentation]  From a given elasticsearch index, states that the total number of document
    ...              retrieves should be greater or equal to a number, parameter:
    ...                - num_of_doc: int (number to compare to)
    ...                - config_path: str (absolute path to your elasticsearch.yaml)
    [Arguments]  ${config_path}  ${num_of_doc}

    ${result}=        Number Of Documents In Index    config_path=${config_path}
    Should Be True    ${result} >= ${num_of_doc}


Elasticsearch Documents Count Should Equal
    [Documentation]  Check exact document count in given ES index
    [Arguments]  ${num_of_doc}  ${config_path}

    ${actual_doc_count}=           Number Of Documents In Index    config_path=${config_path}
    Should Be Equal As Integers    ${actual_doc_count}             ${num_of_doc}


Elasticsearch Documents Count Should Eventually Equal
    [Documentation]  Check exact document count in given ES index, but waits an retry if not exact
    [Arguments]  ${num_of_doc}  ${config_path}

    Wait Until Keyword Succeeds         1 min                                          3s
    ...                                 Elasticsearch Documents Count Should Equal     ${num_of_doc}
    ...                                 config_path=${config_path}


Timestamp Field Is Advancing
    [Documentation]  From a given elasticsearch index, select a valid iso timestamp field
    ...              and check whether it is increasing in time or not.
    [Arguments]  ${config_path}  ${field_name}  ${is_advancing}=True

    ${result}=        Is Timestamp Advancing          config_path=${config_path}
    ...                                               field_name=${field_name}
    Should Be True    ${result} == ${is_advancing}


Has Document In Timerange
    [Documentation]  From a given elasticsearch index, check if a document
    ...              has been pushed in last scroll timerange.
    [Arguments]  ${config_path}  ${expected}

    ${result}=        Number Of Document In Timerange    config_path=${config_path}
    Should Be True    ${result} == ${expected}


Http Endpoint Available
    [Documentation]  Checks that some answer can be retrieved from a remote HTTP server
    ...               (as opposed to a communication rejection or non-HTTP endpoint)
    [Arguments]  ${endpoint}

    ${result}=                  Run Command                  curl  ${endpoint}
    Process Should Exit 0       ${result.rc}
