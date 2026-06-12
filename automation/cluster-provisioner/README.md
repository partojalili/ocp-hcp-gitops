# Automated GCP OpenShift Cluster Provisioning

This automation uses External Secrets Operator and Kubernetes Jobs to automatically provision OpenShift clusters on GCP.

## Architecture

```
Developer Hub Template
    ↓
Creates cluster config in Git (including ExternalSecret resources)
    ↓
ArgoCD ApplicationSet detects new cluster
    ↓
Syncs manifests/ directory
    ↓
ExternalSecrets pull credentials from secret backend
    ↓
Kubernetes Job runs openshift-install (ArgoCD PostSync hook)
    ↓
Cluster provisioned on GCP (30-40 mins)
    ↓
Kubeconfig & credentials saved as Kubernetes secrets
```

## Components

### 1. ExternalSecret Resources

Three ExternalSecret resources fetch credentials from the central secret store:

- **gcp-credentials.yaml** - GCP service account JSON
- **pull-secret.yaml** - OpenShift pull secret
- **ssh-key.yaml** - SSH public key for node access

These use the same `hcp-secrets-store` ClusterSecretStore as the HCP template.

### 2. Installer Job

**installer-job.yaml** - Kubernetes Job that:
- Runs as ArgoCD PostSync hook (triggers after manifests sync)
- Downloads openshift-install binary
- Creates install-config.yaml with credentials
- Provisions OpenShift cluster on GCP
- Saves kubeconfig and kubeadmin password as secrets

### 3. RBAC Resources

- ServiceAccount: `cluster-installer`
- Role: permissions to create secrets and configmaps
- RoleBinding: binds role to service account

## Secret Mapping

| Secret Backend Key | Property | ExternalSecret Target | Job Mount Path |
|-------------------|----------|----------------------|----------------|
| `gcp-service-account` | (entire JSON) | `<cluster>-gcp-credentials` | `/secrets/gcp/service-account.json` |
| `ocp-pull-secret` | `.dockerconfigjson` | `<cluster>-pull-secret` | `/secrets/pull-secret/.dockerconfigjson` |
| `ocp-ssh-key` | `ssh-publickey` | `<cluster>-ssh-key` | `/secrets/ssh-key/ssh-publickey` |

## Installation Flow

1. **User submits template** in Developer Hub
2. **PR created** with:
   - `install-config.yaml` (cluster configuration)
   - `manifests/gcp-credentials.yaml` (ExternalSecret)
   - `manifests/pull-secret.yaml` (ExternalSecret)
   - `manifests/ssh-key.yaml` (ExternalSecret)
   - `manifests/installer-job.yaml` (Job)
   - `catalog-info.yaml` (Backstage metadata)
   - `README.md` (documentation)
3. **PR merged** to main branch
4. **ApplicationSet discovers** new cluster directory
5. **ArgoCD syncs** manifests directory to `gcp-<cluster-name>` namespace
6. **ExternalSecrets sync** (< 1 minute):
   - Fetch credentials from backend
   - Create Kubernetes secrets
7. **Job starts** (PostSync hook):
   - Waits for secrets to exist
   - Downloads openshift-install
   - Merges credentials into install-config.yaml
   - Runs `openshift-install create cluster`
8. **Cluster provisions** (30-40 minutes)
9. **Job saves output**:
   - `<cluster>-kubeconfig` secret
   - `<cluster>-kubeadmin` secret
   - `<cluster>-metadata` configmap

## Job Behavior

### Resource Limits
- **Memory**: 512Mi request, 1Gi limit
- **CPU**: 500m request, 1000m limit
- **Timeout**: 2 hours (7200 seconds)
- **Retries**: 2 backoff attempts

### ArgoCD Hooks
- **Hook**: PostSync (runs after main sync completes)
- **Delete Policy**: BeforeHookCreation (cleans up old jobs)

### Failure Modes

Job fails if:
- ExternalSecrets haven't synced (secrets missing)
- GCP service account lacks permissions
- Pull secret format invalid
- OpenShift installer fails (quota, network, DNS)
- Timeout exceeded (> 2 hours)

## Monitoring Installation

### Check ExternalSecrets
```bash
# List ExternalSecrets
oc get externalsecrets -n gcp-<cluster-name>

# Check sync status
oc get externalsecret <cluster>-gcp-credentials -n gcp-<cluster-name> -o yaml

# Verify secrets created
oc get secrets -n gcp-<cluster-name> | grep -E '(gcp-credentials|pull-secret|ssh-key)'
```

### Check Job Status
```bash
# Find installer job
oc get jobs -n gcp-<cluster-name> -l job-type=cluster-installer

# View job details
oc describe job install-<cluster-name> -n gcp-<cluster-name>

# Check pod status
oc get pods -n gcp-<cluster-name> -l job=cluster-installer

# Stream logs
oc logs -n gcp-<cluster-name> job/install-<cluster-name> -f
```

### Check Cluster Status
```bash
# After installation completes
oc get secret <cluster>-kubeconfig -n gcp-<cluster-name> \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/kubeconfig

export KUBECONFIG=/tmp/kubeconfig
oc get nodes
oc get co  # Cluster operators
```

## Accessing the Cluster

### Console URL
```
https://console-openshift-console.apps.<cluster-name>.<base-domain>
```

