# Punch Integration Tools

This repository provides easy tools to deploy a production punch on top of
virtualk boxes. It is designed to do all that on a single laptop.

Watchout : this repository follows the punch branch naming convention used by the punch. I.e. use the
- 5.7 branch if you work with a craig release
- 6.0 branch if you work with a dave or duke release 
- etc..

## Generate a Punch

Assumming you also have the pp-punch punch repository somewhere (say `~/pp-punch`)
type in the following command: (remove the --start-vagrant to no start the vagrant boxes)

```sh
punchbox --config configurations/complete_punch_16G.json \
        --generate-vagrantfile \
        --punch-conf ~/pp-punch/pp-packaging/punchplatform-standalone/target/tmp/punchplatform-resources-*/conf/ \
        --deployer ~/pp-punch/pp-packaging/punchplatform-deployer/target/punchplatform-deployer-*.zip \
        -start-vagrant
```

This will unzip the punch deployer archive, as well as the sample standalone channels so that you will have a complete
sample application deployed on your punch.

Once that done go on and generate the punch deployement files. You dop that using the `punchplatform-deployer.sh`
tool that is now available to you. 

```sh
source $PUNCHBOX_DIR/activate.sh
punchplatform-deployer.sh --generate-platform-config \
    --templates-dir $PUNCHBOX_DIR/punch/platform_template/ \
    --model $PUNCHBOX_DIR/punch/build/model.json
punchplatform-deployer.sh -gi
``

Last you can effectively deploy the punch. Note that you can use tags to install only
a part of it:
Note that  a successful configuration generation you can deploy a specific component for example:

```sh
# install everything 
punchplatform-deployer.sh deploy -u vagrant
# install only install zookeeper
punchplatform-deployer.sh deploy -u vagrant --tags zookeeper
# install zookeeper plus operator
punchplatform-deployer.sh deploy -u vagrant --tags zookeeper,operator
```

## Punch Integration Tests 

Once your deployment is successful you can check your platform health. 
Connect to your operator node, you will find a shell in `pp-conf/check_platform.sh` which : 

  - Put your configuration in Zookeeper
  - Push some templates to Elasticsearch
  - Import Kibana dashboards 
  - Launch useful channels 
  - Start log injectors 

Global execution takes around 15 minutes. 

To execute it: 
```sh
ssh vagrant@server_operator
./pp-conf/check_platform.sh
```

This automatic test checks if aggregation channel works and send result in a specific slack channel.

## Manual test 

After deployment, additionals steps are required to have a full functionning deployement setup.

**Prerequisites**

Inject ES templates and save your configuration in zookeeper

```sh
# root dir - of kibana server
ROOTDIR=$(realpath ~/pp-conf)

# insert elasticsearch templates mapping
punchplatform-push-es-templates.sh --directory $ROOTDIR/resources/elasticsearch --cluster es_search --verbose

# put conf for punchctl
punchplatform-putconf.sh -t mytenant
```

**Inject Data**

```sh
ROOTDIR=$(realpath ~/pp-conf)

