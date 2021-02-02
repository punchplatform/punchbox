#  Kast Deployment

This guide helps deploying a kast cluster onto vagrant boxes. Kast requires a cluster of
centos or redhat servers. We will simply use the punchbox tool to create that cluster, then
install kast onto it. 

## Prepare the VMs

Simply follow the punchbox vagrant guide to deploy a linux cluster. 
Make sure you have a ssh key. You can disable the ssh host key checking
as explained [here](../vagrant/README.md). 

As an example select the 16G template, make sure you use a
supported os (for example "bento/centos-8") amd generate your vagrantfile using :

```sh
punchbox --platform-config-file configurations/empty_16G.json --generate-vagrantfile
```

That create a vagrant/Vagrantfile file. Start your servers:

```sh
cd vagrant
vagrant up
```

Check you can reach your boxes without passwords.

```sh
ssh vagrant@server1
ssh vagrant@server2
ssh vagrant@server3
```

##  Deploy Kast

[Kast](https://gitlab.thalesdigital.io/sixdt/kast)) stands for Kubernetes Analytics Stack. 
It is a Thales project that allows you to bootstrap a Kubernetes cluster on cloud or on premise using the native kubeadm tool. To move on clone that repository :

```sh
git clone https://gitlab.thalesdigital.io/sixdt/kast
cd kast
```

Check out the [production kubernetes prerequisites](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/). Here are the essential minimal recommended setup:

-   One or more machines running a deb/rpm-compatible Linux OS; for example: Ubuntu or CentOS.
-   2 GiB or more of RAM per machine--any less leaves little room for your apps.
-   At least 2 CPUs on the machine that you use as a control-plane node.
-   Full network connectivity among all machines in the cluster. You can use either a public or a private network.

Once deployed the kubernetes core infrastructure will use the following networking configuration:

```/bin/sh
Control-plane node(s)

Protocol Direction Port Range Purpose Used By
TCP      Inbound   6443*      Kubernetes API server All
TCP      Inbound   2379-2380  etcd server client API kube-apiserver, etcd
TCP      Inbound   10250      Kubelet API Self, Control plane
TCP      Inbound   10251      kube-scheduler Self
TCP      Inbound   10252      kube-controller-manager Self
TCP      Inbound   10249      kube-proxy metrics port

Worker node(s)

Protocol Direction Port Range  Purpose Used By
TCP      Inbound   10250       Kubelet API Self, Control plane
TCP      Inbound   30000-32767 NodePort Services† All
```

### Step 1. Create the Kast Ansible hosts file

```sh
touch hosts
vim hosts
```

If your nodes have multiple network interface you need to specify the advertise address for this particular control-plane node API server, you can do this with the argument ``ìnternal_address``

example  :

```ini
[kube_master]
server1 internal_address=172.28.128.21

[kube_worker]
server2
server3
```


### 2. Bootstrap your kubernetes cluster

To bootstrap your Kubernetes cluster you need to run 3 ansible role :

 - `preflight.yml` : it will apply some basic nodes configuration
 - `containerd_runtime_install.yml` : This role will basically run accross all worker and master nodes and setup a container runtime for kubernetes
 - `kube.yml` : it will install Kubernetes composant

You can choose Kubernetes composants like Pod network add-on by modify the file ``role/kube/boot/default/main.yml``


#### Run role preflight

```sh
ansible-playbook -i hosts preflight.yml -u vagrant
```
If your use a custom ssh key pair : 
```sh
ansible-playbook -i hosts preflight.yml -u vagrant --private-key=path/to/your/ssh/private/key
```

#### Run role containerd_runtime_install 
```sh
ansible-playbook -i hosts containerd_runtime_install.yml -u vagrant
```
If your use a custom ssh key pair : 
```sh
ansible-playbook -i hosts containerd_runtime_install.yml -u vagrant --private-key=path/to/your/ssh/private/key
```

#### Run role kube 
Before run the kube role you need to set the parameter `nic` with the network card to be use by your kube cluster. If you use a Vagrant cluster or punchbox you need to set this parameter to `nic: eth1`.

The configuration file is `/roles/kube/boot/defaults/main.yml`

```yml
# Network card to use for internal
# can be: first-found, for first non loopback or name like eth0
# default first-found
nic: eth1
```

Then you can run the role to deploy your cluster Kubernetes.

```sh
ansible-playbook -i hosts kube.yml -u vagrant
```
If your use a custom ssh key pair : 
```sh
ansible-playbook -i hosts kube.yml -u vagrant --private-key=path/to/your/ssh/private/key
```

### 3. Test your Kubernetes cluster

#### Connect  to one master node

```sh
ssh vagrant@server1
```

And run following commands : 

```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
```

#### Run kubectl command

```sh
kubectl get pods --all-namespaces -o wide
```

#### Expected result

![](./images/test_kube.gif)

### 4. Run kubectl commands from your laptop

if you want to run kubectl command directly from you laptop, you need to install kubectl and run following commands :


#### Install kubectl
```sh
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
```

#### Retrieve kubeconf file from a master node
```sh
scp vagrant@server1:/home/vagrant/.kube/config $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
```

If your use a custom ssh key pair : 

```sh
scp -i /path/to/your/private/key vagrant@server1:/home/vagrant/.kube/config  $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
```

