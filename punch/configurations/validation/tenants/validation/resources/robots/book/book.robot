*** Settings ***
Documentation    Test books that runs either Pyspark or Spark
...              Exit code are tested with the use-cases below:
...              - incorrect punchline spark/pyspark syntax (expected: 1)
...              - incorrect spark/pyspark sql syntax (expected: 1)
...              - valid punchline with runtime spark/pyspark (expected: 0)
Metadata         Version    6.3.0-SNAPSHOT
Metadata         https://punchplatform.com
Metadata         Author: Punchplatform Team
Test Setup       Stop Books
Test Teardown    Stop Books
Test Timeout     ${TIMEOUT}
Resource         ../utils/punch_common.robot

*** Test Cases ***
Spark Foreground Valid Punchline With Exit Code 0
    [Documentation]  Test with a valid punchline configuration using
    ...              the runtime spark with returned exit code is 0
    [Tags]  book  spark
    Run Book    valid_spark_foreground    return_code=0


Spark Foreground Bad Syntax Punchline With Exit Code 1
    [Documentation]  Test with an invalid punchline configuration using
    ...              the runtime spark with returned exit code 1
    [Tags]  book  spark
    Run Book    invalid_spark_foreground    return_code=1


Spark Cluster Valid Punchline
    [Documentation]  Test with a valid punchline configuration using
    ...              the runtime spark with returned exit code is 0
    [Tags]  book  spark
    Run Book    valid_spark_cluster    return_code=0


Spark Cluster Invalid Punchline
    [Documentation]  Test with an invalid punchline configuration using
    ...              the runtime spark with returned exit code 1
    [Tags]  book  spark
    Run Book    invalid_spark_cluster    return_code=1


Pyspark Foreground Valid Punchline With Exit Code 0
    [Documentation]  Test with a valid punchline configuration using
    ...              the runtime spark with returned exit code is 0
    [Tags]  book  pyspark
    Run Book    valid_pyspark_foreground    return_code=0


Pyspark Foreground Bad Syntax Punchline With Exit Code 1
    [Documentation]  Test with an invalid punchline configuration using
    ...              the runtime spark with returned exit code 1
    [Tags]  book  pyspark
    Run Book    invalid_pyspark_foreground    return_code=1


Pyspark Cluster Valid Punchline With Exit Code 0
    [Documentation]  Test with a valid punchline configuration using
    ...              the runtime spark with returned exit code is 0
    [Tags]  book  pyspark
    Run Book    valid_pyspark_cluster    return_code=0


Pyspark Cluster Bad Syntax Punchline With Exit Code 1
    [Documentation]  Test with an invalid punchline configuration using
    ...              the runtime spark with returned exit code 1
    [Tags]  book  pyspark
    Run Book    invalid_pyspark_cluster    return_code=1