# to inject fake logs, by default apache_httpd topology starts on server3
punchctl -t mytenant start --channel apache_httpd
punchplatform-log-injector.sh -c $ROOTDIR/resources/injectors/mytenant/apache_httpd_injector.json -H server3
```

**Troubleshooting**

If you have some issues with Kibana plugin : 

```sh 
# kibana needs punchplatform.properties in it's working directory, by default: ~/pp-conf/tmp_path
mkdir -p $ROOTDIR/tmp_path/conf/
cp $ROOTDIR/punchplatform.properties $ROOTDIR/tmp_path/conf/
```

If you have some issues with ES templates : 

```sh
# In test environment, all indices created prior the insertion of template mapping should be wiped...
# below is a list (not all are included)
CURRENTDATE=2020.03.24
ESVERSION=6.8.6
curl -sS -XDELETE server1:9200/platform-metricbeat-$ESVERSION-$CURRENTDATE
curl -sS -XDELETE server1:9200/mytenant-metrics-$CURRENTDATE
curl -sS -XDELETE server1:9200/mytenant-events-$CURRENTDATE
curl -sS -XDELETE server1:9200/mytenant-archive-$CURRENTDATE
curl -sS -XDELETE server1:9200/mytenant-jobs
```

## User config 

This repository contains different layers and commands which must be passed in order to launch a successful deployment. 

It may seem a bit complicated at first but with a little practice you will soon become quite skilled

From a user point of view only one file is important : `full-32G.json` (the file provide with --config option)

You could update it or create a new one with your specific configuration

This file is composed as follow : 

  - `vagrant`: details about vagrant boxes
      - `boxes`: list of vagrant boxes  
          - `server_name`: string to identify a box
              - `disksize`: size of disk box
              - `memory`: memory size of box
              - `cpu`: number of cpu for box
              - `synced_pp_conf_folder`: boolean to sync pp-conf folder (operator server)
      - `meta`: common details for all boxes
          - `os`: os for all boxes

  - `punch`: list of punch component
      - `elasticsearch`:
          - `servers`: list of elasticsearch hosts
          - `cluster_production_transport_address`: elasticsearch transport address
          - `memory`: maximum size of each elasticsearch nodes Jvm memory
          - `security` : if true, enable Opendistro Security plugin and Opendistro alerting plugin. It will generate 
          configuration for SSL, authentication and security management. The security resource folder will be used to
          deploy default certificates
      - `kibana`: 
          - `servers`: list of kibana hosts
          - `security` : if true, enable Opendistro Security plugin and Opendistro alerting plugin. It will generate 
          configuration for SSL, authentication and security management. The security resource folder will be used to
          deploy default certificates
      - `zookeeper`: 
          - `servers`: list of zookeeper hosts
          - `childopts`: JVM options for zookeeper
      - `gateway`: 
          - `servers`: list of gateway hosts 
          - `inet_address`: inet address for gateway (will be remove soon)
          - `security` : if true, enable ssl connections to, and from, gateway's rest api. It will generate 
          configuration for SSL. The security resource will be used to deploy a  default keystore.
      - `storm`: 
          - `master`: 
              - `servers`: list of storm master hosts
              - `cluster_production_address`: cluster address for storm master
          - `ui`:
              - `servers`: list of storm ui hosts
              - `cluster_admin_url`: cluster address for storm ui
          - `slaves` : list of storm slave hosts
          - `workers_childopts`: storm worker jvm options
          - `supervisor_memory_mb`: size of RAM for supervisor
      - `kafka`:
          - `brokers`: list of kafka brokers
          - `jvm_xmx`: max JVM size for each kafka broker 
      - `shiva`: 
          - `servers`: list of shiva hosts
      -  `spark`:
          - `masters`: list of spark master hosts
          - `slaves`: list of spark slave hosts
          - `slaves_memory`: allocation of memory for each slaves
      - `operator`: 
          - `servers`: list of operator hosts
      

**Note** : All parameters under `vagrant` key are mandatory. For those under `punch`, they are optional

**Note** : do **never** add or change things in the platform_template or vagrant without a first review with the core punch team leaders


## How it works ? 

Here we will explain repository tree and then each internal steps 

This repository contains three essential folders:

- plaform_template provides a punchplatform configuration template
- bin : provide a shell and a python app 
      - `punchbox`: create your integration pex environement and execute integration.py app
      - `integration.py`: unarchive punchplatform deployer, administrate vagrant, generate model for punchplatform 
      deployment, create your ansible pex environement and generate a check platform script

### Generate Inventories and Vagrant management : punchbox

```sh
ROOTDIR=$(realpath ~/Desktop/myPunch/6)  # change this to your location
DEPLOYERZIP=$(ls -of $ROOTDIR/pp-punch/pp-packaging/punchplatform-deployer/target/punchplatform-deployer-*.zip)
PUNCHCONF=$(realpath $ROOTDIR/pp-punch/pp-packaging/punchplatform-standalone/punchplatform-standalone-linux/target/tmp/punchplatform-standalone-*/conf)

