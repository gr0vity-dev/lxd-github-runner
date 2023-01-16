# Introduction

Forked from https://github.com/stgraber/lxd-github-actions

This repository contains some scripts to create LXD instances suitable
to be used as Github Actions runners as well as tools to spawn a set of
such instances.

This will use LXD with a set of ephemeral instances which will then be
added as Github Runners. Each of those will process exactly one job and
then self-destroy. This is to avoid running jobs in unclean
environments, preventing one job from impacting or attacking the next.


# Installing LXD
```
sudo apt-get install lxd-client

lxd init
#you can use all the defaults

#Add new storge pool called docker (docker needs btrfs to work properly, so we named its storage pool docker)
#default size is 30GB. we increse it to 50GB for our need
lxc storage create docker btrfs size=50GB
```


# Creating a suitable base instance

For example, for an Ubuntu 20.04 container, you'd use:
```
lxc launch images:ubuntu/20.04 gh-runner
```

### Do Once : 

Setup a PAT (Personal access token) with access to the repos and orgs you want serviced. 
https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token
- Enable the following scopes:
	- repo
	-  workflow
	-  admin:org
	-  admin:repo_hook


Prepare the LXD container with all its depedencies 
(You might need to modify this to fit your needs)
```
./prepare-instance gh-runner
```

# Starting some runners

### Spawn LXD github-runners : 


```
./respawn gh-runner RUNNER_COUNT https://github.com/ORG/REPO PAT label1,label2
```

- gh-runner (or the name of your base container)
- RUNNER_COUNT : (number of gh-runners that will run in parallel)
- repository address
- PAT (starting with ghg_...)
- LABELS (optinal)

Create a cronjob that executes job above once per minute to respawn any number of missing runners :

``` bash
crontab -e
>>>
* * * * * /path/to/lxd-runner/respawn gh-runner RUNNER_COUNT https://github.com/ORG/REPO PAT 
```
