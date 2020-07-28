# Ansible roles 

Here you can find some useful ansible roles. Each is autonomous. 
Each role contains a specific README which describes mandatory variables to declare in your ansible inventory. 

Make sure you use these roles if you are in charge of operating/deploying or upgrading a production punch. 

## Punch Compilation Environment

Use the "punch-development"  role to equip a server, laptop or vm with the punch compilation prerequisites. For developers only.

## MiniKube

Install quickly a mono kube on your laptop. For developers or testers. 

## Punch Deployer 

Use the "punch-deployer" role to install the necessary requirements for deploying a punch. These are thus what you need on your deployer server (laptop or vm). Not the target punch servers. 

## Punch Raw Node 

Use the "punch-node" role to generate the raw unix node with the required punch prerequisite. 
These raw nodes are they ready to be used for deploying a complete punch. 


