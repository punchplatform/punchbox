# Punch Integration Tools

This repository provides tools to deploy plain servers, kubernetes clusters and/or
punch based platform in a production-ready setup. Most of these tools should be able to run on machine having at least 16GB of ram memory. 
But is very useful should you have VMs or physical servers as well.

This repository follows the punch branch naming convention. 

For instance, this repository 5.7 branch should be used to deploy the same version of punch (5.7), the 6.0 to deploy a 6.0 etc. If you do not plan to install punch but only kube or vagrant boxes, stick to the latest stable branch !

**Behind the scene**

We use `pyenv` to install the exact python version we depend on ~ **3.6.8**.

A virualenv directory is created at the root of this repository on your local filesystem, containing required python modules for the punchbox to be functional.

Some python module, such as ansible, are generated as PEX by our `Makefile` install rule. They are then added to your $PATH upon sourcing a generated `activate.sh` script.

## Requirements

### RSA Key for ssh

The use of ssh to deploy software inside VMs relies on having generated a RSA key in the user environment (~/.ssh/id_rsa.pub).
If it does not exist, you can create one :
```sh
ssh-keygen  ### When prompted, use the provided default values (just press Return key)
```

### Python and PEX
This repository leverages python pex. We recommand the use of [pyenv](https://github.com/pyenv/pyenv). 
If not familiar with python installation and best practices refer to 
[Setup Python](https://doc.punchplatform.com/Contribution_Guide/Setup_Python.html). 

Here is a safe and clean procedure to setup your python environment: first 
create and activates a new virtualenv and call it (say) punchbox
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

If you plan to use vagrant install [vagrant](https://www.vagrantup.com/downloads.html) and [virtualbox](https://www.virtualbox.org/). 

```sh
# once vagrant is installed, run the rule below
make vagrant-dependencies
```

## Installation 

Install the punchbox tool by simply typing :

```sh
make install
source activate.sh
```

Check everything is correctly setup by executing the punchbox command:
```sh
punchbox -h
```

## File Organisation

Here is the punchbox folder layout. 

```sh
.
├── Makefile
├── README.md
├── bin
│   └── the punchbox utility plus a few extra commands including ansible
├── configurations
│   └── some ready to use boxes with or without punch layout models
├── ansible
│   └── some ready to use ansible roles to create reference servers
├── kast
│   └── the kubernetes resources to deploy a production-ready punch, or simply play with kast.
├── punch
│   └── the punch resources to deploy a production-ready punch in minutes
├── requirements.txt
└── vagrant
    └── vagrant resource to create the server infrastructure
```

## Deploy a Punch

To deploy a punch do the following. First pick your punch deployer and topology (checkout the ones available) and generate a descriptor yml file required by the deployer.
Save that file somewhere.
```sh
punchbox generate descriptor \
  --deployer ~/punch-deployer-6.3.0-SNAPSHOT \
  --topology punchbox/configurations/kafka_cluster_topology.yml \
  > ~/workspace/descriptor.yml
```


## Generate Bare Linux Vagrant Boxes

A first basic requirement is to generate one or several linux boxes. You will find some
simple models in the configurations folder. For example to generate 
three ubuntu servers for testing things on a 16Gb laptop use the following:

```sh
punchbox --platform-config-file configurations/empty_16G.json --generate-vagrantfile
```

You then have you Vagrantfile generated. To also start these servers you can type in:

```sh
punchbox --platform-config-file configurations/empty_16G.json \
        --generate-vagrantfile \
        --start-vagrant
```

or simply go to the vagrant directory and type in:

```sh
vagrant up
```

The way it works is to start with some very simple model files for you to specify what you need. 
Here the configurations/empty_16G.json example:

```json
{
  "targets": {
    "info": {
      "server1": {
        "disksize": "20GB",
        "memory": 3000,
        "cpu": 2,
      },
      "server2": {
        "disksize": "20GB",
        "memory": 5120,
        "cpu": 2
      },
      "server3": {
        "disksize": "20GB",
        "memory": 5120,
        "cpu": 2
      }
    },
    "meta": {
      "os": "ubuntu/bionic64"
    }
  }
}
```

For another os simply update the meta os properties. For example "bento/centos-8". 

## Deploy a KAST Kubernetes cluster

[Kast](https://gitlab.thalesdigital.io/sixdt/kast) is a thales initiative taht provides an easy to deploy production kube stack that includes
many useful cots such as elasticsearch, kafka, spark etc.. 

Checkout the [kast](./kast/README.md) guide to deploy a Kast cluster onto vagrant. In turn you will be
able to install a punch on top of it. 

***info*** : this part is subject to hot activities. The punch is in the process of integrating kast as its
core runtime stack. It will soon become an integrated part of the punch. 

## Punch Reference Servers

This part lets you create plain unix servers with all the prerequisites to (i) setup a punch deployer server and/or (ii) setup a punch platform target server.

Depending on your goal the prerequisites are differnt. A punch deployer server needs for example ansible, jq, unzip python etc .. Instead a punch target server (i.e. where you deploy and run punch apps and services) require  mainly python 3. 

The ansible roles defined in this part are free to use and lets you setup these target in minutes. 

Refer to the [ansible](./ansible/README.md) guide.  

## Deploy a Complete Punch

The punch deployment is performed in a way similar than what is just explained to deploy empty servers.
You simply use layout configuration file with the punch components you need. This repository provides
three ready-to-use complete punch configurations to accomodate 16Gb, 32Gb laptops and security settings. 

Also provided is a great tool to perform an end-to-end validation of the punch. 

**warning**: this part requires you have an official punch deployer package. 

Refer to the [punch](./punch/README.md) guide.  

## Contribute

This repository is licensed under the ApacheV2 license, please feel free to contribute. 
Only the punch itself is submitted to license, but is not necessary to use the vagrant or kube 
parts.

## Troubleshooting

Refer to the [troubleshooting](./Troubleshooting.md) documentation if you encounter some problems:
