# Punchbox Integration Tools

Welcome to the punchbox project. It provides tools to easily deploy plain servers, kubernetes clusters and/or
punch platforms in a production-ready setup. 

These tools run fine on 16GB laptops. 32G is recommended. If you have one you will
be at ease to work locally, i.e. have a representative platforms completly running
on local VMS. 
This said; these tools are also very useful should you have (remote) VMs or physical servers.

On the rationale and other quick questions you may have: checkout the [FAQ](./FAQ.md). If you have issues refer to the [Troubleshootings](./Troubleshootings.md).

## Requirements

### RSA Key for ssh

Ansible (hence ssh) is used to deploy the punch software and cots onto the vagrant VMs. 
A RSA public key is required. By default your default key (/.ssh/id_rsa.pub). 

If it does not exist, create one:

```sh
ssh-keygen  ### When prompted, use the provided default values (just press Return key)
```

That key will be installed in the authorized_keys file of each VM. Right after your VMs are created, 
ensure you can successfully  ssh without password to each 
VM. I.e. :

```
ssh vagrant@server1
```
must succeed. Check out the [Troubleshootings](./Troubleshootings.md) in case of problem.

### Python 

[pyenv](https://github.com/pyenv/pyenv) is used to install the exact python version we depend on ~ **3.6.8**.

A virualenv directory is created at the root of this repository on your local filesystem, containing required python modules for the punchbox to be functional.

Some python module, such as ansible, are generated as PEX by our `Makefile` install rule. They are then added to your $PATH upon sourcing a generated `activate.sh` script.

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

## Usages

### Deploy a KAST Kubernetes cluster

Checkout the [kast](./kast/README.md) guide to deploy a Kast cluster onto vagrant. In turn you will be
able to install a punch on top of it. 

### Create Punch Reference Servers

Refer to the [ansible](./ansible/README.md) guide.  It contains a few ansible roles to create linux servers suited for a punch deployment. But only the linux server.

### Deploy a Complete Punch

Refer to the [punch](./punch/README.md) guide. To run validation tests, checkout out the [validation](./punch/configurations/validation/README.md) guide.

### Generate Plain Linux CLusters 

To generate one or several plain linux boxes, you will find some
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

## Contribute

This repository is licensed under the ApacheV2 license, please feel free to contribute. Only the punch itself is submitted to license, but is not necessary to use the vagrant or kube 
parts.