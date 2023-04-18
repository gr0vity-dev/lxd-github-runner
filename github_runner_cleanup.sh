#!/bin/bash

# list all active LXC containers that start with "github-"
containers=$(lxc list --format=json | jq -r '.[] | select(.status=="Running" and (.name | test("^github-.*"))) | .name')

# loop through the list of containers and check the status of the "github-actions.service" service
for container in $containers
do
  # execute the command in the container and check the output for the "Failed" status
  status=$(lxc exec "$container" -- systemctl status github-actions.service | grep "Listening for Jobs" | wc -l)
  
  # if the service has failed, stop the container
  if [ "$status" -eq "0" ]; then
    lxc stop "$container"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container $container has been stopped."
  fi
done
