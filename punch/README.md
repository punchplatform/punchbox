# Punch Deployment

## Before You Start 

This folder provides easy tools and samples to deploy and to validate a complete Punch with different configurations. It is necessary for you 
to have an official punch deployer package, which only comes with a license. Get in touch with the punch team if you are interested in exploring the punch.

If you are new to the punch here a a few important and essential concepts :

* a punch **platform** is a punch you deploy on one or several servers. A food idea is to start with vagrant boxes. A platform only consists in the components you decided to deploy such as elasticsearch, clickhouse, S3 etc.. but has no application yet. I.e. it is empty. 
* a punch *user configuration*  (simply referred to as *configuration*) is where you define your applications. A punch configuration consists in
  - one or several *tenants*
  - in each tenant, one or several *channels*
  - in each channel, one or several *applications*
* *resources* are static configuration files that are often used along with your configuration. Resources are:
  - certificates
  - kibana dashboards and elasticsearch mappings
  - enrichment files like geoip database file
  - machine learning models
  - etc..

The Punch applications are particular in that they are expressed using simple (json or hjson) configuration files. 
Of course all these are explained in details on the punch [online documentation](https://doc.punchplatform.com).

Have a look at the configurations/sample folder. It defines a minimalistic application that consists in a single *sample* tenant, that contains a single *sample* channel, that contains a sample application which receives logs on the 9999 tcp port, and simply print them to stdout.

In the rest of this chapter we go through a complete deployment, assuming you have your vargant boxes ready. If you have reachable VMs somewhere you can of course use these instead vagrant boxes. 

## Deployment

### Quick start 

This example shows how to deploy a complete punch quickly. We provided a Makefile to reduce 
verbosity of punchbox commands. 

However, if you want to go further, please read next section which offers you more possibilities in terms of configuration
(i.e create your punchbox config, select a specific user config ..)

If you want to deploy on Redhat platform, you need a Redhat licence or a free [RHEL developer subscription](https://developers.redhat.com) that are limited to 20 VMs per account. During the installation the Makefile will ask you your credentials to register VMs on account. When you delete yours VMs, they will automatically unregister from your account. 

Here it is a punch deployment on a set of ubuntu virtual machines (32gb of RAM in total). Other configurations
are available trought in the Makefile, type `make` to see all of them 

```sh
make install
# a .deployer file is generated which contains the file path to your deployer.zip; change it to yours if it doesn't match
# By default we consider that pp-punch and punchbox are in the same directory: $WORKING_SPACE/pp-punch and $WORKING_SPACE/punchbox
make configure-deployer

# Generate all configurations for a 32G deployment on ubuntu
make punchbox-ubuntu-32G

# Pop up vagrant boxes
make start-vagrant

# Deploy Punchplatform
make deploy-punch

# Deploy punch configurations to operator nodes 
make deploy-config

# Cleanup everything
make clean
```

### Behind the scene

Commands provided throught the `Makefile` are a wrapper of the following commands. 
You can use them directly if you want to have more possibilities 

Assuming you also have a punchplatform deployer and your associated configuration somewhere
type in the following command:

```sh
punchbox --platform-config-file configurations/complete_punch_16G.json \
        --generate-vagrantfile \
        --punch-user-config <path_to_your_punchplatform_config_folder> \
        --deployer <path_to_your_punchplatform_deployer_zip>
```

Note: you can add the --start-vagrant to also start the vagrant boxes if not done yet.

In case you do not know what to use for `path_to_your_punchplatform_config_folder`, simply use the sample configuration, i.e: 

```sh
punchbox --platform-config-file configurations/complete_punch_16G.json \
        --generate-vagrantfile \
        --punch-user-config $PUNCHBOX_DIR/punch/configurations/sample \
        --deployer <path_to_your_punchplatform_deployer_zip>
```

This will unzip the punch deployer archive, as well as the sample standalone channels so that you will have a complete
sample application deployed on your punch.

Next generate the punch deployment files: You do that using the `punchplatform-deployer.sh`
tool that is now available to you. 

```sh
source $PUNCHBOX_DIR/activate.sh
punchplatform-deployer.sh --generate-platform-config \
    --templates-dir $PUNCHBOX_DIR/punch/deployment_template/ \
    --model $PUNCHBOX_DIR/punch/build/model.json
punchplatform-deployer.sh -gi
```

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
# import punch conf to operator node
punchplatform-deployer.sh -cp -u vagrant
```

### Daily usage 

If you want to reset your environnement : 

```sh
make clean
```

If you made a mistake in your user config file for example, you might want to regenerate the configuration file without 
dealing another time with vagrant boxes. For that use `punchbox` without vagrant options: 

```sh
make install
source activate.sh
punchbox --deployer ../pp-punch/pp-packaging/punchplatform-deployer/target/punchplatform-deployer-6.0.0-SNAPSHOT.zip --platform-config-file configurations/32-full.json --punch-user-config ../pp-punch/pp-packaging/punchplatform-standalone/punchplatform-standalone-linux/target/tmp/punchplatform-standalone-6.0.0-SNAPSHOT/conf
source activate 
punchplatform-deployer.sh --generate-platform-config --templates-dir punch/platform_template/ --model punch/build/model.json
punchplatform-deployer.sh -gi
```

If you want to only deal with vagrant boxes, you must use vagrant options : 

```sh
punchbox --platform-config-file configurations/32-full.json --generate-vagrantfile --start-vagrant  
```

**Note** : For each update on config or templates you must relaunch all these commands, you can only play with `punchbox` options to be more or less verbose

## Options

| Option | Details | Example |
| --- | --- | --- |
| --help | Usage summary. | --help |
| --deployer | Path to the punch deployer zip archive. Something like punchplatform-deployer-6.1.0.zip. | --deployer /Downloads/punchplatform-deployer-6.0.0.zip |
| --punch-user-config | Path to a punch configuration folder with your channels and resources. If you have no idea, check and use the punchbox/punch/configurations/sample/conf folder. | punchbox/punch/configurations/sample/ |
| --punch-validation-config | Path to Punchplatform conf folder with your channels and resources. | --punch-validation-config  punchbox/punch/configurations/sample/validation |
| --platform-config-file |Path to your platform json configuration. Check the punchbox/configurations folder for ready to use configurations. For example complete_punch_16G.json for a complete punch assuming 16Gb ram on your laptop. | --platform-config-file configurations/complete_punch_32G.json |
| --destroy-vagrant | Destroy the machines mounted from the Vagrantfile inside the current `vagrant` folder. | --destroy-vagrant |
| --generate-vagrantfile | Generate a Vagrantfile inside the `vagrant` folder, from `targets.info` and `targets.meta` sections in user configuration. | --generate-vagrantfile |
| --start-vagrant | Mount VMs right after the Vagrantfile generation. Same as `vagrant up` in vagrant folder. | --start-vagrant |
| --generate-inventory | Generate an inventory file to mount VMs without vagrant. | --generate-inventory |
| --generate-playbook | Generate an ansible playbook to mount VMs without vagrant. | --generate-playbook |
| --os | OS name to mount on VMs during the vagrant phase. Used to overwrite the os name inside the user's configuration. | --os centos/7 |
| --interface | Interface name used by the deployed punchplatform components. This value should match the production interface on the mounted VMs. This option does not overwrite or change the interfaces names for vagrant. | --interface eth1 |
| --security | Inject security configurations inside any user configuration to enable Elasticsearch cluster and Kibana servers security | --security |

## Secured deployment

To deploy the Punchplatform alongside security measures, use the `--security` option with a complete configuration file :

```shell
make install
source activate.sh
punchbox --platform-config-file configurations/complete_punch_32G.json \
        --punch-user-config <path_to_your_punchplatform_config_folder> \
        --deployer <path_to_your_punchplatform_deployer_zip> \
        --generate-vagrantfile \
        --start-vagrant
source activate.sh 
punchplatform-deployer.sh --generate-platform-config --templates-dir punch/deployment_template/ --model punch/build/model.json
punchplatform-deployer.sh -gi
punchplatform-deployer.sh deploy -u vagrant
punchplatform-deployer.sh -cp -u vagrant
```

A secured deployment enable :

* Authentication to the Elasticsearch cluster
* Authentication to the Kibana servers

There is no need for further actions, the deployment and the validation steps remain unchanged for the user.

## Punchplatform validation  

Once you have deployed your Punchplatform, you may be wondering how to check your platform health

Refer to the [validation](./configurations/validation/README.md) guide. 
