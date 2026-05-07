# ACM 2.16 Compatibility Guide

## ✅ Full Compatibility Confirmed

This GitOps repository is **fully compatible** with Red Hat Advanced Cluster Management (ACM) 2.16 and MultiCluster Engine (MCE) 2.11.

## Version Matrix

| Component | Version | Status |
|-----------|---------|--------|
| ACM | 2.16 | ✅ Supported |
| MCE | 2.11 | ✅ Required |
| HyperShift API | v1beta1 | ✅ Current (v1alpha1 deprecated) |
| OCP Hub Cluster | 4.16+ | ✅ Recommended |
| OCP Hosted Cluster | 4.20 | ✅ Supported |
| OpenShift Virtualization | 4.16+ | ✅ Required |

## Key ACM 2.16 Features for Hosted Control Planes

### 1. **Enhanced Virtualization Support**

ACM 2.16 includes significant improvements for OpenShift Virtualization integration:

- **New RBAC Management**: The `MultiClusterRoleAssignment` custom resource enables centralized role-based access control for virtual machines
- **HyperConverged Resource Editing**: Improved flexibility to edit the HyperConverged resource for infrastructure requirement changes
- **Cross-Cluster Migration Roles**: New roles for VM migration across clusters

### 2. **Hosted Control Plane Upgrade Paths**

The ACM console now supports:
- Visual display of available upgrade channels for hosted clusters
- Channel modal for managing upgrade paths
- Available channels stored in the `ManagedClusterInfo` resource

### 3. **GitOps Enhancements**

- **Custom CA Certificates**: Configure custom Certificate Authority certificates within Argo CD cluster secrets for secure TLS connections
- **Improved ApplicationSet Support**: Better integration for managing multiple hosted clusters

### 4. **Observability Improvements**

- **RightSizingRecommendation**: Now generally available for optimizing workload resources

## API Version Details

### ✅ Using v1beta1 (Correct)

All manifests in this repository use `hypershift.openshift.io/v1beta1`:

```yaml
apiVersion: hypershift.openshift.io/v1beta1
kind: HostedCluster
```

```yaml
apiVersion: hypershift.openshift.io/v1beta1
kind: NodePool
```

### ⚠️ v1alpha1 Deprecated

The older `hypershift.openshift.io/v1alpha1` API version is deprecated and should not be used with ACM 2.16.

## Version Compatibility Rules

ACM 2.16 enforces important version compatibility rules:

### NodePool to HostedCluster Version Skew

**Rule**: NodePools cannot exceed the HostedCluster version and must be within 3 minor versions.

**Examples**:
- ✅ **Supported**: HostedCluster 4.20 can have NodePools running 4.17, 4.18, 4.19, or 4.20
- ❌ **Unsupported**: HostedCluster 4.20 with NodePool 4.16 (exceeds N-3 skew)
- ❌ **Unsupported**: HostedCluster 4.20 with NodePool 4.21 (NodePool cannot be newer)

### HostedCluster OCP Version Support

The supported OCP versions for HostedClusters depend on your MCE version:

**With MCE 2.11 (ACM 2.16)**:
- Management cluster OCP version
- Two previous minor versions
- Example: Management cluster on OCP 4.18 supports hosted clusters 4.16, 4.17, 4.18, 4.19, 4.20

**Important**: Hosted Control Planes does NOT support the next RHOCP version unless you upgrade MCE to the next y-stream release.

## ACM 2.16-Specific Configuration

### Enable HyperShift in MCE 2.11

```bash
# Verify MCE version
oc get mce multiclusterengine -o yaml | grep "mce.openshift.io:"

# Enable HyperShift (if not already enabled)
oc patch mce multiclusterengine --type=merge -p '{"spec":{"overrides":{"components":[{"name":"hypershift","enabled":true}]}}}'

# Verify HyperShift operator
oc get deployment operator -n hypershift
```

### Using MultiClusterRoleAssignment (New in 2.16)

For RBAC management across virtual machines:

```yaml
apiVersion: rbac.open-cluster-management.io/v1alpha1
kind: MultiClusterRoleAssignment
metadata:
  name: vm-admin-access
  namespace: clusters
spec:
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: cluster-admin
  subjects:
  - kind: User
    name: admin@example.com
  clusterSelector:
    matchLabels:
      cluster-type: hosted-control-plane
```

### Enhanced Observability

Enable RightSizingRecommendation for hosted cluster workloads:

