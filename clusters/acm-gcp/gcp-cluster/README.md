# ACM-Managed OpenShift Cluster: gcp-cluster

## Cluster Information

- **Name**: `gcp-cluster`
- **Platform**: Google Cloud Platform (GCP)
- **Region**: `us-east1`
- **Base Domain**: `jdpff.gcp.redhatworkshops.io`
- **OpenShift Version**: `4.20.24`
- **Provisioning Method**: ACM Hive Operator

## Configuration

### Control Plane
- **Nodes**: 3
- **Machine Type**: `n2-standard-4`

### Workers
- **Nodes**: `3`
- **Machine Type**: `n2-standard-4`

## Viewing in ACM

This cluster is managed by Red Hat Advanced Cluster Management (ACM). To view it:

1. Navigate to ACM Console
2. Go to **Infrastructure** → **Clusters**
3. Find cluster: `gcp-cluster`

## Cluster Access

### Console URL
```
https://console-openshift-console.apps.gcp-cluster.jdpff.gcp.redhatworkshops.io
```

### API URL
```
https://api.gcp-cluster.jdpff.gcp.redhatworkshops.io:6443
```

### Getting Kubeconfig

From ACM hub cluster:
```bash
# Get kubeadmin password
oc get secret $(oc get cd gcp-cluster -n gcp-cluster -o jsonpath='{.spec.clusterMetadata.adminPasswordSecretRef.name}') \\
  -n gcp-cluster -o jsonpath='{.data.password}' | base64 -d

# Get kubeconfig
oc get secret $(oc get cd gcp-cluster -n gcp-cluster -o jsonpath='{.spec.clusterMetadata.adminKubeconfigSecretRef.name}') \\
  -n gcp-cluster -o jsonpath='{.data.kubeconfig}' | base64 -d > gcp-cluster-kubeconfig
```

## Monitoring Installation

Check ClusterDeployment status:
```bash
oc get clusterdeployment gcp-cluster -n gcp-cluster -o yaml
```

Watch installation progress:
```bash
oc get clusterdeployment gcp-cluster -n gcp-cluster -w
```

Check installation logs:
```bash
oc logs -n gcp-cluster -l hive.openshift.io/cluster-deployment-name=gcp-cluster -f
```

## Troubleshooting

### Check Provisioning Status
```bash
oc describe clusterdeployment gcp-cluster -n gcp-cluster
```

### View Hive Install Pods
```bash
oc get pods -n gcp-cluster -l job-name
```

### Common Issues

1. **Credentials Issue**: Verify GCP service account has proper permissions
2. **Quota Exceeded**: Check GCP project quotas
3. **DNS Configuration**: Ensure Cloud DNS zone exists for base domain

## Cluster Lifecycle

### Hibernating the Cluster
```bash
oc patch clusterdeployment gcp-cluster -n gcp-cluster \\
  --type merge -p '{"spec":{"powerState":"Hibernating"}}'
```

### Resuming the Cluster
```bash
oc patch clusterdeployment gcp-cluster -n gcp-cluster \\
  --type merge -p '{"spec":{"powerState":"Running"}}'
```

### Deleting the Cluster

**WARNING**: This will destroy all cluster resources on GCP!

```bash
# Delete ClusterDeployment (this triggers deprovision)
oc delete clusterdeployment gcp-cluster -n gcp-cluster

# Or delete from Git and let ArgoCD sync
git rm -r clusters/acm-gcp/gcp-cluster
git commit -m "Delete cluster gcp-cluster"
git push
```

## Cost Information

Estimated monthly cost: ~$700-900 USD

- **Control Plane**: 3 x `n2-standard-4`
- **Workers**: `3` x `n2-standard-4`
- **Storage**: Persistent volumes
- **Networking**: Load balancers, egress

## Support

For issues with:
- **ACM**: Check ACM documentation
- **Provisioning**: Review Hive operator logs
- **GCP**: Verify service account permissions and quotas

---

**Provisioned via**: Red Hat Developer Hub  
**Created**: ${{ '' | now }}  
**Repository**: https://github.com/partojalili/ocp-hcp-gitops.git
