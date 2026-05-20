# Prerequisites for HCP Template

Before provisioning clusters using this template, ensure the following prerequisites are met:

## 1. Sealed Secrets Controller

**Note:** Namespaces are created automatically for each cluster. Each cluster gets its own namespace (`clusters-CLUSTER_NAME`) for better isolation.

The Sealed Secrets controller must be installed to decrypt sealed secrets.

**Check if installed:**

```bash
oc get deployment sealed-secrets-controller -n kube-system
```

**Install if not present:**

```bash
oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/controller.yaml
```

**Wait for controller to be ready:**

```bash
oc wait --for=condition=Available deployment/sealed-secrets-controller -n kube-system --timeout=300s
```

## 2. OpenShift GitOps (ArgoCD)

If using GitOps deployment, OpenShift GitOps must be installed.

**Check if installed:**

```bash
oc get pods -n openshift-gitops
```

**Install OpenShift GitOps operator:**

```bash
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF
```

**Grant ArgoCD permissions for ACM:**

```bash
# Apply from repository root
oc apply -f argocd/argocd-acm-permissions.yaml
```

## 3. Storage Classes

Verify required storage classes are available:

**For etcd:**
```bash
oc get storageclass lvms-vg1
```

**For worker node root volumes:**
```bash
oc get storageclass ocs-external-storagecluster-ceph-rbd
```

If different storage classes are available in your environment, update the template files:
- `base/hostedcluster.yaml` (etcd storage)
- `base/nodepool.yaml` (worker node root volume)

## 4. ACM and MultiCluster Engine

**Check ACM version:**
```bash
oc get multiclusterhub -A
```

**Check MCE version:**
```bash
oc get multiclusterengine -A
```

**Required versions:**
- ACM 2.10+ (tested with 2.16)
- MCE 2.5+ (tested with 2.11)

## 5. OpenShift Virtualization

**Check if installed:**
```bash
oc get csv -n openshift-cnv | grep kubevirt
```

**Required for:**
- Running worker nodes as VMs (KubeVirt platform)

## 6. kubeseal CLI Tool

Required to seal secrets locally before committing to Git.

**macOS:**
```bash
brew install kubeseal
```

**Linux:**
```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/kubeseal-0.36.6-linux-amd64.tar.gz
tar -xvzf kubeseal-0.36.6-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

**Verify:**
```bash
kubeseal --version
```

## Quick Verification Script

Run this to check all prerequisites:

```bash
#!/bin/bash

echo "Checking prerequisites..."
echo ""

# Check Sealed Secrets
if oc get deployment sealed-secrets-controller -n kube-system &>/dev/null; then
    echo "✅ Sealed Secrets controller installed"
else
    echo "❌ Sealed Secrets controller not installed"
fi

# Check OpenShift GitOps
if oc get pods -n openshift-gitops &>/dev/null; then
    echo "✅ OpenShift GitOps installed"
else
    echo "⚠️  OpenShift GitOps not installed (optional for manual deployment)"
fi

# Check storage classes
if oc get storageclass lvms-vg1 &>/dev/null; then
    echo "✅ Storage class 'lvms-vg1' available"
else
    echo "⚠️  Storage class 'lvms-vg1' not found (update template if using different storage)"
fi

if oc get storageclass ocs-external-storagecluster-ceph-rbd &>/dev/null; then
    echo "✅ Storage class 'ocs-external-storagecluster-ceph-rbd' available"
else
    echo "⚠️  Storage class 'ocs-external-storagecluster-ceph-rbd' not found (update template if using different storage)"
fi

# Check kubeseal
if command -v kubeseal &>/dev/null; then
    echo "✅ kubeseal CLI installed"
else
    echo "❌ kubeseal CLI not installed - run: brew install kubeseal"
fi

echo ""
echo "Prerequisites check complete!"
```

Save this as `check-prerequisites.sh` and run it before provisioning clusters.
