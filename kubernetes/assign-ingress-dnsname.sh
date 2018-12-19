#!/bin/bash

set -e

# Public IP address of your ingress controller
IP="${1}"

# Name to associate with public IP address
DNSNAME="${2}"

# Get the resource-id of the public ip
PUBLICIPID=$(az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$IP')].[id]" --output tsv)

# Update public ip address with DNS name
az network public-ip update --ids $PUBLICIPID --dns-name $DNSNAME
