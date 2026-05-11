# Quick Start for ACM 2.16

## ✅ ACM 2.16 Ready!

This repository is **fully compatible** with ACM 2.16 and MCE 2.11.

## 5-Minute Quick Start

### 1. Verify Your Environment

```bash
cd ocp-hcp-gitops
./scripts/verify-acm-version.sh
```

**Expected Output** (for ACM 2.16):

```
✅ ACM 2.16 detected - fully compatible!
✅ MCE 2.11 detected - fully compatible!
✓ HyperShift operator found
✅ v1beta1 API available (correct)
```

### 2. Configure Secrets

```bash
# Pull secret (required)
cat ~/Downloads/pull-secret.txt | base64 -w0
# Paste into base/pull-secret.yaml

# SSH key (optional)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ocp420-hcp -N ""
cat ~/.ssh/ocp420-hcp.pub
# Paste into base/ssh-key.yaml
```

### 3. Customize DNS

Edit `overlays/production/hostedcluster-patch.yaml`:

```yaml
spec:
  dns:
    baseDomain: your-domain.com  # ← Change this
```

### 4. Deploy

**Option A - GitOps (Recommended)**:

```bash
# Update Git URL in argocd/application.yaml
git init && git add . && git commit -m "OCP 4.20 HCP"
git remote add origin https://github.com/YOUR-ORG/YOUR-REPO.git
git push -u origin main

oc apply -f argocd/application.yaml
```

**Option B - Direct**:

```bash
oc apply -k overlays/production/
```

### 5. Monitor

```bash
./scripts/monitor-deployment.sh
```

### 6. Access Your Cluster

```bash
./scripts/get-kubeconfig.sh
export KUBECONFIG=ocp420-hcp-kubeconfig.yaml
oc get nodes
```

## What's Using ACM 2.16 Features?


| Feature                              | ACM 2.16 Enhancement             | Used In This Repo                |
| ------------------------------------ | -------------------------------- | -------------------------------- |
| HyperShift API v1beta1               | Stable API (v1alpha1 deprecated) | ✅ All manifests                  |
| Hosted Cluster Upgrade UI            | Visual upgrade channels          | ✅ Enabled by default             |
| GitOps Custom CA                     | Secure TLS connections           | 🔧 Optional (argocd/)            |
| VM RBAC (MultiClusterRoleAssignment) | Centralized VM permissions       | 📖 See ACM-2.16-COMPATIBILITY.md |
| RightSizingRecommendation            | Workload optimization            | 📖 See ACM-2.16-COMPATIBILITY.md |


## Version Compatibility Matrix (ACM 2.16)


| Hub Cluster OCP | Hosted Cluster OCP           | Status |
| --------------- | ---------------------------- | ------ |
| 4.16            | 4.17, 4.18, 4.19, 4.20       | ✅      |
| 4.17            | 4.17, 4.18, 4.19, 4.20       | ✅      |
| 4.18            | 4.16, 4.17, 4.18, 4.19, 4.20 | ✅      |


**Rule**: NodePools must be within 3 minor versions of HostedCluster and cannot be newer.

## ACM 2.16-Specific Commands

### Enable HyperShift (if needed)

```bash
oc patch mce multiclusterengine --type=merge \
  -p '{"spec":{"overrides":{"components":[{"name":"hypershift","enabled":true}]}}}'
```

### Check Upgrade Channels (New in 2.16)

```bash
# View available upgrade channels
oc get managedclusterinfo ocp420-hcp -n ocp420-hcp -o yaml | grep channels

# View in ACM console
# Infrastructure → Clusters → [cluster name] → Upgrade
```

### Using MultiClusterRoleAssignment (New in 2.16)

```bash
cat <<EOF | oc apply -f -
apiVersion: rbac.open-cluster-management.io/v1alpha1
kind: MultiClusterRoleAssignment
metadata:
  name: hcp-vm-admin
  namespace: clusters
spec:
  roleRef:
    kind: ClusterRole
    name: cluster-admin
  subjects:
  - kind: User
    name: admin@example.com
  clusterSelector:
    matchLabels:
      name: ocp420-hcp
EOF
```

## Troubleshooting ACM 2.16

### Issue: "API version not supported"

**Cause**: Using deprecated v1alpha1 API  
**Solution**: This repo uses v1beta1 (correct) ✅

### Issue: "Version skew not supported"

**Cause**: NodePool version differs from HostedCluster by more than 3 minor versions  
**Solution**: Update NodePool release image to match HostedCluster

```bash
CLUSTER_VERSION=$(oc get hostedcluster ocp420-hcp -n clusters -o jsonpath='{.spec.release.image}')
oc patch nodepool ocp420-hcp-workers -n clusters --type=merge \
  -p "{\"spec\":{\"release\":{\"image\":\"$CLUSTER_VERSION\"}}}"
```

### Issue: HyperShift operator not found

```bash
# Enable HyperShift in MCE 2.11
oc patch mce multiclusterengine --type=merge \
  -p '{"spec":{"overrides":{"components":[{"name":"hypershift","enabled":true}]}}}'

# Wait for operator
oc wait --for=condition=Available deployment/operator -n hypershift --timeout=5m
```

## What's Different from ACM 2.15 or Earlier?


| Change      | ACM 2.15            | ACM 2.16                           |
| ----------- | ------------------- | ---------------------------------- |
| API Version | v1beta1 or v1alpha1 | v1beta1 only (v1alpha1 deprecated) |
| MCE Version | 2.10                | 2.11                               |
| Upgrade UI  | Basic               | Enhanced with channels             |
| VM RBAC     | Manual              | MultiClusterRoleAssignment         |
| GitOps TLS  | Default certs       | Custom CA support                  |


## Resources

- 📄 [ACM-2.16-COMPATIBILITY.md](ACM-2.16-COMPATIBILITY.md) - Detailed compatibility guide
- 📄 [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Complete deployment instructions
- 📄 [README.md](README.md) - Repository overview

## Official Documentation

- [ACM 2.16 Release Notes](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.16/html/release_notes/acm-release-notes)
- [ACM 2.16 Support Matrix](https://access.redhat.com/articles/7136928)
- [HyperShift API v1beta1](https://hypershift-docs.netlify.app/reference/api/)
- [MCE 2.11 Documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.11/html/clusters/cluster_mce_overview)

---

**Need Help?** See the [troubleshooting section in DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md#troubleshooting)