*** Settings ***
Documentation    Test an extraction books running simple shiva and storm archiving and
...              extraction punchline
Metadata         Version    6.3.0-SNAPSHOT
Metadata         https://punchplatform.com
Metadata         Author: Punchplatform Team
Test Setup       Run Keywords
...                  Stop Books                                                                 AND
...                  Clean Archives Resources    validation_extraction
...                                              ${archive_folder}
...                                              ${CURDIR}/elasticsearch_metadata_config.yaml   AND
...                  Inject Logs                 ${CURDIR}/extraction_injector.hjson
Test Teardown    Run Keywords
...                  Stop Books                                                                 AND
...                  Clean Archives Resources    validation_extraction
...                                              ${archive_folder}
...                                              ${CURDIR}/elasticsearch_metadata_config.yaml
Test Timeout     2 minute
Resource         ../utils/archive_common.robot

*** Variables ***
${archive_folder}    /tmp/extraction/storage

*** Test Cases ***
Shiva Extraction With Exit Code 0
    [Documentation]  Test with a valid extraction punchline configuration using
    ...              the runtime shiva with returned exit code is 0
    [Tags]  book  shiva
    Run Book    extraction_shiva    return_code=0


Storm Extraction With Exit Code 0
    [Documentation]  Test with a valid extraction punchline configuration using
    ...              the runtime storm with returned exit code is 0
    [Tags]  book  storm
    Run Book    extraction_storm    return_code=0
