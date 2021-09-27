*** Settings ***
Documentation    Integration test for punchlines
...
...              This file regroups common keywords and imports
...              needed to run integration tests
Resource         punch_common.robot


*** Keywords ***
Delete Kafka Topic
    [Documentation]  Ensure the kafka topic does not exist (will succeed even if topic is already deleted)
    [Arguments]  ${topic}  ${cluster}=common

    ${result}=                     Run Command                          kafkactl
    ...                                                                 delete-topic
    ...                                                                 --cluster  ${cluster}
    ...                                                                 --topic  ${topic}
    # We are ignoring return code, because topic may not exist, but anyway we are ensuring success
    # By waiting until the topic is not listed anymore (because deletion is not immediate)
    Wait Until Keyword Succeeds    1 min                                4 sec
    ...                            Check Kafka Topic Does Not Exist     ${topic}
    ...                                                                 ${cluster}


Create Kafka Topic
    [Documentation]  Ensure the kafka topic exists or create it (will leave it unchanged if it already existed)
    [Arguments]  ${topic}  ${cluster}=common  ${partitions}=1  ${replication_factor}=1

    ${result}=               Run Command              kafkactl
    ...                                               create-topics
    ...                                               --topic  ${topic}
    ...                                               --replication-factor  ${replication_factor}
    ...                                               --partition  ${partitions}
    ...                                               --cluster  ${cluster}
    Process Should Exit 0    ${result.rc}

Check Kafka Topic Does Not Exist
    [Documentation]  List kafka topics to check that a topic does not exist anymore
    ...              This is needed because topic deletion is not instantaneous
    [Arguments]  ${topic}  ${cluster}=common
    ${result}=               Run Command              kafkactl
    ...                                               list-topics
    ...                                               --cluster  ${cluster}
    ...                                               |  grep  ': ${topic}\s*$'
    Process Should Exit 1    ${result.rc}


Reset Kafka Topic
    [Documentation]  Ensure the kafka topic exists and is empty (will delete it and recreate it)
    [Arguments]  ${topic}  ${cluster}=common  ${partitions}=1  ${replication_factor}=1

    Delete Kafka Topic        ${topic}  ${cluster}
