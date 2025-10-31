#!/usr/bin/bash
# When VMs are deleted, IPs remain allocated in DHCPDB

set -euo pipefail

vm_specs=/tmp/vm_specs
cat <<EOF > $vm_specs
controlplane01,2,2G,10G
controlplane02,1,2G,5G
node01,2,4G,20G
ingress,1,512M,5G

# Boot the nodes
for vm in $(cat $vm_specs)
do
  node=$(cut -d ',' -f 1 <<< $vm_specs)
  cpus=$(cut -d ',' -f 2 <<< $vm_specs)
  ram=$(cut -d ',' -f 3 <<< $vm_specs)
  disk=$(cut -d ',' -f 4 <<< $vm_specs)

  multipass launch --disk $disk --memory $ram --cpus $cpus --name $node jammy
done


