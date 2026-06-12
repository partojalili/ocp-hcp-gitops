# OpenShift Cluster: ${{ values.clusterName }}

This directory contains the configuration for the OpenShift cluster **${{ values.clusterName }}** on Google Cloud Platform.

## Cluster Details

- **Cluster Name**: `${{ values.clusterName }}`
- **Platform**: Google Cloud Platform (GCP)
- **Project ID**: `${{ values.gcpProjectID }}`
- **Region**: `${{ values.gcpRegion }}`
- **OpenShift Version**: `${{ values.openshiftVersion }}`
- **Base Domain**: `${{ values.baseDomain }}`
- **Network Type**: `${{ values.networkType }}`

## Infrastructure

### Control Plane
- **Replicas**: 3 (HA)
- **Machine Type**: `${{ values.masterMachineType }}`

### Workers
- **Replicas**: `${{ values.workerCount }}`
- **Machine Type**: `${{ values.workerMachineType }}`

## Prerequisites

Before installing the cluster, ensure you have:

1. **GCP Service Account** with the following roles:
   - Compute Admin
   - DNS Administrator
   - Security Admin
   - Service Account Admin
   - Service Account Key Admin
   - Storage Admin
   - Service Account User
   - Deployment Manager Editor

2. **OpenShift Pull Secret** from https://console.redhat.com/openshift/install/pull-secret

3. **SSH Key** for node access

4. **DNS Configuration**:
   - Create a Cloud DNS zone for `${{ values.baseDomain }}`
   - Ensure the domain is delegated to GCP's name servers

## Installation Steps

### 1. Prepare Credentials

Create a secrets directory (DO NOT commit this):

```bash
mkdir -p secrets
```

Save your GCP service account JSON key:

```bash
# Download from GCP Console or use gcloud
gcloud iam service-accounts keys create secrets/gcp-service-account.json \
  --iam-account=<service-account-email>
```

Save your OpenShift pull secret:

```bash
# Get from https://console.redhat.com/openshift/install/pull-secret
cat > secrets/pull-secret.json <<'EOF'
{your-pull-secret-here}
EOF
```

Generate SSH key if you don't have one:

```bash
ssh-keygen -t ed25519 -N '' -f secrets/ssh-key
```

### 2. Set Environment Variables

```bash
export GCP_SERVICE_ACCOUNT_FILE=$(pwd)/secrets/gcp-service-account.json
export PULL_SECRET=$(cat secrets/pull-secret.json | jq -c .)
export SSH_PUB_KEY=$(cat secrets/ssh-key.pub)
```

### 3. Prepare Install Config

Create the installation directory:

```bash
mkdir -p install-dir
```

Generate the install-config.yaml with secrets:

```bash
cat install-config.yaml | \
  sed "s|{{ "{{" }} .PullSecret {{ "}}" }}|${PULL_SECRET}|g" | \
  sed "s|{{ "{{" }} .SSHKey {{ "}}" }}|${SSH_PUB_KEY}|g" > install-dir/install-config.yaml
```

**IMPORTANT**: Backup your install-config.yaml as it will be consumed:

```bash
cp install-dir/install-config.yaml install-config-backup.yaml
```

### 4. Run the Installer

Download the OpenShift installer for version `${{ values.openshiftVersion }}`:

```bash
# Download installer
OPENSHIFT_VERSION=${{ values.openshiftVersion }}
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-${OPENSHIFT_VERSION}/openshift-install-linux.tar.gz

# Extract
tar -xvf openshift-install-linux.tar.gz
chmod +x openshift-install
```

Create the cluster:

```bash
./openshift-install create cluster --dir=install-dir --log-level=info
```

Installation typically takes **30-40 minutes**.

### 5. Access the Cluster

After installation completes:

```bash
# Set KUBECONFIG
export KUBECONFIG=$(pwd)/install-dir/auth/kubeconfig

# Verify cluster
oc get nodes
oc get co

# Get console URL
oc whoami --show-console

# Get kubeadmin password
cat install-dir/auth/kubeadmin-password
```

## Post-Installation

### Store Credentials Securely

Create a sealed secret for the kubeconfig (if using Sealed Secrets):

```bash
# Create secret
oc create secret generic ${{ values.clusterName }}-kubeconfig \
  --from-file=kubeconfig=install-dir/auth/kubeconfig \
  --dry-run=client -o yaml > secrets/kubeconfig-secret.yaml

# Seal it
kubeseal --format=yaml \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  < secrets/kubeconfig-secret.yaml \
  > manifests/kubeconfig-sealed-secret.yaml

# Apply to management cluster
oc apply -f manifests/kubeconfig-sealed-secret.yaml
```

### Configure DNS

Get the cluster's ingress IP:

```bash
oc -n openshift-ingress get service router-default -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Add DNS records in Cloud DNS:

1. **A Record**: `*.apps.${{ values.clusterName }}.${{ values.baseDomain }}` → `<ingress-ip>`
2. **A Record**: `api.${{ values.clusterName }}.${{ values.baseDomain }}` → `<api-lb-ip>`

Get API load balancer IP:

```bash
gcloud compute addresses list --filter="name~'${{ values.clusterName }}.*api'" --format="value(address)"
```

### Install ArgoCD Application

Apply the ArgoCD application to manage cluster resources:

```bash
oc apply -f argocd-application.yaml
```

## Cluster Access

- **Console**: https://console-openshift-console.apps.${{ values.clusterName }}.${{ values.baseDomain }}
- **API**: https://api.${{ values.clusterName }}.${{ values.baseDomain }}:6443
- **OAuth**: https://oauth-openshift.apps.${{ values.clusterName }}.${{ values.baseDomain }}

## Maintenance

### Scale Workers

Edit the MachineSet:

```bash
oc get machinesets -n openshift-machine-api
oc scale machineset <machineset-name> --replicas=<desired-count> -n openshift-machine-api
```

### Upgrade Cluster

```bash
# Check available upgrades
oc adm upgrade

# Start upgrade
oc adm upgrade --to=<version>
```

## Troubleshooting

### Installation Logs

```bash
tail -f install-dir/.openshift_install.log
```

### Installer State

```bash
./openshift-install wait-for install-complete --dir=install-dir --log-level=debug
```

### GCP Resources

Check created resources in GCP:

```bash
gcloud compute instances list --filter="labels.kubernetes-io-cluster-${{ values.clusterName }}"
gcloud compute disks list --filter="labels.kubernetes-io-cluster-${{ values.clusterName }}"
gcloud compute networks list
```

## Destroy Cluster

**WARNING**: This will permanently delete the cluster and all data.

```bash
./openshift-install destroy cluster --dir=install-dir --log-level=info
```

## Support

- [OpenShift GCP Documentation](https://docs.openshift.com/container-platform/${{ values.openshiftVersion }}/installing/installing_gcp/installing-gcp-customizations.html)
- [GCP Quotas](https://console.cloud.google.com/iam-admin/quotas?project=${{ values.gcpProjectID }})

---

**Created**: ${{ values.timestamp }}  
**Repository**: ${{ values.repoUrl }}  
**Branch**: ${{ values.gitBranch }}
