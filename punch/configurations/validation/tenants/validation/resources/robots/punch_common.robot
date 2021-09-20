*** Settings ***
Documentation    Integration test for punchlines
...
...              This file regroups common keywords and imports
...              needed to run integration tests
Library          SeleniumLibrary
Library          OperatingSystem
Library          Process
Library          String
Library          punch_robot.keyword.elasticsearch_assertion.ElasticsearchAssertion
Library          punch_robot.keyword.httprequests.HttpRequests

*** Variables ***
${TENANT_DIR}
${STDOUT_DIR}
${OUTPUT_DIR}
${TENANT_NAME}
${TIMEOUT}        1 minute

*** Keywords ***
Get Test Name
    [Documentation]  Get a snake case test name for log files naming

    ${lower_case_name}=     Convert To Lower Case          ${TEST NAME}
    ${test_name}=           Replace String Using Regexp    ${lower_case_name}
    ...                                                    \\s    _
    [Return]                ${test_name}


Run Command
    [Documentation]  Run command with dedicated stdout and stderr
    [Arguments]  @{args}  ${label}=''
    ${test_name}=     Get Test Name
    ${label}=         Set Variable If        "${label}"=="''"
    ...                                      ${test_name}
    ...                                      ${label}
    ${result}=        Process.Run Process    @{args}
    ...                                      stdout=${STDOUT_DIR}/${label}_out.txt
    ...                                      stderr=${STDOUT_DIR}/${label}_err.txt
    [Return]          ${result}


Process Should Exit
    [Documentation]  Takes as parameter an integer
    ...              The returned code of a given executed process
    ...              Will fail if different from 0
    [Arguments]  ${process_return_code}  ${return_code}

    Should Be Equal As Integers    ${process_return_code}    ${return_code}
    ...                            msg=Process return code (${process_return_code}) does not match expected value(${return_code})


Process Should Exit 0
    [Documentation]  Takes as parameter an integer
    ...              The returned code of a given executed process
    ...              Will fail if different from 0
    [Arguments]  ${process_return_code}

    Should Be Equal As Integers    ${process_return_code}    0
    ...                            msg=Process returned a non-nominal exit code (${process_return_code}) while expecting to return 0


Process Should Exit 1
    [Documentation]  Takes as parameter an integer
    ...              The returned code of a given executed process
    ...              Will fail if different from 1
    [Arguments]  ${process_return_code}

    Should Be Equal As Integers    ${process_return_code}    1
    ...                             msg=Process returned a nominal(0) exit code while expecting to return non-0 code(${process_return_code})

Stop Books
    [Documentation]  Ensure that all books are shutdown on the platform that
    ...              tests will be running.

    ${result}=               Run Command                         bookctl
    ...                                                          stop
    ...                                                          label=books_stop
    Process Should Exit 0    process_return_code=${result.rc}


Run Book
    [Documentation]  Takes same parameter as keyword Run Book with an additional parameter:
    ...              - return_code: int (expected return code by bookctl)
    [Arguments]  ${book}  ${return_code}=0

    ${result}=             Run Command                         bookctl
    ...                                                        --tenant    ${TENANT_NAME}
    ...                                                        start
    ...                                                        --book      ${book}
    Process Should Exit    process_return_code=${result.rc}    return_code=${return_code}


Start Channel
    [Documentation]  starts a validation channel through channelctl
    [Arguments]  ${channel}

    ${result}=             Run Command                         channelctl
    ...                                                        --tenant    ${TENANT_NAME}
    ...                                                        start
    ...                                                        --channel      ${channel}
    Process Should Exit 0   process_return_code=${result.rc}



Stop Channel
    [Documentation]  stops a validation channel through channelctl
    [Arguments]  ${channel}

    ${result}=             Run Command                         channelctl
    ...                                                        --tenant    ${TENANT_NAME}
    ...                                                        stop
    ...                                                        --channel      ${channel}
    Process Should Exit 0   process_return_code=${result.rc}

Run Punchline
    [Documentation]  Run punchlinectl in foreground with a choosen expected return code
    [Arguments]  ${punchline}  ${runtime}=${EMPTY}  ${return_code}=0

    File Should Exist      ${punchline}
    ${runtime_arg}=        Set Variable If                     "${runtime}"=="${EMPTY}"
    ...                                                        ${EMPTY}
    ...                                                        --runtime ${runtime}
    ${result}=             Run Command                         punchlinectl
    ...                                                        --tenant    ${TENANT_NAME}
    ...                                                        start
    ...                                                        --punchline  ${punchline}
    ...                                                        ${runtime_arg}
    Process Should Exit    process_return_code=${result.rc}    return_code=${return_code}


