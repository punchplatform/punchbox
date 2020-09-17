# Punchplatform validation

**Warning** : Section in Beta, fixes will coming soon

Punchplatform validation could be use to daily check your platform health or to check a 
specific critic point

Punchplatform team provides and uses this tool to validate Punchplatform releases
and to maintain stabilily of Punch repository 

Files in `templates` folder combined with Punchplatform standalone examples
are the resources necessary for Punchplatform team validation

However, you can use your own channels and create your own validation templates to respond
to your specific use case 

## Punchplatform integration 

### Quick Start

#### TEST on vagrant a complete punch platform with 32G RAM

```sh
make install
# a .deployer file is generated which contains the file path to your deployer.zip; change it to yours if it doesn't match
# By default we consider that pp-punch and punchbox are in the same directory: $WORKING_SPACE/pp-punch and $WORKING_SPACE/punchbox
make configure-deployer

# Generate all configurations for a 32G deployment on ubuntu
make punchbox-ubuntu-32G-validation

# Pop up vagrant boxes
make start-vagrant

# Deploy Punchplatform
make deploy-punch

# send validation configuration files to your platform and run tests
make local-integration-vagrant

# note: run local-integration-vagrant rule as many as you want to run tests
# if you want to update configuration before testing
make update-deployer-configuration && make local-integration-vagrant

# Reset punchbox environment
make clean
```

#### Setup automatic scheduling with systemd

**Note 1**: their is no automatic clone of pp-punch repository; 

**Note 2**: make sure that the desired branch of pp-punch is already built, in general the master branch; 

**Note 3**: it is mandatory for punchbox and pp-punch to be in the same working directory;

**Note 4**: to report to other endpoint than the platform itself, set LIVEDEMO_API_URL before executing make rules;

Example:

```sh
user@PUNCH: ~/r61$ ls
pp-punch  punchbox  starters
```

##### Ubuntu LTS 18.X

```sh
# everyday at 4 am
make validation-scheduler-ubuntu-32G hour=4

# status
systemctl --user status punch-validation.timer

# log
systemctl --user status punch-validation.service
# and/or
journalctl -u punch_validation.service -f

# removing the timer
make clean-validation-scheduler
```

##### CentOS 7

```sh
# everyday at 2 am
make validation-scheduler-centos-32G hour=2

# log
systemctl --user status punch-validation.service
# and/or
journalctl -u punch_validation.service -f

# removing the timer
make clean-validation-scheduler
```

### Manual integration 

You have to deploy your platform with a specific validation configuration : 

```sh
punchbox --platform-config-file configurations/complete_punch_16G.json \
        --generate-vagrantfile \
        --punch-validation-config punch/configurations/validation/  \
        --deployer <path_to_your_punchplatform_deployer_zip> \
        --validation
punchplatform-deployer.sh --generate-platform-config --templates-dir punch/platform_template/ --model punch/build/model.json
punchplatform-deployer.sh --deploy -u vagrant
punchplatform-deployer.sh -cp -u vagrant
```

Once your deployment is successful you can check your platform health. 
Connect to your operator node, you will find a shell in `pp-conf/check_platform.sh`
Global execution takes around 15 minutes. 

To execute it: 
```sh
ssh vagrant@server_operator
./pp-conf/check_platform.sh
```

This automatic test checks if aggregation channel works and send result in a specific slack channel.

### Reporting to Livedemo

You can send your tests results to the Punchplatform Livedemo with ElastAlert HTTP POST.

Only two environment variables are required to do so : 

```sh
PUNCH_DIR=/home/punch/workspace/pp-punch
LIVEDEMO_API_URL=http://xxxx
```

The Livedemo will receive :
- tests results from rules in `validation/channels/elastalert_validation/rules/failure/*.yaml` and `/success/*.yaml`
- validation information from `validation/channels/elastalert_validation/rules/validation.yaml`

A Spark aggregation plan running on Livedemo will add aggregated tests results to the validation information document.

## Punchplatform tests 

This section describes tests done during Punchplatform team validation :

### Aggregation test 

Launch aggregation and apache channels from Punchplatform standalone and then use log injectors 

**Scope covered** : 
  - Put configuration in zookeeper
  - Push some templates to Elasticsearch
  - Import Kibana dashboards 
  - Storm execution 
  - Archiving : Checking some metadata is created by archiving
  - Housekeeping : Checking metadata are removed by housekeeper
  - Plan and spark in foreground mode  
  - Log injectors 
  - Elasticsearch 

### Spark test 

Launch spark channels from punchbox validation tenant (located in `conf` folder )

**Scope covered** : 
  - Check exit 0 code for spark executions in client mode (java, python and java/python punchlines)  
  - Check exit 1 code for spark executions in client mode (java, python and java/python malformed punchlines)  
  - Check anormal exit 0/1 

### Elastalert test : 

Launch elastalert channel to get and publish results from previous tests 

**Scope covered** : 
  - Shiva execution
  - Elastalert 
  - Elasticsearch


