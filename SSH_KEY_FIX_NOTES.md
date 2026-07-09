# SSH Key Fix for ACM GCP Cluster Provisioning

## Issue Summary
Cluster provisioning was failing with SSH authentication errors during bootstrap phase:
- Error: "ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain"
- Bootstrap host was reachable but installer couldn't authenticate

## Root Causes

### 1. Template Bug
**File:** `developer-hub/templates/acm-gcp-cluster-template/skeleton/base/ssh-key.yaml`

**Problem:** Line 18 was fetching the wrong property from the secret store
```yaml
# WRONG
property: ssh-publickey
```

**Fix:** Changed to fetch the private key
```yaml
# CORRECT
property: ssh-privatekey
```

**Commit:** `bfcd917` - "Fix SSH key: use ssh-privatekey instead of ssh-publickey"

### 2. Missing Secret Property
**Secret:** `ocp-ssh-key` in namespace `hcp-secrets`

**Problem:** The secret only contained the public key property
```json
{
  "ssh-publickey": "<base64-encoded-public-key>"
}
```

**Fix:** Added the matching private key property
```bash
oc patch secret ocp-ssh-key -n hcp-secrets --type='json' -p='[
  {
    "op": "add",
    "path": "/data/ssh-privatekey",
    "value": "<base64-encoded-private-key-from-~/.ssh/ocp420-hcp>"
  }
]'
```

**Result:** Secret now contains both keys
```json
{
  "ssh-privatekey": "<base64-encoded-private-key>",
  "ssh-publickey": "<base64-encoded-public-key>"
}
```

## SSH Key Pair Used
- **Public Key:** `~/.ssh/ocp420-hcp.pub`
- **Private Key:** `~/.ssh/ocp420-hcp`
- **Type:** RSA 4096-bit
- **User:** pjalili@pjalili-mac

## Verification Steps

1. **Template Fix Verification:**
   ```bash
   cd ~/Projects/ocp-hcp-gitops
   git show HEAD:developer-hub/templates/acm-gcp-cluster-template/skeleton/base/ssh-key.yaml | grep property
   # Should show: property: ssh-privatekey
   ```

2. **Secret Verification:**
   ```bash
   oc get secret ocp-ssh-key -n hcp-secrets -o jsonpath='{.data}' | jq -r 'keys'
   # Should show: ["ssh-privatekey", "ssh-publickey"]
   ```

3. **ExternalSecret Health:**
   ```bash
   oc get externalsecret gcp-cluster-ssh-key -n gcp-cluster
   # Should show: READY=True, STATUS=SecretSynced
   ```

4. **ArgoCD Application Health:**
   ```bash
   oc get application.argoproj.io acm-gcp-cluster-gcp-cluster -n openshift-gitops
   # Should show: HEALTH STATUS=Healthy (not Degraded)
   ```

## GCP IAM Permissions (Previously Added)

The following roles were added to service account `sa-openenv-d967h@rhpds-345620.iam.gserviceaccount.com`:
- `roles/storage.admin` - For GCS bucket access
- `roles/dns.admin` - For DNS zone management  
- `roles/iam.serviceAccountUser` - For service account usage

## Next Steps

When provisioning a new cluster via Developer Hub:
1. Use template: "ACM-Managed GCP Cluster"
2. The SSH key will now be correctly fetched from the secret store
3. Bootstrap authentication should succeed
4. Cluster should provision successfully

## Related Files
- Template: `developer-hub/templates/acm-gcp-cluster-template/skeleton/base/ssh-key.yaml`
- Secret: `ocp-ssh-key` in namespace `hcp-secrets`
- Cleanup script: `scripts/cleanup-acm-gcp-cluster.sh`

## Date
2026-07-09
