# ACM-Managed OpenShift Cluster: ${{ values.clusterName }}

## Cluster Information

- **Name**: `${{ values.clusterName }}`
- **Platform**: Google Cloud Platform (GCP)
- **Region**: `${{ values.gcpRegion }}`
- **Base Domain**: `${{ values.baseDomain }}`
- **OpenShift Version**: `${{ values.openshiftVersion }}`
- **Provisioning Method**: ACM Hive Operator

## Configuration

### Control Plane
- **Nodes**: 3
- **Machine Type**: `${{ values.masterMachineType }}`

### Workers
- **Nodes**: `${{ values.workerCount }}`
- **Machine Type**: `${{ values.workerMachineType }}`

## Viewing in ACM

This cluster is managed by Red Hat Advanced Cluster Management (ACM). To view it:

1. Navigate to ACM Console
2. Go to **Infrastructure** → **Clusters**
3. Find cluster: `${{ values.clusterName }}`

## Cluster Access

### Console URL
```
https://console-openshift-console.apps.${{ values.clusterName }}.${{ values.baseDomain }}
```

### API URL
```
https://api.${{ values.clusterName }}.${{ values.baseDomain }}:6443
```

### Getting Kubeconfig

From ACM hub cluster:
```bash
# Get kubeadmin password
oc get secret $(oc get cd ${{ values.clusterName }} -n ${{ values.clusterName }} -o jsonpath='{.spec.clusterMetadata.adminPasswordSecretRef.name}') \\
  -n ${{ values.clusterName }} -o jsonpath='{.data.password}' | base64 -d

# Get kubeconfig
oc get secret $(oc get cd ${{ values.clusterName }} -n ${{ values.clusterName }} -o jsonpath='{.spec.clusterMetadata.adminKubeconfigSecretRef.name}') \\
  -n ${{ values.clusterName }} -o jsonpath='{.data.kubeconfig}' | base64 -d > ${{ values.clusterName }}-kubeconfig
```

## Monitoring Installation

Check ClusterDeployment status:
```bash
oc get clusterdeployment ${{ values.clusterName }} -n ${{ values.clusterName }} -o yaml
```

Watch installation progress:
```bash
oc get clusterdeployment ${{ values.clusterName }} -n ${{ values.clusterName }} -w
```

Check installation logs:
```bash
oc logs -n ${{ values.clusterName }} -l hive.openshift.io/cluster-deployment-name=${{ values.clusterName }} -f
```

## Troubleshooting

### Check Provisioning Status
```bash
oc describe clusterdeployment ${{ values.clusterName }} -n ${{ values.clusterName }}
```

### View Hive Install Pods
```bash
oc get pods -n ${{ values.clusterName }} -l job-name
```

### Common Issues

1. **Credentials Issue**: Verify GCP service account has proper permissions
2. **Quota Exceeded**: Check GCP project quotas
3. **DNS Configuration**: Ensure Cloud DNS zone exists for base domain

## Cluster Lifecycle

### Hibernating the Cluster
```bash
oc patch clusterdeployment ${{ values.clusterName }} -n ${{ values.clusterName }} \\
  --type merge -p '{"spec":{"powerState":"Hibernating"}}'
```

### Resuming the Cluster
```bash
oc patch clusterdeployment ${{ values.clusterName }} -n ${{ values.clusterName }} \\
  --type merge -p '{"spec":{"powerState":"Running"}}'
```

### Deleting the Cluster

**WARNING**: This will destroy all cluster resources on GCP!

```bash
# Delete ClusterDeployment (this triggers deprovision)
oc delete clusterdeployment ${{ values.clusterName }} -n ${{ values.clusterName }}

# Or delete from Git and let ArgoCD sync
git rm -r clusters/acm-gcp/${{ values.clusterName }}
git commit -m "Delete cluster ${{ values.clusterName }}"
git push
```

## Cost Information

Estimated monthly cost: ~$700-900 USD

- **Control Plane**: 3 x `${{ values.masterMachineType }}`
- **Workers**: `${{ values.workerCount }}` x `${{ values.workerMachineType }}`
- **Storage**: Persistent volumes
- **Networking**: Load balancers, egress

## Support

For issues with:
- **ACM**: Check ACM documentation
- **Provisioning**: Review Hive operator logs
- **GCP**: Verify service account permissions and quotas

---

**Provisioned via**: Red Hat Developer Hub  
**Created**: ${{ values.timestamp }}  
**Repository**: ${{ values.repoUrl }}
