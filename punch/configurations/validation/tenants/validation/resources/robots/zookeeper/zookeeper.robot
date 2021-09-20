*** Settings ***
Documentation    Test that zookeper is up and correctly configured
Metadata         Version    6.3.0-SNAPSHOT
Metadata         https://punchplatform.com
Metadata         Author: Punchplatform Team
Test Timeout     ${TIMEOUT}
Resource         ../utils/punch_common.robot

*** Test Cases ***
Execute ZkCli
    [Documentation]  Executing ls with ZkCli.sh
    [Tags]  zookeeper

    ${result} =       Run Command         %{PUNCHPLATFORM_ZK_INSTALL_DIR}/bin/zkCli.sh
    ...                                   -server    localhost:2181
    ...                                   ls    /
    Should Contain    ${result.stdout}    [punchplatform-primary, zookeeper]


Execute Punch Zookeeper Console Shell Using Cluster Name and command after -- arg
    [Documentation]  Executing ls with punchplatform-zookeeper-console.sh using --cluster parameter
    [Tags]  zookeeper

    ${result} =       Run Command         punchplatform-zookeeper-console.sh
    ...                                   --cluster    common
    ...                                   --    ls    /
    Should Contain    ${result.stdout}    [punchplatform-primary, zookeeper]


Execute Punch Zookeeper Console Shell Using Servers
    [Documentation]  Executing ls with punchplatform-zookeeper-console.sh using --servers parameter
    [Tags]  zookeeper

    ${result} =       Run Command         punchplatform-zookeeper-console.sh
    ...                                   --servers    localhost:2181
    ...                                   ls    /
    Should Contain    ${result.stdout}    [punchplatform-primary, zookeeper]


Execute Punch Zookeeper Console Shell Using native zookeeper -server arg and inlined command
    [Documentation]  Executing ls with punchplatform-zookeeper-console.sh using --servers parameter
    [Tags]  zookeeper

    ${result} =       Run Command         punchplatform-zookeeper-console.sh
    ...                                   -server    localhost:2181
    ...                                   ls    /
    Should Contain    ${result.stdout}    [punchplatform-primary, zookeeper]
