# Punch Integration Tools

This repository provides easy tools to deploy plain servers, kubernetes clusters and/or
punchplatforms in production-ready setups. It is designed to do all that on a single laptop.

Note that this repository follows the punch branch naming convention. The 5.7 branch should be used to deploy 5.7 punch, the 6.0 to deploy a 6.0 etc. If you do not plan to install punch but only kube or vagrant boxe this does not matter to you. Simply stick to the
default branch. 

WATCHOUT: there is realy only one thing to understand : once installed, this repository will install a local python environment
using pyenv. As part of that environment the right version of ansible is installed, cleanly packaged as a pex executable.
This is to ensure you all have the right ansible version. That particular version of ansible will be put in front of your 
PATH environment variable so as to make sure it is the one used. 


## Requirements

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

You are all set. 

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
│   └── some ready to use ansible roles
├── kube
│   └── the kubernetes resources to deploy a production-ready punch, or simply play with kube.
├── punch
│   └── the punch resources to deploy a production-ready punch
├── requirements.txt
└── vagrant
    └── vagrant resource to create the server infrastructure
```

## Generate Bare Linux VMs

A first basic requirement is to generate one or several linux boxes. You will find some
simple models in the 'configurations' folder. For example to generate 
three servers for testing things on a 16Gb laptop use the following:

```sh
punchbox --config configurations/empty_16G.json --generate-vagrantfile
```

You then have you Vagrantfile generated. To also start these servers you can type in:

```sh
punchbox --config configurations/empty_16G.json \
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

## Deploy a production Kubernetes Cluster

Punch can be deployed on a kube platform as long as it contains the required Kafka, Elasticsearch etc.. 
Checkout the [kube](./kube/README.md) guide to install such a production kube equipped with the required COTS.

Note that this is fun even if you do not want to put a punch on top of it. It shows how simple it is to
deploy a complete kube platform using [kube_spray](https://github.com/kubernetes-sigs/kubespray).

***info*** : this part is subjected to hot activities. It will soon become an integrated part of the punch. 

## Create Punch-Ready Bare OS servers

This part lets you create plain unix servers with all the prerequisites to (i) setup a punch deployer server and/or (ii) setup a punch platform target server.

Depending on your goal the prerequisites are differnt. A punch deployer server needs for example ansible, jq, unzip python etc .. Instead a punch target server (i.e. where you deploy and run punch apps and services) requires  mainly python 3. 

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
