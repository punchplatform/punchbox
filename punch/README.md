# Punchplatform Integration

This folder provides easy tools to deploy and to validate a complete Punchplatform with different configurations 

**Warning**

  - This version is a Beta
  - Alpha version named 6.1 will be released mid-June
  - Validation section use standalone and punchbox resources, it will be fixed soon to be more flexible
  - Requires hardcode configuration : SLACK_WEBHOOK environment variable set with specific slack webhook URL
  
## File Organization

```sh
.
├── README.md
├── platform_template
│   └── Punchplatform configuration template
├── resources
│   └── some resources necessary to deploy a Punchplatform
├── validation
│   └── validation tools and resources
├── build
    └── temp files 
```

## Punchplatform deployment

Assumming you also have the pp-punch punch repository somewhere (say `~/pp-punch`)
type in the following command: (remove the --start-vagrant to no start the vagrant boxes)

```sh
punchbox --config configurations/complete_punch_16G.json \
        --generate-vagrantfile \
        --punch-conf ~/pp-punch/pp-packaging/punchplatform-standalone/target/tmp/punchplatform-resources-*/conf/ \
        --deployer ~/pp-punch/pp-packaging/punchplatform-deployer/target/punchplatform-deployer-*.zip \
        --start-vagrant
```

This will unzip the punch deployer archive, as well as the sample standalone channels so that you will have a complete
sample application deployed on your punch.

Once that done go on and generate the punch deployment files. You dop that using the `punchplatform-deployer.sh`
tool that is now available to you. 

```sh
source $PUNCHBOX_DIR/activate.sh
punchplatform-deployer.sh --generate-platform-config \
    --templates-dir $PUNCHBOX_DIR/punch/platform_template/ \
    --model $PUNCHBOX_DIR/punch/build/model.json
punchplatform-deployer.sh -gi
``

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

If you made a error in your user config file for example, you might want to regenerate configuration file without dealing another time with vagrant boxes. For that use `punchbox` without vagrant options: 

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

## Punchplatform validation  

Once you have deployed your Punchplatform, you may be wondering how to check your platform health

Refer to the [validation](./validation/README.md) guide. 