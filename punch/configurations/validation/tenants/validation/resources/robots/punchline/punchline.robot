*** Settings ***
Documentation    Test punchlines with runtime spark, pyspark, storm or shiva
...              Exit code are tested with the use-cases below:
...              - incorrect punchline spark/pyspark syntax (expected: 1)
...              - incorrect spark/pyspark sql syntax (expected: 1)
...              - valid punchline with runtime spark/pyspark (expected: 0)
Metadata         Version    6.3.0-SNAPSHOT
Metadata         https://punchplatform.com
Metadata         Author: Punchplatform Team
Test Teardown    Terminate All Processes    kill=True
Test Timeout     ${TIMEOUT}
Resource         ../utils/punch_common.robot

*** Variables ***
${spark_valid_punchline}       ${CURDIR}/punchline_valid.hjson

${spark_bad_syntax_punchline}       ${CURDIR}/punchline_bad_syntax.hjson


*** Test Cases ***
Spark Valid Punchline With Exit Code 0
    [Documentation]  Test with a valid punchline configuration using
    ...              the runtime spark with returned exit code 0
    [Tags]  spark  punchline
    Run Punchline    ${spark_valid_punchline}    spark
    ...                                          return_code=0


Spark invalid Punchline With Exit Code 1
    [Documentation]  Test with a valid punchline configuration using
    ...              the runtime spark with returned exit code 1
    [Tags]  spark  punchline
    Run Punchline    ${spark_bad_syntax_punchline}    spark
    ...                                               return_code=1


Pyspark invalid Punchline With Exit Code 1
    [Documentation]  Test with an invalid punchline configuration using
    ...              the runtime pyspark with returned exit code 1
    [Tags]  pyspark  punchline
    Run Punchline    ${spark_bad_syntax_punchline}    pyspark
    ...                                               return_code=1


Pyspark Valid Punchline With Exit Code 0
    [Documentation]  Test with a valid punchline configuration using
    ...              the runtime pyspark with returned exit code 0
    [Tags]  pyspark  punchline
    Run Punchline    ${spark_valid_punchline}    pyspark
    ...                                          return_code=0

####################################################################################
#
#              EXIT-CONDITIONS test in a 'punchlinectl' context
#
####################################################################################


Exit Condition On Tuple Failure
    [Documentation]  Test that a punchline run through punchlinectl applies Exit condition "on failures >= 1"
    ...              AND test punchlet capacity to generate tuple failure in Punch node through PunchTupleException
    [Tags]  shiva  punchline

    Run punchline    ${CURDIR}/punchline_with_exit_caused_by_failure.yaml    return_code=255


Nominal Exit Despite Tuple Failure
    [Documentation]  Test that a punchline run through punchlinectl applies Exit condition "on failures >= 1"
    ...              AND test punchlet capacity to generate tuple failure in Punch node through PunchTupleException
    [Tags]  shiva  punchline

    Run punchline    ${CURDIR}/punchline_with_nominal_exit_because_not_enough_failures.yaml    return_code=0


