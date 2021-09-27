*** Settings ***
Documentation    Integration test for punchlines
...
...              This file regroups common keywords and imports
...              needed to run integration tests
Library          OperatingSystem
Library          Process
Library          String

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
    ${result}=        Run Process            @{args}
    ...                                      shell=True
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
    ...                                                        --tenant  ${TENANT_NAME}
    ...                                                        start
    ...                                                        --book  ${book}
    Process Should Exit    process_return_code=${result.rc}    return_code=${return_code}


Start Channel
    [Documentation]  starts a validation channel through channelctl
    [Arguments]  ${channel}

    ${result}=             Run Command                         channelctl
    ...                                                        --tenant  ${TENANT_NAME}
    ...                                                        start
    ...                                                        --channel  ${channel}
    Process Should Exit 0   process_return_code=${result.rc}



Stop Channel
    [Documentation]  stops a validation channel through channelctl
    [Arguments]  ${channel}

    ${result}=             Run Command                         channelctl
    ...                                                        --tenant  ${TENANT_NAME}
    ...                                                        stop
    ...                                                        --channel  ${channel}
    Process Should Exit 0   process_return_code=${result.rc}

Run Punchline
    [Documentation]  Run punchlinectl in foreground with a choosen expected return code
    [Arguments]  ${punchline}  ${runtime}=${EMPTY}  ${return_code}=0

    File Should Exist      ${punchline}
    ${runtime_arg}=        Set Variable If                     "${runtime}"=="${EMPTY}"
    ...                                                        ${EMPTY}
    ...                                                        --runtime ${runtime}
    ${result}=             Run Command                         punchlinectl
    ...                                                        --tenant  ${TENANT_NAME}
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
    ...                                                        --tenant  ${TENANT_NAME}
    ...                                                        start  --plan  ${plan}
    ...                                                        --template  ${template}
    ...                                                        --runtime  ${runtime}
    ...                                                        --last-committed
    Process Should Exit    process_return_code=${result.rc}    return_code=${return_code}


Inject Logs
    [Documentation]  Runs a log injector
    [Arguments]              ${injector_}

    File Should exist        ${injector}
    ${result}=               Run Command     punchplatform-log-injector.sh
    ...                                      -c    ${injector}
    Process Should Exit 0    ${result.rc}
