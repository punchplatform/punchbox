*** Settings ***
Documentation    Test archiving and extraction through storm punchlines

Metadata         Version    6.3.0-SNAPSHOT
Metadata         https://punchplatform.com
Metadata         Author: Punchplatform Team
Test Setup       Run Keywords
...                 Clean Archives Resources  validation_archiving
...                                           ${archive_folder}
...                                           ${CURDIR}/elasticsearch_metadata_config.yaml    AND
...                 Inject Logs  ${CURDIR}/archiving_injector.hjson
Test Teardown    Clean Archives Resources  validation_archiving
...                                        ${archive_folder}
...                                        ${CURDIR}/elasticsearch_metadata_config.yaml
Test Timeout     ${TIMEOUT}
Resource         ../utils/archive_common.robot

*** Variables ***
${archive_folder}    /tmp/archiving/storage

*** Test Cases ***
Light engine Archiving With Exit Code 0
    [Documentation]  Test with a valid archiving punchline configuration
    ...              with returned exit code is 0 (exit condition: > 1000 tuple successes, 0 failure)
    [Tags]  punchlinectl  shiva

    Run Punchline                       ${CURDIR}/archiving.yaml
    Archive Should Contain Documents    1000                        ${archive_folder}


Storm Archiving With Exit Code 0
    [Documentation]  Test with a valid archiving punchline configuration using
    ...              the runtime storm with returned exit code is 0
    [Tags]  book  storm

    Stop Books
    Run Book                            archiving_storm
    Archive Should Contain Documents    1000               ${archive_folder}
    Stop Books