./bin/setup_model.sh --deployer $DEPLOYERZIP \
    --config configurations/32-full.json \ 
    --punch-conf $PUNCHCONF \
    ----generate-vagrantfile \
    --start-vagrant
```

It provides two mandatory prerequisites before Punchplatform deployment : 
  - Vagrant boxes to install Punchplatform on it 
  - model.json file to generate punchplatform.properties and punchplatform-deployment.settings files

It also generated a virtualenv like `activate.sh` shell, and unzip your deployer. Setup your environment :

```sh
source ~/.activate.sh`.
```
Splendid ! You are ready to go.

### Deploy : punchplatform-deployer.sh

First generate the final platform configuration files for the target platform you want. 
Here is an example to deploy a 3 nodes zookeeper cluster. We use the zookeeper example because it is extra simple, and has no operator. 
It is a good way to ensure your environment is all good before exploring more
realistic setups. 

```sh
punchplatform-deployer.sh --generate-platform-config --templates-dir platform_template/ --model model.json
Generated files:
  /Users/dimi/Punch/Craig/pp-integration-vagrant/pp-conf/punchplatform-deployment.settings
  /Users/dimi/Punch/Craig/pp-integration-vagrant/pp-conf/punchplatform.properties
``` 

From there you can generate the required ansible inventories.  

```sh
punchplatform-deployer.sh -gi
```

You can now deploy your platform :

```sh
punchplatform-deployer.sh deploy -u vagrant
```

Check things are running ok. But basically that is it. 

## Daily usage 

If you want to reset your environnement : 

```sh
make clean
```

If you made a error in your user config file for example, you might want to regenerate configuration file without dealing another time with vagrant boxes. For that use `setup_model.sh` without clean and vagrant option: 

```sh
./bin/setup_model.sh --deployer ../pp-punch/pp-packaging/punchplatform-deployer/target/punchplatform-deployer-6.0.0-SNAPSHOT.zip --config configurations/32-full.json --punch-conf ../pp-punch/pp-packaging/punchplatform-standalone/punchplatform-standalone-linux/target/tmp/punchplatform-standalone-6.0.0-SNAPSHOT/conf
source activate 
punchplatform-deployer.sh --generate-platform-config --templates-dir platform_template/ --model model.json
punchplatform-deployer.sh -gi
```

If you want to only deal with vagrant boxes, you must use vagrant options : 

```sh
./bin/setup_model.sh --config configurations/32-full.json --generate-vagrantfile --start-vagrant  
```

**Note** : For each update on config or templates you must relaunch all these commands, you can only play with `setup_model.sh` options to be more or less verbose

## Continious deployment 

Previous sections explain how to launch pp-integration and how to administrate it in one shot mode. This one shows how to launch the full repository automaticaly  with cron in order to  test regularly health of each pp-punch version. 


With your current user, copy and paste full result of 'env' command at the beggining of the user crontab file : 
```sh
crontab -e  
```

Then, under these lines add (Be sure to adapt vars with your own configuration): 

```sh
INTEGRATION_DIR=/home/punch/workspace/pp-integration-vagrant
PUNCH_DIR=/home/punch/workspace/craig/pp-punch

00 1  * *  * $INTEGRATION_DIR/bin/automatic_integration.sh 6.0 > /tmp/integration-6.0 2>&1
00 3  * *  * $INTEGRATION_DIR/bin/automatic_integration.sh 6.x > /tmp/integration-6.x 2>&1
```

By doing this, pp-integration will be launched twice a night, once per version, a CD test which : 

- Compile pp-punch
- Deploy pp-integration 
- Launch 'check_platform.sh' (inject data and start useful channels whose Elastalert)
- Publish results in 'integration' slack channel
- Destroy vagrant boxes

You can also launch a global test manually by doing : 

```sh
export INTEGRATION_DIR=/home/punch/workspace/pp-integration-vagrant
export PUNCH_DIR=/home/punch/workspace/craig/pp-punch
automatic_integration.sh 6.0 > /tmp/integration-6.0 2>&1
```
