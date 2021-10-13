# Punchbox Integration Tools

Welcome to the punchbox project. It provides tools to easily deploy plain servers and/or punch platforms in a
production-ready setup.

These tools run fine on 16G laptops. 32G is recommended. If you have one you will be at ease to work locally, i.e. have
a representative platforms completly running on local VMS. This said; these tools are also very useful should you have (
remote) VMs or physical servers.

On the rationale and other quick questions you may have: checkout the [FAQ](./FAQ.md). If you have issues refer to
the [Troubleshootings](./Troubleshooting.md).

## Requirements

### RSA Key for ssh

Ansible (hence ssh) is used to deploy the punch software and cots onto the vagrant VMs. An RSA public key is required.
By default, your default key (/.ssh/id_rsa.pub).

If it does not exist, create one:

```sh
ssh-keygen  ### When prompted, use the provided default values (just press Return key)
```

That key will be installed in the authorized_keys file of each VM. Right after your VMs are created, ensure you can
successfully ssh without password to each VM :

```sh
ssh vagrant@server1
```

Check out the [Troubleshootings](./Troubleshooting.md) in case of problem.

### Python

[pyenv](https://github.com/pyenv/pyenv) is used to install the exact python version we depend on ~ **3.6.8**.

A virualenv directory is created at the root of this repository on your local filesystem, containing required python
modules for the punchbox to be functional.

Some python module, such as ansible, are generated as PEX by our `Makefile` install rule. They are then added to your
`$PATH` upon sourcing the `activate.sh` script.

If not familiar with python installation and best practices refer to
[Setup Python](https://doc.punchplatform.com/Common/Contribution_Guide/Developper/Setup/Setup_Python.html).

Here is a safe and clean procedure to set up your python environment: first create and activates a new virtualenv and
call it (say) punchbox

```sh
pyenv virtualenv 3.6.8 punchbox
pyenv activate punchbox
```

Next install pex, to do that use the provided requirements.txt

```sh
# in your python environment
pip install -U pip
pip install -r requirements.txt
```

If you plan to use vagrant, install [vagrant](https://www.vagrantup.com/downloads.html)
and [virtualbox](https://www.virtualbox.org/).

## Installation and Deployment

### Introduction

Deploying a punch is actually quite simple. All you need to do is use the makefile.

There are six steps, each calling the previous one, meaning you can basically run only the last one if you want
everything done. If you've updated some files, you should only run the last step. Make will know which file has been
updated and which step should be executed again.

```
Step 1 : build the punchbox tools and prepare the environment.
  install          Build the punchbox tools

Step 2 : configure the different options : deployer, configuration, os, security, validation...
  configure        Set configuration

Step 3 : generate platform model to deploy.
  punchbox         Run punchbox templating

Step 4 : start (or stop) your VMs
  start-vagrant    Start vagrant boxes
  stop-vagrant     Stop vagrant boxes. This is useful to simply stop, not destroying.

Step 5 : deploy the punch, i.e. deploy all the punch components to yours vms.
  deploy           Deploy punch components to the target VMs
```

Note :  You can find this description by running a simple `make`.

### Configuration

During the installation, you'll be asked to provide some configuration choices and file paths.

These configuration choices will be stored in some "marker files". You'll be able to find them in the `markers` folder
of this repository.

To change these configurations, simply update the content of the marker files. To be asked again, simply delete the
concerned file.

### Make steps

#### Deploy

This is the main step. To create vagrant VMs and deplo a punch on it, simply run :

```shell
make deploy
```

This should leave you with a deployed punch, ready to be used.

To deploy your configuration to your punch, simply run :

```shell
make deploy-config
```

The deployed configuration is the one located in `punch/build/pp-conf`. You can always update it and deploy again using
the same command.

#### Vagrant Start/Stop

If you only want to deploy vagrant, you can simply run :

```shell
make start-vagrant
```

This will generate a vagrant file with the correct configuration and start the VMs.

This is also a useful command to stop and start vagrat without deleting your configuration or redeploying your punch.

#### Punchbox

If you only want to generate your configuration files, you can run

```shell
make punchbox
```

Your configuration should be available in `punch/build`.

#### Configure

If you only want to choose or update your configuration, run :

```shell
make configure
```

#### Install

If you only want to build the pex and install prerequisites :

```shell
make install
```

Check everything is correctly setup by executing the punchbox command:

```sh
source activate.sh
punchbox -h
```

#### Cleaning

If you want to reset your environment :

```sh
make clean
```

You'll find more specific cleaning in you make description :
```
Clean up
  stop             Only stop vagrant boxes
  clean            Cleanup vagrant and deployer. Watchout this wipes everything.
  clean-deployer   Remove the installed deployer
  clean-punch-config  Remove Punchplatform Configurations
  clean-vagrant    Remove vagrant boxes and generated Vagrantfile
  clean-markers    Remove all makefile markers
```

## Punchbox Command

The commands provided by the `Makefile` are simple wrappers of punchbox commands. You can use them directly if you want
to have more possibilities.

Assuming you also have a punch deployer and your associated configuration somewhere type in the following command:

```sh
punchbox --platform-config-file configurations/complete_punch_16G.json \
         --generate-vagrantfile \
         --punch-user-config <path_to_your_punchplatform_config_folder> \
         --deployer <path_to_your_punchplatform_deployer_zip>
```

Note: you can add the --start-vagrant to also start the vagrant boxes if not done yet.

In case you do not know what to use for `path_to_your_punchplatform_config_folder`, simply use the validation configuration,
i.e:

```sh
punchbox --platform-config-file configurations/complete_punch_16G.json \
        --generate-vagrantfile \
        --punch-user-config $PUNCHBOX_DIR/punch/configurations/validation \
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

Last you can effectively deploy the punch. Note that you can use tags to install only a part of it:
Note also that after successful configuration generation you can deploy a specific component for example:

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

### Options

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

To deploy the Punchplatform alongside security measures, use the `--security` option with a complete configuration
file :

```shell
make install
source activate.sh
punchbox --platform-config-file configurations/complete_punch_32G.json \
        --punch-user-config <path_to_your_punchplatform_config_folder> \
        --security
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

## Contribute

This repository is licensed under the ApacheV2 license, please feel free to contribute. Only the punch itself is
submitted to license, but is not necessary to use the vagrant or kube parts.