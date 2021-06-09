# Punch Deployment

## Before You Start 

This folder provides easy tools and samples to deploy and validate a complete Punch with different configurations. It is necessary for you 
to have an official punch deployer package, which only comes with a license. Get in touch with the punch team if you are interested in exploring the punch.

If you are new to the punch essential concepts :

* a Punch **platform** is a punch you deploy on one or several servers. A platform only consists in the components you 
  decide to deploy by configuration. 
* a Punch **user configuration**  (simply referred to as *configuration*) is where you define your applications. A user
  configuration consists in : 
  - one or several *tenants*
  - in each tenant, one or several *channels*
  - in each channel, one or several *applications*
* Punch **resources** are static configuration files that are often used along with your configuration. Resources are:
  - certificates
  - kibana dashboards and elasticsearch mappings
  - enrichment files like geoip database file
  - machine learning models
  - etc..

The Punch applications are particular in that they are expressed using simple (json or hjson) configuration files. 
Of course all these are explained in details on the punch [online documentation](https://doc.punchplatform.com).

Have a look at the configurations/sample folder. It defines a minimalistic application that consists in a single *sample* tenant, that contains a single *sample* channel, that contains a sample application which receives logs on the 9999 tcp port, and simply print them to stdout.

In the rest of this chapter we go through a complete deployment, assuming you have your vargant boxes ready. If you have reachable VMs somewhere you can of course use these instead vagrant boxes. 

## Requirements

Check [Punchbox](../README.md) requirements first !

Install a `punch-deployer` and save its location in your environment `PUNCH_DEPLOYER`:

```sh
cd pp-punch
mvn clean install
unzip packagings/punch-deployer/target/punch-deployer-<version>.zip -d ~
echo "export PUNCH_DEPLOYER=$HOME/punch-deployer-<version>.zip >> ~/.bashrc"
source ~/.bashrc
```

## Quick start

Basic usage :

```sh
# This command generate a configuration, start the vagrant boxes and deploy
punchbox run default
# This command generate a TLS configuration, start the vagrant boxes and deploy
punchbox run tls
```

More information about the punchbox usage :

```sh
punchbox help
```

This example shows how to deploy a complete punch quickly. We provided a Makefile to reduce
verbosity of punchbox commands.

However, if you want to go further, please read next section which offers you more possibilities in terms of configuration
(i.e create your punchbox config, select a specific user config ..)

If you want to deploy on Redhat platform, you need a Redhat licence or a free [RHEL developer subscription](https://developers.redhat.com) that are limited to 20 VMs per account. During the installation the Makefile will ask you your credentials to register VMs on account. When you delete yours VMs, they will automatically unregister from your account.

Here it is a punch deployment on a set of ubuntu virtual machines (32gb of RAM in total). Other configurations
are available trought in the Makefile, type `make` to see all of them

## Custom Usage

### Custom Punchbox configuration

Using the default platform configuration provided by punchbox :

```sh
punchbox config /path/to/punchbox_conf.json
punchbox vagrant start
punchbox deploy
```

Learn more about custom configurations in [Punchbox configuration documentation](../configurations/README.md)

### Custom punchplatform-deployment.settings

Using an existing punch configuration in your home directory :

```sh
punchbox config default
cp ~/punchplatform-deployment.settings punch/build/pp-conf/
punchbox vagrant start
punchbox deploy
```
