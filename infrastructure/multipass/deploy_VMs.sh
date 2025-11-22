#!/usr/bin/env bash
# When VMs are deleted, IPs remain allocated in DHCPDB

set -euo pipefail

# Setting colors
RED="\033[1;31m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
NC="\033[0m"


# Define VMs specs
vm_specs=../../tmp/vm_specs
cat <<EOF > $vm_specs
controlplane01,2,2048M,10G
node01,3,6144M,20G
ingress,1,2048M,5G
EOF

echo -e "${GREEN}Booting the nodes...${NC}"

# Boot the nodes
for vm in $(cat $vm_specs)
do
  node=$(cut -d ',' -f 1 <<< $vm)
  cpus=$(cut -d ',' -f 2 <<< $vm)
  ram=$(cut -d ',' -f 3 <<< $vm)
  disk=$(cut -d ',' -f 4 <<< $vm)

  # Checking if there are any running VMs, if yes, delete them
  if multipass list --format json | jq -r ".list[].name" | grep $(cut -d ',' -f 1 <<< $node) > /dev/null
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
hostentries=../../tmp/hostentries
> $hostentries

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
  node=$(cut -d ',' -f 1 <<< $spec)
  multipass transfer $hostentries $node:/tmp/
  multipass transfer ./scripts/setup_host.sh $node:/tmp/
  multipass transfer ./scripts/cert_verify.sh $node:/home/ubuntu/
  multipass transfer ./scripts/setup_kernel.sh $node:/tmp/
  multipass transfer ./scripts/k8s_dependencies.sh $node:/tmp/
  # Execute setup host script on each node
  multipass exec $node -- chmod +x /tmp/setup_host.sh
  multipass exec $node -- /tmp/setup_host.sh

  # Execute setup kernel script on each node
  multipass exec $node -- chmod +x /tmp/setup_kernel.sh
  multipass exec $node -- /tmp/setup_kernel.sh

  # Install k8s dependencies on each node
  multipass exec $node -- chmod +x /tmp/k8s_dependencies.sh
  multipass exec $node -- /tmp/k8s_dependencies.sh
done

# Config CSR on the controlplane nodes
multipass transfer ./scripts/approve_csr.sh controlplane01:/home/ubuntu/

echo -e "${GREEN}Done!${NC}"

