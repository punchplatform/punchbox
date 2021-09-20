# Prerequisite

Source punchplatform `activate.sh` before proceeding.

```sh
# standalone
source $PUNCHPLATFORM_CONF_DIR/../activate.sh

# deployed platform
source $PUNCHPLATFORM_CONF_DIR/activate.sh
```

## Quick Start

Another `activate.sh` is provided to ease the execution of tests.
Alias are created with correct parameters already defined.

An executable PEX archive: `punch-robot` which is available on `$PATH` upon sourcing `activate.sh` from prerequisite is aliased to:

1) punch-robot-test  # Only essential information are shown on STDOUT
2) punch-robot-test-console  # All events and test result are shown on STDOUT
3) punch-robot-test-kafka  # All events and test result are sent to a kafka topic

Each of the above aliases takes the same arguments.

For instance:

```sh
# Execute all tests find in current directory by search for .robot file recursively
punch-robot-test .
punch-robot-test-kafka .

# Execute only tests that has the tag: MY_TAG
punch-robot-test --include MYTAG .
punch-robot-test-console --include MYTAG .
```

## Test documentation

### Configuration test documentation

If you want to view a global documentation of all written robot tests, just use the command below:

```sh
punch-robot-doc-conf . output_doc.html
```

This command will recursively search for all robot files in current direcotry and generate an html documentation as `output_doc.html` in current directory.

### Custom library documentation

It is also possible to view punch custom library documentation by executing the command:

```sh
# to view python documentation
punch-robot-doc-lib $KEYWORD_ELASTICSEARCH_ASSERTION show
# or to view available keywords
punch-robot-doc-lib $KEYWORD_ELASTICSEARCH_ASSERTION list
```

Note: all custom keyword will be prefixed by KEYWORD.

## Kafka reporter and Dashboarding

### Kafka

Use: `punch-robot-test-kafka .`

A configuration file to set kafka settings is provided with default configuration: `kafka_config.yaml`

### Dashboarding

A channel that fetches data from a kafka topic and saves the resulting data to an elasticsearch index is available by using:

```sh
channelctl -t validation start --channel integration_test
```

Any tests that are executed using `punch-robot-test-kafka` command will have their data stored in elasticsearch.

## Test Workflow


```sh
cd $PUNCHPLATFORM_CONF_DIR/tenants/validation/resources/robots
source activate.sh

# A new command will be enabled: punch-robot-test

# test a single robot file

punch-robot-test punchline/punchline.robot

# test two robot files

punch-robot-test punchline/punchline.robot archiving/archiving.robot

# test all robot files in a directory recursively

punch-robot-test .
```

# Debugging and Result

## Debugging

During test execution, you may want to know why some of your test cases are failing.

You can directly investigate processes logs by going to: `$ROBOT_STDOUT`.

## Report/Result

At the end of the executions of your tests suites, an html file is generated with a summary of all your tests suites. 

Go to: `$ROBOT_OUTPUT_DIR`
