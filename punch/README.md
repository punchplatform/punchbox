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

Assuming you also have a punchplatform deployer and your associated configuration somewhere
type in the following command:

```sh
punchbox --config configurations/complete_punch_16G.json \
        --generate-vagrantfile \
        --punch-user-config <path_to_your_punchplatform_config_folder> \
        --deployer <path_to_your_punchplatform_deployer_zip>
```

Note: you can add the --start-vagrant to also start the vagrant boxes if not done yet.

In case you do not know what to use for `path_to_your_punchplatform_config_folder`, simply use the sample configuration, i.e: 

```sh
punchbox --config configurations/complete_punch_16G.json \
        --generate-vagrantfile \
        --punch-user-config ./configurations/sample \
        --deployer <path_to_your_punchplatform_deployer_zip>
```

This will unzip the punch deployer archive, as well as the sample standalone channels so that you will have a complete
sample application deployed on your punch.

Next generate the punch deployment files: You do that using the `punchplatform-deployer.sh`
tool that is now available to you. 

```sh
source $PUNCHBOX_DIR/activate.sh
punchplatform-deployer.sh --generate-platform-config \
    --templates-dir $PUNCHBOX_DIR/punch/platform_template/ \
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
punchbox --deployer ../pp-punch/pp-packaging/punchplatform-deployer/target/punchplatform-deployer-6.0.0-SNAPSHOT.zip --config configurations/32-full.json --punch-conf ../pp-punch/pp-packaging/punchplatform-standalone/punchplatform-standalone-linux/target/tmp/punchplatform-standalone-6.0.0-SNAPSHOT/conf
source activate 
punchplatform-deployer.sh --generate-platform-config --templates-dir punch/platform_template/ --model punch/build/model.json
punchplatform-deployer.sh -gi
```

If you want to only deal with vagrant boxes, you must use vagrant options : 

```sh
punchbox --config configurations/32-full.json --generate-vagrantfile --start-vagrant  
```

**Note** : For each update on config or templates you must relaunch all these commands, you can only play with `punchbox` options to be more or less verbose

## Options

| Option | Details | Example |
| --- | --- | --- |
| --help | Usage summary. | --help |
| --deployer | Path to the deployer's zip archive. This option is used to generate the configuration model with components versions and user properties. | --deployer /Downloads/punchplatform-deployer-6.0.0.zip |
| --punch-conf | Path to a Punchpatform's configuration folder to import resources inside the shared folder. These resources will further be placed inside the configuration folder in operator nodes. | --punch-conf /home/user/punchplatform-standalone-linux-6.0.0/pp-conf |
| --config | Path to the user configuration. | --config configurations/complete_punch_32G.json |
| --destroy-vagrant | Destroy the machines mounted from the Vagrantfile inside the current `vagrant` folder. | --destroy-vagrant |
| --generate-vagrantfile | Generate a Vagrantfile inside the `vagrant` folder, from `targets.info` and `targets.meta` sections in user configuration. | --generate-vagrantfile |
| --start-vagrant | Mount VMs right after the Vagrantfile generation. Same as `vagrant up` in vagrant folder. | --start-vagrant |
| --generate-inventory | Generate an inventory file to mount VMs without vagrant. | --generate-inventory |
| --generate-playbook | Generate an ansible playbook to mount VMs without vagrant. | --generate-playbook |
| --os | OS name to mount on VMs during the vagrant phase. Used to overwrite the os name inside the user's configuration. | --os centos/7 |
| --interface | Interface name used by the deployed punchplatform components. This value should match the production interface on the mounted VMs. This option does not overwrite or change the interfaces names for vagrant. | --interface eth1 |

## Secured deployment

To deploy the Punchplatform alongside security measures, use the `--security` option with a complete configuration file :

```shell
make install
source activate.sh
punchbox --deployer ../pp-punch/pp-packaging/punchplatform-deployer/target/punchplatform-deployer-6.0.0-SNAPSHOT.zip \
    --config configurations/complete_punch_32G.json \
    --punch-conf ../pp-punch/pp-packaging/punchplatform-standalone/punchplatform-standalone-linux/target/tmp/punchplatform-standalone-6.0.0-SNAPSHOT/conf
    --security
source activate 
punchplatform-deployer.sh --generate-platform-config --templates-dir punch/platform_template/ --model punch/build/model.json
punchplatform-deployer.sh -gi
```

A secured deployment enable :

* Authentication to the Elasticsearch cluster
* Authentication to the Kibana servers
* SSL connexions to the Elasticsearch cluster
* SSL connexions to the Kibana servers

## Punchplatform validation  

Once you have deployed your Punchplatform, you may be wondering how to check your platform health

Refer to the [validation](./validation/README.md) guide. 
