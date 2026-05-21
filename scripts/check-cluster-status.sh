#!/bin/bash
# Comprehensive HCP Cluster Status Check
# Usage: ./check-cluster-status.sh <cluster-name>

CLUSTER_NAME=${1}
NAMESPACE="clusters-${CLUSTER_NAME}"

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name>"
    echo "Example: $0 hcp2"
    exit 1
fi

echo "========================================="
echo "HCP Cluster Status: ${CLUSTER_NAME}"
echo "========================================="
echo ""

# Check if cluster exists
if ! oc get hostedcluster -n ${NAMESPACE} ${CLUSTER_NAME} &>/dev/null; then
    echo "❌ Cluster '${CLUSTER_NAME}' not found in namespace '${NAMESPACE}'"
    exit 1
fi

# 1. HostedCluster Status
echo "1. HOSTEDCLUSTER STATUS"
echo "----------------------"
HC_AVAILABLE=$(oc get hostedcluster -n ${NAMESPACE} ${CLUSTER_NAME} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
HC_PROGRESSING=$(oc get hostedcluster -n ${NAMESPACE} ${CLUSTER_NAME} -o jsonpath='{.status.conditions[?(@.type=="Progressing")].status}' 2>/dev/null)
HC_DEGRADED=$(oc get hostedcluster -n ${NAMESPACE} ${CLUSTER_NAME} -o jsonpath='{.status.conditions[?(@.type=="Degraded")].status}' 2>/dev/null)
HC_VERSION=$(oc get hostedcluster -n ${NAMESPACE} ${CLUSTER_NAME} -o jsonpath='{.status.version.desired.version}' 2>/dev/null)

echo "  Available: ${HC_AVAILABLE}"
echo "  Progressing: ${HC_PROGRESSING}"
echo "  Degraded: ${HC_DEGRADED}"
echo "  Version: ${HC_VERSION}"
echo ""

# 2. NodePool Status
echo "2. NODEPOOL STATUS"
echo "------------------"
NP_READY=$(oc get nodepool -n ${NAMESPACE} ${CLUSTER_NAME}-workers -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
NP_MACHINES=$(oc get nodepool -n ${NAMESPACE} ${CLUSTER_NAME}-workers -o jsonpath='{.status.conditions[?(@.type=="AllMachinesReady")].status}' 2>/dev/null)
NP_NODES=$(oc get nodepool -n ${NAMESPACE} ${CLUSTER_NAME}-workers -o jsonpath='{.status.conditions[?(@.type=="AllNodesHealthy")].status}' 2>/dev/null)
NP_REPLICAS=$(oc get nodepool -n ${NAMESPACE} ${CLUSTER_NAME}-workers -o jsonpath='{.status.replicas}' 2>/dev/null)
NP_DESIRED=$(oc get nodepool -n ${NAMESPACE} ${CLUSTER_NAME}-workers -o jsonpath='{.spec.replicas}' 2>/dev/null)

echo "  Ready: ${NP_READY}"
echo "  AllMachinesReady: ${NP_MACHINES}"
echo "  AllNodesHealthy: ${NP_NODES}"
echo "  Replicas: ${NP_REPLICAS:-0}/${NP_DESIRED}"
echo ""

# 3. Worker VMs
echo "3. WORKER VMs"
echo "-------------"
VM_COUNT=$(oc get virtualmachine -n ${NAMESPACE}-${CLUSTER_NAME} --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$VM_COUNT" -gt 0 ]; then
    oc get virtualmachine -n ${NAMESPACE}-${CLUSTER_NAME} 2>/dev/null
else
    echo "  No VMs found (namespace: ${NAMESPACE}-${CLUSTER_NAME})"
fi
echo ""

# 4. Control Plane Pods
echo "4. CONTROL PLANE PODS (summary)"
echo "-------------------------------"
TOTAL_PODS=$(oc get pods -n ${NAMESPACE}-${CLUSTER_NAME} --no-headers 2>/dev/null | wc -l | tr -d ' ')
RUNNING_PODS=$(oc get pods -n ${NAMESPACE}-${CLUSTER_NAME} --no-headers 2>/dev/null | grep Running | wc -l | tr -d ' ')
PENDING_PODS=$(oc get pods -n ${NAMESPACE}-${CLUSTER_NAME} --no-headers 2>/dev/null | grep -E "Pending|ContainerCreating" | wc -l | tr -d ' ')
ERROR_PODS=$(oc get pods -n ${NAMESPACE}-${CLUSTER_NAME} --no-headers 2>/dev/null | grep -E "Error|CrashLoopBackOff|ImagePullBackOff" | wc -l | tr -d ' ')

echo "  Total: ${TOTAL_PODS}"
echo "  Running: ${RUNNING_PODS}"
echo "  Pending: ${PENDING_PODS}"
echo "  Error: ${ERROR_PODS}"
echo ""

# 5. Recent NodePool Events
echo "5. NODEPOOL EVENTS (last 5 warnings)"
echo "------------------------------------"
oc get events -n ${NAMESPACE} --field-selector involvedObject.name=${CLUSTER_NAME}-workers --sort-by='.lastTimestamp' 2>/dev/null | grep Warning | tail -5 || echo "  No warnings found"
echo ""

# 6. Overall Status
echo "6. OVERALL STATUS"
echo "-----------------"
if [ "$HC_AVAILABLE" = "True" ] && [ "$NP_READY" = "True" ] && [ "$NP_NODES" = "True" ]; then
    echo "  ✅ CLUSTER IS READY!"
    echo ""
    echo "Next steps:"
    echo "  - Port-forward to API: oc port-forward -n ${NAMESPACE}-${CLUSTER_NAME} svc/kube-apiserver 6443:6443"
    echo "  - Get kubeconfig: oc get secret -n ${NAMESPACE} ${CLUSTER_NAME}-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > ${CLUSTER_NAME}-kubeconfig"
    echo "  - Login: oc login --kubeconfig=${CLUSTER_NAME}-kubeconfig https://localhost:6443"
elif [ "$HC_AVAILABLE" = "True" ] && [ "$NP_MACHINES" = "True" ]; then
    echo "  ⏳ Control plane ready, workers provisioning (machines ready but nodes not healthy)"
    echo ""
    echo "Current issue: Workers are running but not registering as healthy nodes"
    echo "Check: NodePool events above for errors"
elif [ "$HC_AVAILABLE" = "True" ]; then
    echo "  ⏳ Control plane ready, waiting for workers..."
    echo ""
    echo "Current status: Worker VMs are being created"
else
    echo "  ⏳ Cluster provisioning in progress..."
    echo ""
    echo "Current status: Control plane is still deploying"
fi
echo ""
