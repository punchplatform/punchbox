# Punch Integration Tools

This repository provides tools to deploy plain servers, kubernetes clusters and/or
punch based platform in a production-ready setup. Most of these tools should be able to run on machine having at least 16GB of ram memory. 
But is very useful should you have VMs or physical servers as well.

This repository follows the punch branch naming convention. 



**Behind the scene**

We use `pyenv` to install the exact python version we depend on ~ **3.6.8**.

A virualenv directory is created at the root of this repository on your local filesystem, containing required python modules for the punchbox to be functional.

## Requirements

### RSA Key for ssh

You MUST have ssh keys inside *~/.ssh/id_rsa.pub*.  
if not, generate one with:

```sh
### When prompted, use the provided default values (just press Return key)
ssh-keygen  
```

### Python

Install [pyenv](https://github.com/pyenv/pyenv).   

If not familiar with python installation and best practices refer to 
[Setup Python](https://doc.punchplatform.com/Contribution_Guide/Setup_Python.html).

### Environment

Clone the `pp-punch` repo next to `punchbox` :

```sh
.
├── pp-punch
└── punchbox
```

If you already have a `pp-punch` folder elsewhere, store its location in `PUNCH_DIR`:

```sh
echo "export PUNCH_DIR=/path/to/pp-punch >> ~/.bashrc"
source ~/.bashrc
```

### Punch

You MUST have compiled a punch version in `pp-punch`.

## Installation 

Install your punchbox environment and the deployer with :

```sh
make install
```

Now you are ready to get started !

## Generate Bare Linux Vagrant Boxes

Use the default vagrant configuration provided by punchbox :

```sh
source activate.sh
punchbox --config configurations/vagrant_config.json
```

or simply go to the vagrant directory and type in:

```sh
make start-vagrant
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
