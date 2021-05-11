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

Clone the `pp-punch` repository and save its location in `PUNCH_DIR`:

```sh
echo "export PUNCH_DIR=/path/to/pp-punch >> ~/.bashrc"
source ~/.bashrc
```

**You MUST have compiled a punch version in `pp-punch`!**

## Quick start 

This example shows how to deploy a complete punch quickly. We provided a Makefile to reduce 
verbosity of punchbox commands. 

However, if you want to go further, please read next section which offers you more possibilities in terms of configuration
(i.e create your punchbox config, select a specific user config ..)

If you want to deploy on Redhat platform, you need a Redhat licence or a free [RHEL developer subscription](https://developers.redhat.com) that are limited to 20 VMs per account. During the installation the Makefile will ask you your credentials to register VMs on account. When you delete yours VMs, they will automatically unregister from your account. 

Here it is a punch deployment on a set of ubuntu virtual machines (32gb of RAM in total). Other configurations
are available trought in the Makefile, type `make` to see all of them

Basic usage :

```sh
# This command install a deployer, generate a configuration, start the vagrant boxes and deploy
make default-punch
# This command install a deployer, generate a TLS configuration, start the vagrant boxes and deploy
make default-tls
```

More information about the make usage :

```sh
make help
```

## Custom Usage

### Punchbox configuration

Considering you already have a punchbox config file : 

```sh
source activate.sh
punchbox --config myconfig.json
make start-vagrant
make deploy
```

Custom configuration :



## Punchplatform validation  

Once you have deployed your Punchplatform, you may be wondering how to check your platform health

Refer to the [validation](./configurations/validation/README.md) guide. 
