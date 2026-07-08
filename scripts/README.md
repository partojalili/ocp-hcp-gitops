# Cluster Management Scripts

## cleanup-acm-gcp-cluster.sh

Comprehensive cleanup script for ACM-managed GCP OpenShift clusters. This script removes all resources associated with a cluster:

- ArgoCD Application
- Kubernetes namespace and resources (ClusterDeployment, ManagedCluster)
- Git repository directory
- GCP infrastructure (VPC, firewall, load balancers, DNS, etc.)

### Prerequisites

- `oc` CLI logged into the hub cluster
- `gcloud` CLI authenticated with access to the GCP project
- Git repository access with push permissions

### Usage

```bash
./cleanup-acm-gcp-cluster.sh \
  --cluster-name <name> \
  --base-domain <domain> \
  --gcp-project <project> \
  [options]
```

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--cluster-name` | Name of the cluster to delete | `gcp-cluster` |
| `--base-domain` | Base domain for DNS | `d967h.gcp.redhatworkshops.io` |
| `--gcp-project` | GCP project ID | `openenv-d967h` |

### Optional Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--gcp-region` | GCP region | `us-east1` |
| `--git-repo-path` | Path to git repository | Current directory |
| `--skip-argocd` | Skip ArgoCD application deletion | false |
| `--skip-namespace` | Skip namespace deletion | false |
| `--skip-git` | Skip git directory deletion | false |
| `--skip-gcp` | Skip GCP resource cleanup | false |
| `--dry-run` | Show what would be deleted without deleting | false |

### Examples

**Full cleanup:**
```bash
./cleanup-acm-gcp-cluster.sh \
  --cluster-name gcp-cluster \
  --base-domain d967h.gcp.redhatworkshops.io \
  --gcp-project openenv-d967h
```

**Dry run (preview what would be deleted):**
```bash
./cleanup-acm-gcp-cluster.sh \
  --cluster-name gcp-cluster \
  --base-domain d967h.gcp.redhatworkshops.io \
  --gcp-project openenv-d967h \
  --dry-run
```

**Cleanup only GCP resources:**
```bash
./cleanup-acm-gcp-cluster.sh \
  --cluster-name gcp-cluster \
  --base-domain d967h.gcp.redhatworkshops.io \
  --gcp-project openenv-d967h \
  --skip-argocd \
  --skip-namespace \
  --skip-git
```

**Cleanup everything except GCP (e.g., for Shared VPC clusters):**
```bash
./cleanup-acm-gcp-cluster.sh \
  --cluster-name gcp-cluster \
  --base-domain d967h.gcp.redhatworkshops.io \
  --gcp-project openenv-d967h \
  --skip-gcp
```

**Specify different region:**
```bash
./cleanup-acm-gcp-cluster.sh \
  --cluster-name gcp-cluster \
  --base-domain d967h.gcp.redhatworkshops.io \
  --gcp-project openenv-d967h \
  --gcp-region us-west1
```

### What Gets Deleted

#### 1. ArgoCD Resources
- ArgoCD Application in `openshift-gitops` namespace

#### 2. Kubernetes Resources
- ClusterDeployment (with finalizer removal)
- ManagedCluster (with finalizer removal)
- Namespace

#### 3. Git Repository
- Cluster directory under `clusters/acm-gcp/<cluster-name>`
- Automatic commit and push

#### 4. GCP Resources

**Networking:**
- VPC network
- Subnets
- Firewall rules
- Cloud router

**Load Balancing:**
- Forwarding rules (global and regional)
- Target TCP proxies
- Backend services (global and regional)
- Health checks

**Compute:**
- Instance groups
- VM instances
- Persistent disks

**IP Addresses:**
- Static IP addresses (global and regional)

**DNS:**
- Private DNS zone
- DNS records (A, CNAME, etc.)

### Safety Features

- **Dry run mode**: Preview changes before executing
- **Error handling**: Uses `|| true` to continue even if resources don't exist
- **Finalizer removal**: Automatically removes finalizers to prevent stuck resources
- **Validation**: Checks for required parameters
- **Timeout protection**: Waits up to 2 minutes for namespace deletion

### Troubleshooting

**Namespace stuck in Terminating:**
```bash
# Check for stuck resources
oc get all -n <cluster-name>
oc get clusterdeployment -n <cluster-name>
oc get managedcluster <cluster-name>

# Manually remove finalizers if needed
oc patch clusterdeployment <name> -n <namespace> --type=merge -p '{"metadata":{"finalizers":[]}}'
oc patch managedcluster <name> --type=merge -p '{"metadata":{"finalizers":[]}}'
```

**GCP resources not found:**
- The script uses `|| true` to continue if resources don't exist
- Check if resources use a different infrastructure ID than the cluster name
- Manually verify with: `gcloud compute networks list --project=<project> --filter='name~<cluster-name>'`

**Git push fails:**
- Ensure you have push permissions to the repository
- Check if the directory exists: `ls clusters/acm-gcp/`
- Manually commit and push if needed

### Notes

- The script automatically finds the GCP infrastructure ID by searching for networks matching the cluster name
- All deletion operations use `--quiet` to avoid interactive prompts
- The script will continue even if individual resources are not found (uses `|| true`)
- For clusters using Shared VPC, use `--skip-gcp` and clean up GCP resources manually in the host project

### Exit Codes

- `0`: Success
- `1`: Missing required parameters or invalid options
