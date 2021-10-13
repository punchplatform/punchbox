# Punch Config

This folder provides easy tools and samples to deploy and to validate a complete Punch with different configurations. It
is necessary for you to have an official punch deployer package, which only comes with a license. Get in touch with the
punch team if you are interested in exploring the punch.

If you are new to the punch here a few important and essential concepts :

* a punch **platform** is a punch you deploy on one or several servers. A food idea is to start with vagrant boxes. A
  platform only consists in the components you decided to deploy such as elasticsearch, clickhouse, S3 etc.. but has no
  application yet. I.e. it is empty.
* a punch *user configuration*  (simply referred to as *configuration*) is where you define your applications. A punch
  configuration consists in
    - one or several *tenants*
    - in each tenant, one or several *channels*
    - in each channel, one or several *applications*
* *resources* are static configuration files that are often used along with your configuration. Resources are:
    - certificates
    - kibana dashboards and elasticsearch mappings
    - enrichment files like geoip database file
    - machine learning models
    - etc..

The Punch applications are particular in that they are expressed using simple (json or hjson) configuration files. Of
course all these are explained in details on the punch [online documentation](https://doc.punchplatform.com).

Have a look at the configurations/sample folder. It defines a minimalistic application that consists in a single *
sample* tenant, that contains a single *sample* channel, that contains a sample application which receives logs on the
9999 tcp port, and simply print them to stdout.

A few ready-to-be-used deployment configurations are available. It is best to start from these:

* punchbox-ubuntu-32G (or punchbox-ubuntu-16G) deploy a fairly complete punch with the full combo: storm spark shiva
  kafka elastic etc..

If you want to deploy on Redhat platform, you need a Redhat licence or a
free [RHEL developer subscription](https://developers.redhat.com) that are limited to 20 VMs per account. During the
installation the Makefile will ask you your credentials to register VMs on account. When you delete your VMs, they will
automatically unregister from your account.

> :warning: If you want to delete Vagrant Vms based on Redhat, you need to use make clean instead of manually delete to also delete the licence associated to your Vms

## Punchplatform validation

Once you have deployed your Punchplatform, you may be wondering how to check your platform health

Refer to the [validation](./configurations/validation/README.md) guide. 
