*** Settings ***
Documentation    Integration test for archiving
...
...              This file regroups common keywords and imports
...              needed to run archiving tests
Resource         punch_common.robot
Resource         kafka_common.robot
Resource         elastic_common.robot


*** Keywords ***
Delete Filesystem Folder
    [Documentation]  Erase filesystem folder used to store archives
    [Arguments]  ${folder}
    ${result}=             Run Command                         rm
    ...                                                        -rf
    ...                                                        ${folder}
    Process Should Exit 0    ${result.rc}


Clean Archives Resources
    [Documentation]  Reset filesystem, kafka topic and elasticsearch index from archiving punchline
    [Arguments]  ${topic}  ${directory}  ${index}

    Reset Kafka Topic           ${topic}
    Delete Filesystem Folder    ${directory}
    Delete Index                ${index}


Archive Should Contain Documents
    [Documentation]  This applies zcat to all the .gz files in archives,
    ...              and checks the lines count against the expected number
    [Arguments]  ${expected_lines_count}  ${base_folder}  ${file_pattern}=*.gz

    ${result}=                     Run Command                find  ${base_folder}
    ...                                                       -name  ${file_pattern}  2>/dev/null
    ...                                                       |  xargs  zcat  |  wc  -l
    Process Should Exit 0          ${result.rc}
    Should Be Equal As Integers    ${expected_lines_count}    ${result.stdout}