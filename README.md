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


### Do Once : 

Setup a PAT (Personal access token) with access to the repos and orgs you want serviced. 
https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token
- Enable the following scopes:
	- repo
	-  workflow
	-  admin:org
	-  admin:repo_hook



# Starting some runners

## If you ar comfortable with sharing your PAT with your working server, do the following

### Prepare the base-container :
Prepare the LXD container with all its depedencies 
(You might need to modify this to fit your needs)
```
./prepare-instance gh-runner
```
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


## If you need to secure your PAT, use the following solution:

! Fork the project, so github can run your workflows

### 1) Prepare the base-container :

Prepare the LXD container with all its depedencies 
(You might need to modify this to fit your needs)
```
./prepare-instance gh-runner-{repo-name}
```

### 2) Setup a scheduled workflow to update the registration-token of your runner regularly :

- You need to configure your work-server so that it can be access via ssh by user and private key (without password)
- Create the following 4 secrets in the forked github repo `GH_PAT, GH_RUNNER_HOST, GH_RUNNER_USER, GH_RUNNER_PRV_KEY`

The workflow I use to run my self-hosted runners can be found [here](https://github.com/gr0vity-dev/lxd-github-runner/blob/master/.github/workflows/auto_renew_runner_token.yml) 
You can simply modify the above workflow to fit your needs.

Here is a simplified example
```
name: Renew ephemeral self-hosted runner token
on:
  schedule:
    - cron: '0/30 * * * *'  # "every 30 minutes
jobs:
  renew_gh-runner_token:
    name: renew reg token
    runs-on: ubuntu-latest
    steps:
      - name: Convert PAT into registration-token
        id: get_token
        run: |          
          GH_RUNNER_TOKEN=$(curl \
          --location --request POST 'https://api.github.com/repos/{OWNER}/{REPO}/actions/runners/registration-token' \
          --header 'Authorization: Bearer ${{ secrets.GH_PAT }}' \
          | jq -r '.token')
          echo "::add-mask::$GH_RUNNER_TOKEN"
          echo "::set-output name=GH_RUNNER_TOKEN::$GH_RUNNER_TOKEN"

      - name: Execute remote ssh commands using user and private key
        uses: appleboy/ssh-action@v0.1.7
        with:
          host: ${{ secrets.GH_RUNNER_HOST }}
          username: ${{ secrets.GH_RUNNER_USER }}
          key: ${{ secrets.GH_RUNNER_PRV_KEY }}
          script: ./git/lxd-github-actions/renew_runner_token {work-server-gh-runner-name} https://github.com/{OWNER}/{REPO} ${{ steps.get_token.outputs.GH_RUNNER_TOKEN }}
```

This workflows runs every 30 minutes and makes sure that the base-container always has a valid registration token by
- converting your PAT into a registration-token for your self-hosted runner
- ssh'ing into your workserver and update registration-token inside the base-container

The following repo secrets need to be defined for the workflow to run properly:
- secrets.GH_PAT (your personal access token used to create a registration-token for your repo)
- secrets.GH_RUNNER_HOST (work server ip address)
- secrets.GH_RUNNER_USER (work-server user)
- secrets.GH_RUNNER_PRV_KEY (private key to ssh into the workserver)

Additionally make sure to replace the following variables with the relevant content:
- {OWNER} # your github user
- {REPO} # your repo that requires the self-hosted runner
- {work-server-gh-runner-name} # the gh-runner name you defined when running the `prepare-instance` script.

### 3) Create and renew self-hosted runners as soon as a workflow has finished

*Run the respawn_runners script as a cronjob to make sure you always have available runners*
```bash 
$ crontab -e
## Add the following line as cronjob. Replace the path and RUNNER_COUNT (=parallel runners)
* * * * * /path/to/lxd-runner/respawn_runners gh-runner-{repo-name} RUNNER_COUNT https://github.com/ORG/REPO
``` 
! **Make sure** to replace the following variables in the above cronjob:
```
gh-runner-{repo-name} # the name of your base-container used when running  ./prepare-instance
ORG (your github user)
REPO (your github repo that nees the self-hosted runner)
``` 
