# FAQ

## Why a Punchbox ?

The punchbox is very useful to:

* support teams: punchboxes are used to test platforms representative of real clients platforms 
* validation teams: the punch team use the punchbox to play release and integration tests
* development teams: having a punchbox at hand makes it easy to develop distributed applications.

## Why not MiniKube ? Kind ? Kast-All-In-One ? Vagrant ?

* Minikube is kubernetes centric and too simple (single node)
* Kind is great for automated K8 CI/CD tests. We use it for that. But only for that.
* Vagrant: vagrant is actually used by the punchbox. Vagrant alone is too low level.  
* Kast-All-In-One: is a great and very similar tool. We plan to use it and probably replace the punchbox in the future. The rationale of maitaining the punchbox is to keep supporting non Kubernetes projects and to keep leveraging the punch validation apps.

## What tools/binary is actually delivered ?

After a 'make install' two binaries are provided:

* ansible : so that you do not have to provide it yourself. We make sure the right ansible version is packaged for you.
* punchbox : a small python app that provide various helper subcopmmands. Check 'punchbox -h'. 

Note however that you can completly ignore these two apps and only use the top level Makefile.

## What can a Punchbox do ?

* create a set of VMs
* deploy various models of punch on these VMs
* deploy a Kast Kubernetes cluster on top of these VMS.
* run punch validation campaigns

## Is the Punchbox useful to Punch Customers ?

Yes. It is an easy and well documented way to learn how to deploy a punch.

## Is the Punchbox specific to Punch ?

No but the primary goal of the Punchbox is indeed to allow the punch 
professional and development teams to support customers and validate 
releases. 

## What is the Branch Usage ?

This repository follows the punch branch naming convention.
For instance, this repository 5.7 branch should be used to deploy the same version of 
punch (5.7), the 6.0 to deploy a 6.0 etc. If you do not plan to install punch but only 
kube or vagrant boxes, stick to the latest stable branch.

## What is the File organisation ? 

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
