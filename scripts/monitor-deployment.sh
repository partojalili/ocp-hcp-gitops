#!/bin/bash
set -e

CLUSTER_NAME=${1:-ocp420-hcp}
NAMESPACE=${2:-clusters}

echo "Monitoring deployment of hosted cluster: $CLUSTER_NAME"
echo "Press Ctrl+C to stop monitoring"
echo

while true; do
    clear
    echo "=== HostedCluster Status ==="
    oc get hostedcluster $CLUSTER_NAME -n $NAMESPACE -o wide 2>/dev/null || echo "HostedCluster not found"

    echo
    echo "=== NodePool Status ==="
    oc get nodepool -n $NAMESPACE -l hypershift.openshift.io/hosted-cluster-name=$CLUSTER_NAME -o wide 2>/dev/null || echo "NodePool not found"

    echo
    echo "=== Control Plane Pods ==="
    oc get pods -n clusters-$CLUSTER_NAME 2>/dev/null | head -20 || echo "Control plane namespace not found"

    echo
    echo "=== VirtualMachines ==="
    oc get vm -n clusters-$CLUSTER_NAME 2>/dev/null || echo "VMs not found yet"

    echo
    echo "=== Conditions ==="
    oc get hostedcluster $CLUSTER_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[*].type}{"\n"}{.status.conditions[*].status}{"\n"}' 2>/dev/null || echo "Status not available"

    sleep 10
done
