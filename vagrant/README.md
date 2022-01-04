## Why Vagrant ?

Vagrant makes it easy to deploy a punch. This is useful both for testing the deployer and testing some punch specific
features.

Vagrant has two key strengths to help us developers. First it lets us work offline. On a decent laptop it is possible to
work with one to five vagrant boxes to deploy various setups of the punch. In most case two are enough.

Second vagrant makes it easy to share a folder bewteen the host and the box. That is also easy to quickly patch a box
whenever we investigate a bug, or to design a poc.

All in all this makes it easy to test the punch deployment role using a unit test approach.

> **Note**: the steps explained here follow the punch documentation

- [official version](https://doc.punchplatform.com/Operations/Platform_Deployment/Before_You_Start.html#deployer_installation_guide)
  .

## Disable SSH host key checking

This method tricks SSH by configuring it to use an empty known_hosts file, and NOT to ask you to confirm the remote host
identity key.

Edit (or create) your `~/.ssh/config` file and add section below.

```bash
# Vagrant VM
host 192.168.128.* server*
user vagrant
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
```

## Format and mount additional disk

Get disks list:

```sh
sudo fdisk -l | grep '^Disk'
```

```
Disk /dev/sda: 42.9 GB, 42949672960 bytes, 83886080 sectors
Disk label type: dos
Disk identifier: 0x000a05f8
Disk /dev/sdb: 5368 MB, 5368709120 bytes, 10485760 sectors
```

Partition the new disk using fdisk command

```sh
sudo fdisk /dev/sdb
```

```
Command (m for help): n
Select (default p): 
Partition number (1-4, default 1): 
Command (m for help): w
```

Format the new disk using mkfs.ext4 command

```sh
sudo mkfs.ext4 /dev/sdb
```

```
mke2fs 1.42.9 (28-Dec-2013)
/dev/sdb is entire device, not just one partition!
Proceed anyway? (y,n) y
```

Mount the new disk using mount command First create a mount point /disk1 and use mount command to mount /dev/sdb1,
enter:

```sh
sudo mkdir /disk1
sudo mount /dev/sdb /disk1
df -H
```

Update /etc/fstab file

```sh
sudo vi /etc/fstab
```

```
/dev/sdb               /disk1           ext3    defaults        1 2
```

## Vim syntax highlighting for Vagrantfile

Create `~/.vim/plugin/vagrant.vim` and drop content bellow:

```
" Teach vim to syntax highlight Vagrantfile as ruby
"
" Install: $HOME/.vim/plugin/vagrant.vim
" Author: Brandon Philips <brandon@ifup.org>

augroup vagrant
  au!
  au BufRead,BufNewFile Vagrantfile set filetype=ruby
augroup END
```

