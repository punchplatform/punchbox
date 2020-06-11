# Troubleshooting

## Vagrant was unable to mount VirtualBox shared folders

Appears when the following error occurs:

```sh
Error
mount -t vboxsf -o uid=1000,gid=1000 home_vagrant_public_html_apps /home/vagrant/public_html/apps

The error output from the command was:
mount: unknown filesystem type ‘vboxsf'”
```

There are two ways you can fix this problem:

* Install the vagrant vbguest plugin: vagrant plugin install vagrant-vbguest.
* Make sure you’re running the latest box version. Update by running vagrant box update.

## Sync folder for configuration is empty after reboot

Execute the followning command on the host :

```sh
vagrant reload
```

## Wrong interface returned by the generated interface

Try to generate the configurations and the vagrant file again, without starting vagrant :

```sh
punchbox --config configurations/complete_punch_16G.json \
        --generate-vagrantfile \
        --punch-conf <path/to/existing/conf>
        --deployer ~/pp-punch/pp-packaging/punchplatform-deployer/target/punchplatform-deployer-*.zip \
```