*** Settings ***
Documentation    Test Elasticsearch and Archiving housekeeping
Metadata         Version    6.3.3-SNAPSHOT
Metadata         https://punchplatform.com
Metadata         Author: Punchplatform Team
Test Timeout     ${TIMEOUT}
Resource         ../utils/archive_common.robot

*** Variables ***
${archive_topic}     validation_archive_housekeeping
${archive_folder}    /tmp/archive_housekeeping/storage
${index_config}      ${CURDIR}/elasticsearch_metadata_config.yaml

*** Keywords ***
Create Archives
    [Documentation]  Create archives for housekeeping test
    Clean Archives Resources            ${archive_topic}
    ...                                 ${archive_folder}
    ...                                 ${index_config}
    Inject Logs                         ${CURDIR}/old_archive_injector.json
    Inject Logs                         ${CURDIR}/new_archive_injector.json
    Run Punchline                       ${CURDIR}/archiving.yaml
    Archive Should Contain Documents              20    ${archive_folder}
    Elasticsearch Documents Count Should Equal    2     ${index_config}


*** Test Cases ***
Archives Housekeeping
    [Documentation]  Execute archives-housekeeping and check that old document are deleted
    [Tags]  housekeeping  archiving
    [Setup]  Create Archives
    [Teardown]  Clean Archives Resources    ${archive_topic}    ${archive_folder}    ${index_config}

    ${result}=                                    Run Command      archives-housekeeping
    ...                                                            ${CURDIR}/archives-housekeeping.hjson
    Process Should Exit 0                         ${result.rc}
    Archive Should Contain Documents              20               ${archive_folder}
    Elasticsearch Documents Count Should Equal    2                ${index_config}