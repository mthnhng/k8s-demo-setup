#!/usr/bin/env bash

# Stop on error, but allow us to handle specific failures
set -u

# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Get the directory where this script is located (infrastructure/multipass/)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Resolve the Terraform directory relative to this script (../../terraform)
TERRAFORM_DIR="$SCRIPT_DIR/../../terraform"

# Confirmation Prompt
echo -e "${RED}WARNING: This will destroy ALL VMs, Terraform State, and Local Configs.${NC}"
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborting."
  exit 1
fi

# Destroy Terraform Resources (Application Layer)
# We attempt this first. If it fails (because VMs are already dead), we force delete state.
echo -e "\n${YELLOW}Cleaning up Terraform...${NC}"
echo "Looking for Terraform in: $TERRAFORM_DIR"

if [ -d "$TERRAFORM_DIR" ]; then
  pushd "$TERRAFORM_DIR" > /dev/null
    
  if [ -f "terraform.tfstate" ]; then
    echo "Attempting graceful terraform destroy..."
    # Allow failure (|| true) in case the cluster is already unreachable 
    tfd -auto-approve || true
        
    echo "Removing local Terraform state files..."
    rm -f terraform.tfstate terraform.tfstate.backup
    rm -f .terraform.lock.hcl
    rm -rf .terraform/
  else
    echo "No state file found. Skipping."
  fi
  popd
else
  echo "${RED}Terraform directory not found at ${TERRAFORM_DIR}. Skipping.${NC}"
fi

# Destroy VMs
echo -e "\n${YELLOW}Destroying VMs...${NC}"

# Define VMs spec
NODES=("controlplane01" "node01" "ingress")

for node in "${NODES[@]}"; do
  if multipass info "$node" &> /dev/null; then
    echo -e "Stopping and deleting ${RED}$node${NC}..."
    multipass stop "$node"
    multipass delete "$node"
  else
    echo "$node not found or already deleted."
  fi
done

echo "Purging Multipass disk images..."
multipass purge

# Clean local config
echo -e "\n${YELLOW}Cleaning local configs...${NC}"

# Remove SSH known hosts
for node in "${NODES[@]}"; do
  echo "Removing $node from ~/.ssh/known_hosts..."
  sed -i '' "/$node/d" ~/.ssh/known_hosts 2>/dev/null || true
done

# Cleanup /etc/hosts
echo -e "${YELLOW}Removing entries from /etc/hosts/ (if exists)...${NC}"
for node in "${NODES[@]}"; do
  if grep -q "$node" /etc/hosts; then
    sudo sed -i '' "/$node/d" /etc/hosts
  fi
done

# Remove local kubeconfig
echo -e "${YELLOW}Remove kube config...${NC}"
sudo rm -f ~/.kube/config

# DHCP Lease Check
echo -e "\n${YELLOW}DHCP Lease Check...${NC}"
if grep -E '(controlplane01|node01|ingress)' /var/db/dhcpd_leases &>/dev/null; then
  echo -e "${RED}Found lingering DHCP leases in the following lines:${NC}"
  cat /var/db/dhcpd_leases | egrep -A 5 -B 1 '(controlplane01|node01|ingress)'
  echo -e "\nRun this command to delete them:"
  echo -e "${GREEN}sudo nvim /var/db/dhcpd_leases${NC}"
else
    echo -e "${GREEN}No lingering DHCP leases found.${NC}"
fi

echo -e "\n${GREEN}Cleanup Complete!${NC}"


