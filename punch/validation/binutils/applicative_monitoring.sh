#!/bin/bash -u
#
# INFO: tested with Kibana v7.4.2 on Ubuntu
#

# MANDATORY MODULE: Jq
if [ "$(which jq)" = "" ]; then
    fatal "Command 'jq' must be installed and available."
fi

# The default value of the variable. Initialize your own variables here
ELASTIC=http://localhost:9200


# Now, kibana does not rely on the document type anymore, but on a "type" field and per-type sub-fields 
# with the same prefix as the name (i.e. <type>.title)
# e.g. :  "_source": {
#         "type": "search",
#          "updated_at": "2018-02-05T18:08:10.509Z",
#          "search": {
#            "title": "Kafka Topics current Health and Alert",
#            "description": "",
#            "hits": 0,
#            [...]

DEBUG='false'
INDEX=''
BODY=''

print_usage() {
  echo "
Description:
  Check number of doc in a specific Elasticsearch index.
  Using doc API from ES

Usage: $(basename "$0") [--check] [options]

Options:
  -h | --help
    Print the help menu.
  -l | --url <url>
    Elasticsearch URL. By default is ${ELASTIC}.
  -u | --user <name>
    Username and password for authenticating to Elasticsearch using Basic
    Authentication. The username and password should be separated by a
    colon (i.e. "admin:secret"). By default no username and password are
    used.
  -i | --index
    Specify index to check
  -b | --body
    Request body (JSON format)

" >&2
}

while [ $# -gt 0 ]; do
case $1 in
    -l | --url )
        ELASTIC=$2
        if [ "$ELASTIC" = "" ]; then
            echo "Error: Missing Elasticsearch URL"
            print_usage
            exit 1
        fi
        shift 2
        continue
        ;;

    -u | --user )
        USER=$2
        AUTH="--user ${USER}"
        if [ "$USER" = "" ]; then
            echo "Error: Missing username"
            print_usage
            exit 1
        fi
        shift 2
        continue
        ;;

    -h | --help )
        print_usage
        exit 0
        ;;

    -i | --index )
        INDEX=$2 
        if [ "$INDEX" = "" ]; then
            echo "Error: Missing index"
            print_usage
            exit 1
        fi
        shift 2
        continue
        ;;

    -b | --body )
        BODY=$2 
        if [ "$BODY" = "" ]; then
            echo "Error: Missing body"
            print_usage
            exit 1
        fi
        shift 2
        continue
        ;;

    * )
        print_usage
        print "Error: Unknown option $1"
        ;;

esac
done


# Usage : echo $(printInsertionResult $REQUEST_RESULT)
function printInsertionResult () {
    result=`echo "$1" | jq -c .count`
    if [ $result = 0 ]; then
        status="No doc found in ${INDEX} index"
        echo -e "Status=${status}"
    else
        status="Some doc found in ${INDEX} index"
        echo -e "Status=${status} Count=${result}"
    fi
}

echo -e "ElasticsearchEndpoint=${ELASTIC}"


RESULT=`curl -s ${USER} -XGET "${ELASTIC}/${INDEX}/_count" -H 'Content-type: application/json' -d "${BODY}"`
printInsertionResult $RESULT
exit 1
