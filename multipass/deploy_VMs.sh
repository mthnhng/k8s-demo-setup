#!/usr/bin/bash
# When VMs are deleted, IPs remain allocated in DHCPDB

set -euo pipefail

# Setting colors
RED="\033[1;31m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
NC="\033[0m"


# Define VMs specs
vm_specs=/tmp/vm_specs
cat <<EOF > $vm_specs
controlplane01,2,2G,10G
controlplane02,1,2G,5G
node01,2,4G,20G
ingress,1,512M,5G
EOF

echo -e "${GREEN}Booting the nodes...${NC}"

# Boot the nodes
for vm in $(cat $vm_specs)
do
  node=$(cut -d ',' -f 1 <<< $vm_specs)
  cpus=$(cut -d ',' -f 2 <<< $vm_specs)
  ram=$(cut -d ',' -f 3 <<< $vm_specs)
  disk=$(cut -d ',' -f 4 <<< $vm_specs)

  # Checking if there are any running VMs, if yes, delete them
  if multipass list --format json | jq -r "list[].name" | grep $(cut -d ',' -f 1 <<< $node) > /dev/null
  then
    echo -e "${RED}Deleting node ${node}...${NC}"
    multipass delete $node
    multipass purge
  fi
  
  echo -e "${BLUE}Launching ${node}. CPU: ${cpus}, MEM: ${ram}${NC}"
  multipass launch --disk $disk --memory $ram --cpus $cpus --name $node jammy
  echo -e "${GREEN}$node booted!${NC}"
done

# Create host file entries
echo -e "${BLUE}Provisioning...${NC}"
hostentries=/tmp/hostentries
[ -f hostentries ] && rm -f $hostentries

# Add ips to /etc/hosts
for spec in $(cat $vm_specs)
do
    node=$(cut -d ',' -f 1 <<< $spec)
    ip=$(multipass info $node --format json | jq -r 'first( .info[] | .ipv4[0] )')
    echo "$ip $node" >> $hostentries
done

# Set up nodes
for spec in $(cat $vm_specs)
do
    node=$(cut -d ',' -f 1 <<< $vm_spec)
    multipass transfer $hostentries $node:/tmp/
    # multipass transfer $SCRIPT_DIR/01-setup-hosts.sh $node:/tmp/
    # multipass transfer $SCRIPT_DIR/cert_verify.sh $node:/home/ubuntu/
    # multipass exec $node -- /tmp/01-setup-hosts.sh
done

# Config CSR on the controlplane nodes
multipass transfer $TOOLS_DIR/approve-csr.sh controlplane01:/home/ubuntu/

echo -e "${GREEN}Done!${NC}"
