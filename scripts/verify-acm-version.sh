#!/bin/bash
set -e

echo "Verifying ACM 2.16 / MCE 2.11 compatibility..."
echo

# Check if connected to cluster
if ! oc whoami &> /dev/null; then
    echo "ERROR: Not logged into an OpenShift cluster"
    exit 1
fi

# Check ACM version
echo "Checking ACM version..."
ACM_VERSION=$(oc get multiclusterhub -n open-cluster-management -o jsonpath='{.items[0].status.currentVersion}' 2>/dev/null || echo "not-found")

if [ "$ACM_VERSION" = "not-found" ]; then
    echo "❌ ACM not found. Please install Advanced Cluster Management."
    exit 1
fi

echo "✓ ACM version: $ACM_VERSION"

# Check if ACM version is 2.16+
ACM_MAJOR=$(echo $ACM_VERSION | cut -d. -f1)
ACM_MINOR=$(echo $ACM_VERSION | cut -d. -f2)

if [ "$ACM_MAJOR" -lt 2 ] || ([ "$ACM_MAJOR" -eq 2 ] && [ "$ACM_MINOR" -lt 10 ]); then
    echo "⚠️  WARNING: ACM version $ACM_VERSION is older than recommended version 2.16"
    echo "   This configuration is optimized for ACM 2.16+"
else
    echo "✓ ACM version is compatible"
fi

if [ "$ACM_MAJOR" -eq 2 ] && [ "$ACM_MINOR" -eq 16 ]; then
    echo "✅ ACM 2.16 detected - fully compatible!"
fi

# Check MCE version
echo
echo "Checking MCE version..."
MCE_VERSION=$(oc get mce multiclusterengine -o jsonpath='{.status.currentVersion}' 2>/dev/null || echo "not-found")

if [ "$MCE_VERSION" = "not-found" ]; then
    echo "❌ MCE not found. MultiCluster Engine must be installed."
    exit 1
fi

echo "✓ MCE version: $MCE_VERSION"

# Check if MCE version is 2.11+
MCE_MAJOR=$(echo $MCE_VERSION | cut -d. -f1)
MCE_MINOR=$(echo $MCE_VERSION | cut -d. -f2)

if [ "$MCE_MAJOR" -eq 2 ] && [ "$MCE_MINOR" -eq 11 ]; then
    echo "✅ MCE 2.11 detected - fully compatible!"
elif [ "$MCE_MAJOR" -lt 2 ] || ([ "$MCE_MAJOR" -eq 2 ] && [ "$MCE_MINOR" -lt 5 ]); then
    echo "⚠️  WARNING: MCE version $MCE_VERSION is older than minimum version 2.5"
else
    echo "✓ MCE version is compatible"
fi

# Check HyperShift operator
echo
echo "Checking HyperShift operator..."
if ! oc get deployment operator -n hypershift &> /dev/null; then
    echo "❌ HyperShift operator not found"
    echo "   Enable it with: oc patch mce multiclusterengine --type=merge -p '{\"spec\":{\"overrides\":{\"components\":[{\"name\":\"hypershift\",\"enabled\":true}]}}}'"
    exit 1
fi

HYPERSHIFT_IMAGE=$(oc get deployment operator -n hypershift -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "✓ HyperShift operator found: $HYPERSHIFT_IMAGE"

# Check API versions
echo
echo "Checking HyperShift API versions..."
if oc api-resources | grep -q "hypershift.openshift.io/v1beta1"; then
    echo "✅ v1beta1 API available (correct)"
else
    echo "❌ v1beta1 API not found"
    exit 1
fi

if oc api-resources | grep -q "hypershift.openshift.io/v1alpha1"; then
    echo "⚠️  v1alpha1 API available (deprecated, should use v1beta1)"
fi

# Summary
echo
echo "================================"
echo "Compatibility Summary"
echo "================================"
echo "ACM Version:        $ACM_VERSION"
echo "MCE Version:        $MCE_VERSION"
echo "HyperShift API:     v1beta1 ✓"
echo "================================"

if [ "$ACM_MAJOR" -eq 2 ] && [ "$ACM_MINOR" -eq 16 ] && [ "$MCE_MAJOR" -eq 2 ] && [ "$MCE_MINOR" -eq 11 ]; then
    echo
    echo "✅ Perfect! You are running ACM 2.16 with MCE 2.11"
    echo "   This is the recommended configuration."
    echo
    echo "New features available in ACM 2.16:"
    echo "  • MultiClusterRoleAssignment for VM RBAC"
    echo "  • Enhanced hosted control plane upgrade paths"
    echo "  • Custom CA certificates in GitOps"
    echo "  • RightSizingRecommendation (GA)"
else
    echo
    echo "✓ Your environment is compatible."
    echo "  For best experience, consider upgrading to ACM 2.16 / MCE 2.11"
fi

echo
echo "See ACM-2.16-COMPATIBILITY.md for detailed compatibility information."
