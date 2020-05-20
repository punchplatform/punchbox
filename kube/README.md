# Punch Kubernetes Deployment

Here are some instructions to deploy a kubernetes cluster equipped
with some interestings COTS.  

## Kubernetes Cluster Setup

To deploy a Kubernetes you need a cluster of linux servers, 
up and running. This guide works with on premise and on cloud.

If you do not have a cluster yet, simply use the punchbox tool:
to create s small vagrant cluster. 

```sh
punchbox --config configurations/empty_16G.json
 --generate-vagrantfile \
 --start-vagrant
```

If you need more ressources (ram or cpu) use empty_32G.json or create your own
model. 

Note that the punchbox tool takes care of the ssh setup bewteen the boxes. If
you are on your own you need to add the ssh key of the 
deployer on each cluster node. Generating a ssh key without passphrase 
is recommended and a lot easie.

## Kubespray Setup

### Prerequisites

-   **Minimum required version of Kubernetes is v1.16**
-   **Ansible v2.9+, Jinja 2.11+ and python-netaddr is installed on the machine that will run Ansible commands**
-   The target servers must have  **access to the Internet**  in order to pull docker images. Otherwise, additional configuration is required (See  [Offline Environment](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/downloads.md#offline-environment))
-   The target servers are configured to allow  **IPv4 forwarding**.
-   **Your ssh key must be copied**  to all the servers part of your inventory.
-   The  **firewalls are not managed**, you'll need to implement your own rules the way you used to. in order to avoid any issue during deployment you should disable your firewall.
-   If kubespray is ran from non-root user account, correct privilege escalation method should be configured in the target servers. Then the  `ansible_become`  flag or command parameters  `--become or -b`  should be specified.

Hardware: These limits are safe guarded by Kubespray. Actual requirements for 
your workload can differ. For a sizing guide go to the  
[Building Large Clusters](https://kubernetes.io/docs/setup/cluster-large/#size-of-master-and-master-components)  
guide.

-   Master
    -   Memory: 1500 MB
-   Node
    -   Memory: 1024 MB


### Install Kubespray

```sh
git clone https://github.com/kubernetes-sigs/kubespray 
cd kubespray 
sudo pip install -r requirements.txt
```

### Create a punch kubespray configuration

```sh
cp -rfp inventory/sample inventory/punch
```

### Declare the ip addresses of your nodes
```sh
declare -a IPS=(172.28.128.21 172.28.128.22 172.28.128.23 )
```

### Generate an Ansible inventory based on declared IPs

```sh
CONFIG_FILE=inventory/punch/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```

### Review and change parameters 

The various variables are located under ``inventory/punch/group_vars``

```sh
cat inventory/punch/group_vars/all/all.yml
cat inventory/punch/group_vars/k8s-cluster/k8s-cluster.yml
```
You can customize your kubernetes deployement or use the generated configuration. If you want to administrate your kubernetes cluster with kubectl, kubespray can copy the required configuration on your host. 

To benefit from that update the following parameters in ``group_vars/k8s-cluster/k8-cluster.yaml``

```yaml
# Make a copy of kubeconfig on the host that runs Ansible 
# in {{ inventory_dir }}/artifacts
kubeconfig_localhost: true
# Download kubectl onto the host that runs Ansible in {{ bin_dir }}
kubectl_localhost: true
```

-   If  `kubectl_localhost`  is enabled,  `kubectl`  will be downloaded and installed into  `/usr/local/bin/`  and setup with 
bash completion. A helper script  `inventory/mycluster/artifacts/kubectl.sh`  will also be created and setup with `admin.conf` described hereafter.
-   If  `kubeconfig_localhost`  is enabled  an `admin.conf`  file will appear in the  `inventory/mycluster/artifacts/`  
directory after deployment.
-   You can change these files installation folders using the  `artifacts_dir` variable.

If desired, copy admin.conf to ~/.kube/config.


### Deploy your kubernetes cluster

```sh
ansible-playbook -i inventory/punch/hosts.yaml --become -u vagrant cluster.yml
```

After some times you will have a kubernetes cluster ready to use. 
If you have ``kubectl_localhost`` and ``kubeconfig_localhost`` you can 
administrate your cluster with ``kubectl.sh`` in artifact directory  or copy 
the file ``admin.conf`` in to use your kubectl already installed.

### Test your Kubernetes Cluster

```sh
cd inventory/clusterPunch/artifacts
./kubectl.sh get nodes
```