Run Plan
    [Documentation]  Run a plan with it's template in foreground using planctl
    [Arguments]  ${plan}  ${template}  ${runtime}  ${return_code}=0

    File Should Exist      ${template}
    File Should Exist      ${plan}
    ${result}=             Run Command                         planctl
    ...                                                        --tenant    ${TENANT_NAME}
    ...                                                        start    --plan    ${plan}
    ...                                                        --template    ${template}
    ...                                                        --runtime    ${runtime}
    ...                                                        --last-committed
    Process Should Exit    process_return_code=${result.rc}    return_code=${return_code}


Inject Logs
    [Documentation]  Runs a log injector
    [Arguments]              ${injector_}    ${logs_count}=${EMPTY}

    File Should exist        ${injector}
    ${count_arg}=            Set Variable If                   "${logs_count}"=="${EMPTY}"
    ...                                                        ${EMPTY}
    ...                                                        "-n ${logs_count}"
    ${result}=               Run Command     punchplatform-log-injector.sh
    ...                                      -c    ${injector}
    ...                                      ${count_arg}
    Process Should Exit 0    ${result.rc}


Ensure Elasticsearch Is Alive
    [Documentation]  Takes an elasticsearch.yaml configuration as parameter and an expected bool result:
    ...              is_alive: bool (whether you expect elastic is alive or not)
    ...              elastic_config_path: str (absolute path to your yaml file)
    [Arguments]  ${is_alive}=True  &{elastic_config_path}

    ${result}=        Elasticsearch Is Alive      &{elastic_config_path}
    Should Be True    ${result} == ${is_alive}


Number Of Documents Should Be GorE
    [Documentation]  From a given elasticsearch index, states that the total number of document
    ...              retrieves should be greater or equal to a number, parameter:
    ...                - num_of_doc: int (number to compare to)
    ...                - config_path: str (absolute path to your elasticsearch.yaml)
    [Arguments]  ${num_of_doc}  ${config_path}

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


Delete Filesystem Folder
    [Documentation]  Erase filesystem folder used to store archives
    [Arguments]  ${folder}
    ${result}=             Run Command                         rm
    ...                                                        -rf
    ...                                                        ${folder}
    Process Should Exit 0    ${result.rc}


Delete Kafka Topic
    [Documentation]  Ensure the kafka topic does not exist (will succeed even if topic is already deleted)
    [Arguments]  ${topic}  ${cluster}=common

    ${result}=                     Run Command                          punchplatform-kafka-topics.sh
    ...                                                                 --kafkaCluster  ${cluster}
    ...                                                                 --delete
    ...                                                                 --topic ${topic}
    # We are ignoring return code, because topic may not exist, but anyway we are ensuring success
    # By waiting until the topic is not listed anymore (because deletion is not immediate)
    Wait Until Keyword Succeeds    1 min                                4 sec
    ...                            Check Kafka Topic Does Not Exist    ${topic}
    ...                                                                 ${cluster}


Create Kafka Topic
    [Documentation]  Ensure the kafka topic exists or create it (will leave it unchanged if it already existed)
    [Arguments]  ${topic}  ${cluster}=common  ${partitions}=1  ${replication_factor}=1

    ${result}=               Run Command              kafkactl
    ...                                               create-topics
    ...                                               --topic  ${topic}
    ...                                               --replication-factor ${replication_factor}
    ...                                               --partition ${partitions}
    ...                                               --cluster ${cluster}
    Process Should Exit 0    ${result.rc}

Check Kafka Topic Does Not Exist
    [Documentation]  List kafka topics to check that a topic does not exist anymore
    ...              This is needed because topic deletion is not instantaneous
    [Arguments]  ${topic}  ${cluster}=common
    ${result}=               Run Command              bash  -c
    ...                                               kafkactl list-topics --cluster ${cluster} | grep -q ': ${topic}\s*$'
    Process Should Exit 1    ${result.rc}


Reset Kafka Topic
    [Documentation]  Ensure the kafka topic exists and is empty (will delete it and recreate it)
    [Arguments]  ${topic}  ${cluster}=common  ${partitions}=1  ${replication_factor}=1

    Delete Kafka Topic        ${topic}  ${cluster}
    Create Kafka Topic        ${topic}  ${cluster} ${partitions} ${replication_factor}

Stop Standalone Elasticsearch
    Run Command                         punchplatform-elasticsearch.sh     --stop

Start Standalone Elasticsearch
    Run Command                         punchplatform-elasticsearch.sh      --start
    Wait Until Keyword Succeeds         1 min                               3s
    ...                                 Http Endpoint Available             localhost:9200

Http Endpoint Available
    [Documentation]  Checks that some answer can be retrieved from a remote HTTP server
    ...               (as opposed to a communication rejection or non-HTTP endpoint)
    [Arguments]  ${endpoint}

    ${result}=                  Run Command                  curl     ${endpoint}
    Process Should Exit 0       ${result.rc}



Archive should contain documents
    [Arguments]  ${expected_count}

    Should Be Equal As Integers    ${process_return_code}    ${return_code}


