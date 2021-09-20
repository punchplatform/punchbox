*** Settings ***
Documentation    Test Plan: offset, punchline runtime (pyspark, spark) and templating
Metadata         Version    6.3.0-SNAPSHOT
Metadata         https://punchplatform.com
Metadata         Author: Punchplatform Team
Test Teardown    Terminate All Processes    kill=True
Test Timeout     ${TIMEOUT}
Resource         ../utils/elastic_common.robot

*** Variables ***
${cursor_index_conf}               ${CURDIR}/elasticsearch_cursor_config.yaml
${cursor_ts_field}                 plan.checkpoint_interval
${dates_templating_index_conf}     ${CURDIR}/elasticsearch_dates_templating_config.yaml
${from_ts_field}                   from_date
${to_ts_field}                     to_date

*** Keyword ***
Plan Cursor Without Shiva
    [Documentation]  Test 3 iterations of plan with last-committed enabled.
    ...              Expecting 3 or more documents in persistence index, timestamp in
    ...              persistence index to increase
    ...              Each new execution will wipe existing elasticsearch index
    [Arguments]  ${runtime}
    [Teardown]  Delete Index    ${cursor_index_conf}

    Ensure Elasticsearch Is Alive         ${cursor_index_conf}
    Delete Index                          ${cursor_index_conf}
    Run Plan                              plan=${CURDIR}/plan.hjson    template=${CURDIR}/simple_template.hjson
    ...                                                                runtime=${runtime}
    Number Of Documents Should Be GorE    ${cursor_index_conf}         num_of_doc=2
    Timestamp Field Is Advancing          ${cursor_index_conf}         ${cursor_ts_field}


Plan Date Templating Without Shiva
    [Documentation]  Test 3 iterations of plan that generates dates and output its results to
    ...              an Elasticsearch index. Generated dates are increasing in time.
    [Arguments]  ${runtime}
    [Teardown]  Delete Index    ${dates_templating_index_conf}

    Ensure Elasticsearch Is Alive         ${dates_templating_index_conf}
    Delete Index                          ${dates_templating_index_conf}
    Run Plan                              plan=${CURDIR}/plan.hjson         template=${CURDIR}/date_template.hjson
    ...                                                                     runtime=${runtime}
    Number Of Documents Should Be GorE    ${dates_templating_index_conf}    num_of_doc=1
    Timestamp Field Is Advancing          ${dates_templating_index_conf}    ${from_ts_field}
    Timestamp Field Is Advancing          ${dates_templating_index_conf}    ${to_ts_field}

*** Test Cases ***
Plan Cursor Spark Without Shiva
    [Documentation]  Test 3 iterations of plan with last-committed enabled.
    ...              Expecting 3 or more documents in persistence index, timestamp in
    ...              persistence index to increase
    ...              Each new execution will wipe existing elasticsearch index
    [Tags]  plan  spark
    Plan Cursor Without Shiva    spark


Plan Cursor Pypark Without Shiva
    [Documentation]  Test 3 iterations of plan with last-committed enabled.
    ...              Expecting 3 or more documents in persistence index, timestamp in
    ...              persistence index to increase
    ...              Each new execution will wipe existing elasticsearch index
    [Tags]  plan  pyspark
    Plan Cursor Without Shiva    pyspark


Plan Date Templating Spark Without Shiva
    [Documentation]  Test 3 iterations of plan that generates dates and output its results to
    ...              an Elasticsearch index. Generated dates are increasing in time.
    [Tags]  plan  spark
    Plan Date Templating Without Shiva    spark


Plan Date Templating Pyspark Without Shiva
    [Documentation]  Test 3 iterations of plan that generate dates and output its result to
    ...              an Elasticsearch index. Generated dates are increasing in time.
    [Tags]  plan  pyspark
    Plan Date Templating Without Shiva    pyspark