### API URL
```
https://api.<cluster-name>.<base-domain>:6443
```

### Kubeadmin Credentials
```bash
# Get password
oc get secret <cluster>-kubeadmin -n gcp-<cluster-name> \
  -o jsonpath='{.data.password}' | base64 -d
```

## Troubleshooting

### ExternalSecret Not Syncing

**Symptoms**: Secret `<cluster>-gcp-credentials` doesn't exist

**Check**:
```bash
# ExternalSecret status
oc get externalsecret <cluster>-gcp-credentials -n gcp-<cluster-name> -o yaml

# ClusterSecretStore status
oc get clustersecretstore hcp-secrets-store -o yaml
```

**Common causes**:
- ClusterSecretStore not ready
- Secret backend authentication failed
- Secret key missing in backend
- Property names don't match

### Job Stuck in Pending

**Symptoms**: Job exists but pod never starts

**Check**:
```bash
# Job events
oc describe job install-<cluster> -n gcp-<cluster-name>

# Pod events
oc get pods -n gcp-<cluster-name> -l job=cluster-installer
oc describe pod <pod-name> -n gcp-<cluster-name>
```

**Common causes**:
- Secrets not yet synced (wait for ExternalSecrets)
- Resource quotas exceeded
- Image pull failures

### Job Fails During Installation

**Symptoms**: Pod running but installation fails

**Check**:
```bash
# Detailed logs
oc logs -n gcp-<cluster-name> job/install-<cluster> --tail=100

# Check for specific errors
oc logs -n gcp-<cluster-name> job/install-<cluster> | grep -i error
```

**Common causes**:
- GCP quota exceeded (CPUs, IPs, disks)
- Invalid install-config.yaml
- DNS zone not configured
- Network connectivity issues
- GCP service account permissions

### Verify Credentials Format

**GCP Service Account**:
```bash
oc get secret <cluster>-gcp-credentials -n gcp-<cluster-name> \
  -o jsonpath='{.data.service-account\.json}' | base64 -d | jq '.'
```

**Pull Secret**:
```bash
oc get secret <cluster>-pull-secret -n gcp-<cluster-name> \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq '.'
```

**SSH Key**:
```bash
oc get secret <cluster>-ssh-key -n gcp-<cluster-name> \
  -o jsonpath='{.data.ssh-publickey}' | base64 -d
```

## Security Considerations

### Secret Isolation
- Each cluster gets its own namespace
- Secrets scoped to cluster namespace
- Job runs with minimal RBAC permissions
- ExternalSecrets auto-refresh every 1 hour

### Credential Rotation
- **GCP keys**: Rotate every 90 days
- **Pull secret**: Before expiration
- **SSH keys**: Yearly or when compromised

Update in secret backend → ExternalSecrets sync automatically (within 1 hour).

### Access Control
- Limit who can read kubeconfig secrets
- Audit secret access
- Use RBAC to restrict namespace access

## Cost Management

Each cluster creates GCP resources:
- **VMs**: 3 masters + N workers
- **Load Balancers**: External/internal
- **Persistent Disks**: Boot disks, etcd
- **VPC**: Subnets, NAT gateways

**Estimated cost**: ~$705/month for standard 3-worker cluster

**Recommendations**:
- Tag resources for cost tracking
- Set up billing alerts
- Delete dev clusters when not in use
- Use smaller machine types for testing

## Cluster Deletion

Currently **manual process**:

```bash
# 1. Get kubeconfig
oc get secret <cluster>-kubeconfig -n gcp-<cluster-name> \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/kubeconfig

# 2. Destroy GCP resources
# Option A: Using openshift-install (need original install dir)
openshift-install destroy cluster --dir=<install-dir>

# Option B: Manual via GCP Console
# Delete all resources with cluster tag/label

# 3. Remove from Git
git rm -r clusters/gcp/<cluster-name>
git commit -m "Delete cluster <cluster-name>"
git push

# 4. ArgoCD auto-deletes Application
```

**Future enhancement**: Add destruction Job with ArgoCD PreDelete hook.

## Limitations

- No automatic cluster destruction
- No automatic cluster upgrades
- Install directory not preserved (makes destroy harder)
- One installation per cluster (no retry if deleted)
- No queuing for concurrent installs

## Future Enhancements

1. **Destruction automation**: PreDelete hook Job
2. **Install directory backup**: Save to S3/GCS
3. **Upgrade automation**: Scheduled Jobs for upgrades
4. **Cluster health monitoring**: Prometheus/Grafana
5. **Cost tracking integration**: Tag resources, export metrics
6. **Hibernation**: Stop/start dev clusters on schedule
7. **Multi-cloud support**: AWS, Azure templates

## Comparison with HCP Template

| Feature | GCP IPI | HCP |
|---------|---------|-----|
| Provisioning method | openshift-install | HostedCluster CR |
| Installation time | 30-40 mins | 15-20 mins |
| Infrastructure | Full VMs | Containers on host |
| Cost | ~$705/month | ~$300/month |
| Secrets management | External Secrets | External Secrets |
| Automation | Kubernetes Job | Operator |
| Destruction | Manual | Automatic |

## Support

For issues:
1. Check ExternalSecret sync status
2. Verify ClusterSecretStore ready
3. Review installer job logs
4. Check GCP quotas and permissions
5. Verify secret formats
6. Review ArgoCD Application status
