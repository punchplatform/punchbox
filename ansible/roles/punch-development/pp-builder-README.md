# Role to install all prerequisites to build pp-punch repository

## Required variables

pp_remote_data_dir: directory in which will be stored all data (e.g. /data)


## Troubleshooting on PunchBox

### Configure NAT 

To have a direct access to internet, example of /etc/netplan file :

```sh
    network:
    ethernets:
    # The primary (admin) network interface
       ens3:
             addresses: [10.10.13.199/16]
             dhcp4: no

    # The secondary (prod) network interface
       ens4:
             addresses: [20.20.13.199/16]
             dhcp4: no
       ens5:
             addresses: [192.168.122.199/24]
             dhcp4: no
             gateway4: 192.168.122.1
             nameservers:
                   addresses: [10.10.1.10]

    version: 2
```

### Build issues  

#### No Space left on device

Change working directory for PEX (Default to HOME dir), in bashrc : 
```sh
export PEX_ROOT=/data/
```

Change working directory for maven (Default to HOME dir), in bashrc : 

```sh
mvn clean install -Dmaven.repo.local=/data/.m2/repository
```

Change working directory for pip (Default to HOME dir), in bashrc : 

```sh
export PIP_CACHE_DIR=/data/.cache
```

#### Encoding 

Change default locale, in bashrc : 

```
export 
```