```yaml
apiVersion: observability.open-cluster-management.io/v1beta2
kind: MultiClusterObservability
metadata:
  name: observability
spec:
  observabilityAddonSpec:
    enableMetrics: true
    interval: 30
  storageConfig:
    metricObjectStorage:
      key: thanos.yaml
      name: thanos-object-storage
  advanced:
    rightsizing:
      enabled: true  # New in ACM 2.16
```

## Validation Steps for ACM 2.16

### 1. Verify ACM and MCE Versions

```bash
# Check ACM version
oc get multiclusterhub -n open-cluster-management -o jsonpath='{.items[0].status.currentVersion}'
# Expected: 2.16.x

# Check MCE version
oc get mce multiclusterengine -o jsonpath='{.status.currentVersion}'
# Expected: 2.11.x
```

### 2. Verify HyperShift Operator

```bash
# Check operator deployment
oc get deployment operator -n hypershift

# Check operator version
oc get deployment operator -n hypershift -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### 3. Verify API Version Support

```bash
# List available HyperShift API versions
oc api-resources | grep hypershift

# Expected output should include:
# hostedclusters    hc       hypershift.openshift.io/v1beta1
# nodepools         np       hypershift.openshift.io/v1beta1
```

### 4. Validate Storage Classes

```bash
# Run the validation script
./scripts/validate-prereqs.sh
```

## Known Considerations for ACM 2.16

### 1. **MachineIdentity Field Migration**

In recent HyperShift versions, the `MachineIdentity` field was moved from the HostedCluster API to the NodePool API for Azure platforms. This doesn't affect KubeVirt deployments.

### 2. **NodePool Version Validation**

ACM 2.16 includes enhanced validation to prevent unsupported version skew between HostedCluster and NodePools. You'll see a `SupportedVersionSkew` condition on your NodePool resource.

### 3. **Zero Touch Provisioning (ZTP) Migration**

ACM 2.16 introduces ZTP migration capabilities for gradually migrating managed clusters between hub clusters while maintaining cluster state.

## Upgrade Path to ACM 2.16

If upgrading from an earlier ACM version:

### From ACM 2.14/2.15 to ACM 2.16

1. **Backup existing hosted clusters**:
   ```bash
   oc get hostedcluster -A -o yaml > hostedclusters-backup.yaml
   oc get nodepool -A -o yaml > nodepools-backup.yaml
   ```

2. **Upgrade ACM operator**:
   ```bash
   # Update operator subscription channel
   oc patch subscription advanced-cluster-management \
     -n open-cluster-management \
     --type merge \
     -p '{"spec":{"channel":"release-2.16"}}'
   ```

3. **Wait for upgrade completion**:
   ```bash
   oc get mch multiclusterhub -n open-cluster-management -w
   ```

4. **Verify HyperShift operator upgraded**:
   ```bash
   oc get deployment operator -n hypershift
   ```

5. **Validate hosted clusters**:
   ```bash
   oc get hostedcluster -A
   oc get nodepool -A
   ```

## Testing Checklist

- [ ] ACM 2.16 operator installed and running
- [ ] MCE 2.11 verified
- [ ] HyperShift operator running in `hypershift` namespace
- [ ] OpenShift Virtualization operator installed
- [ ] Storage classes `lvms-vg1` and `ocs-storagecluster-ceph-rbd` available
- [ ] GitOps operator installed
- [ ] HostedCluster uses `v1beta1` API version
- [ ] NodePool uses `v1beta1` API version
- [ ] NodePool version within 3 minor versions of HostedCluster
- [ ] Pull secret configured
- [ ] SSH key configured (optional)
- [ ] DNS baseDomain configured

## References

- [ACM 2.16 Release Notes](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.16/html/release_notes/acm-release-notes)
- [ACM 2.16 Support Matrix](https://access.redhat.com/articles/7136928)
- [HyperShift API Documentation](https://hypershift-docs.netlify.app/reference/api/)
- [HyperShift Versioning Support](https://hypershift-docs.netlify.app/reference/versioning-support/)
- [MCE 2.11 Cluster Lifecycle](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.11/html/clusters/cluster_mce_overview)

## Support

For ACM 2.16-specific issues:
- Red Hat Support Portal: https://access.redhat.com/support
- ACM Product Documentation: https://access.redhat.com/products/red-hat-advanced-cluster-management-for-kubernetes
