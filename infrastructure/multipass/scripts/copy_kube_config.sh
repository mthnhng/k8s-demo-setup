#!/bin/bash

# Copy the kubeconfig file to local machine
# This script should run after initializing the cluster (kubeadm init/join)
multipass transfer controlplane01:/etc/kubernetes/admin.conf ~/.kube/config