#!/bin/bash
set -e

echo "Validating prerequisites for OCP 4.20 Hosted Control Plane deployment..."
echo

# Check if oc is installed
if ! command -v oc &> /dev/null; then
    echo "ERROR: 'oc' CLI not found. Please install OpenShift CLI."
    exit 1
fi
echo "✓ OpenShift CLI (oc) found"

# Check cluster connection
if ! oc whoami &> /dev/null; then
    echo "ERROR: Not logged into an OpenShift cluster"
    exit 1
fi
echo "✓ Connected to cluster: $(oc whoami --show-server)"

# Check ACM operator
if ! oc get deployment -n open-cluster-management multiclusterhub-operator &> /dev/null; then
    echo "WARNING: ACM operator not found. Install Advanced Cluster Management operator first."
else
    echo "✓ ACM operator found"
fi

# Check MultiCluster Engine
if ! oc get mce multiclusterengine &> /dev/null; then
    echo "WARNING: MultiCluster Engine not found"
else
    echo "✓ MultiCluster Engine found"
fi

# Check OpenShift Virtualization operator
if ! oc get deployment -n openshift-cnv virt-operator &> /dev/null; then
    echo "WARNING: OpenShift Virtualization operator not found. Install it from OperatorHub."
else
    echo "✓ OpenShift Virtualization operator found"
fi

# Check HyperShift operator
if ! oc get deployment -n hypershift operator &> /dev/null; then
    echo "WARNING: HyperShift operator not found. Enable it in MCE."
else
    echo "✓ HyperShift operator found"
fi

# Check GitOps operator
if ! oc get deployment -n openshift-gitops openshift-gitops-server &> /dev/null; then
    echo "WARNING: OpenShift GitOps operator not found. Install it from OperatorHub."
else
    echo "✓ OpenShift GitOps operator found"
fi

# Check storage classes
echo
echo "Checking storage classes..."
if oc get storageclass lvms-vg1 &> /dev/null; then
    echo "✓ Storage class 'lvms-vg1' found (for etcd)"
else
    echo "WARNING: Storage class 'lvms-vg1' not found"
fi

if oc get storageclass ocs-storagecluster-ceph-rbd &> /dev/null; then
    echo "✓ Storage class 'ocs-storagecluster-ceph-rbd' found (for root volumes)"
else
    echo "WARNING: Storage class 'ocs-storagecluster-ceph-rbd' not found"
fi

echo
echo "Available storage classes:"
oc get storageclass

echo
echo "Validation complete!"
