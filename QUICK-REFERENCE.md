# Quick Reference - ACM + ArgoCD Commands

## Your Current Setup

**Hub Cluster:** https://api.cluster-nwjrk.dynamic2.redhatworkshops.io:6443  
**Hosted Cluster:** ocp-hcp (accessed via port-forward)  
**Git Repo:** https://github.com/partojalili/ocp-hcp-gitops.git  
**ArgoCD Namespace:** openshift-gitops  
**ACM Policy Namespace:** open-cluster-management-policies

---

## Connection Scripts

### Connect to Hub Cluster
```bash
oc login --token=sha256~PeZde2yGaERJZHZtME3kA9T8B8w4cNcnPVQj2pFUqU0 \\
  --server=https://api.cluster-nwjrk.dynamic2.redhatworkshops.io:6443
```

### Connect to Hosted Cluster (ocp-hcp)
```bash
cd /Users/pjalili/Projects
./conn-ocp-hcp.sh
```

### Disconnect from Hosted Cluster
```bash
./disconnect-ocp-hcp.sh
```

---

## ArgoCD Commands

### List ArgoCD Applications
```bash
oc get applications -n openshift-gitops
```

### Check Sync Status
```bash
oc get application acm-webserver-app -n openshift-gitops \\
  -o jsonpath='{.status.sync.status} - {.status.sync.revision}'
```

### Force ArgoCD Refresh
```bash
oc annotate application acm-webserver-app -n openshift-gitops \\
  argocd.argoproj.io/refresh=normal --overwrite
```

### View Application Details
```bash
oc get application acm-webserver-app -n openshift-gitops -o yaml
```

### Check ArgoCD Health
```bash
oc get pods -n openshift-gitops
```

---

## ACM Policy Commands

### List All Policies
```bash
oc get policies -n open-cluster-management-policies
```

### Check Policy Compliance
```bash
oc get policy policy-webserver-app -n open-cluster-management-policies
```

### View Policy Details
```bash
oc describe policy policy-webserver-app -n open-cluster-management-policies
```

### Check Policy Status
```bash
oc get policy policy-webserver-app -n open-cluster-management-policies \\
  -o jsonpath='{.status.compliant}'
```

### View Placement
```bash
oc get placement -n open-cluster-management-policies
```

### View PlacementBinding
```bash
oc get placementbinding -n open-cluster-management-policies
```

### Force Policy Update (Add Annotation)
```bash
oc annotate policy policy-webserver-app -n open-cluster-management-policies \\
  policy.open-cluster-management.io/trigger-update="$(date +%s)" --overwrite
```

---

## Managed Cluster Commands

### List Managed Clusters
```bash
oc get managedclusters
```

### Check Cluster Status
```bash
oc get managedcluster ocp-hcp -o wide
```

### View Cluster Info
```bash
oc describe managedcluster ocp-hcp
```

---

## Git Workflow

### Clone Repository
```bash
git clone https://github.com/partojalili/ocp-hcp-gitops.git
cd ocp-hcp-gitops
```

### Make Changes to Policy
```bash
# Edit the policy
vim policies/webserver-app/webserver-policy.yaml

# Increment config-version annotation (if changing ConfigMap)
# Line 85: config-version: "3" → "4"
```

### Commit and Push
```bash
git add policies/webserver-app/webserver-policy.yaml
git commit -m "Update webserver policy"
git push
```

### Check Git Status
```bash
git status
git log --oneline -5
```

---

## Verification Commands

### Check if ArgoCD Synced
```bash
# Check sync status
oc get application acm-webserver-app -n openshift-gitops

# Check synced revision
oc get application acm-webserver-app -n openshift-gitops \\
  -o jsonpath='{.status.sync.revision}'

# Compare with Git HEAD
cd /Users/pjalili/Projects/ocp-hcp-gitops
git rev-parse HEAD
```

### Check if ACM Policy Updated
```bash
# On hub cluster
oc get policy policy-webserver-app -n open-cluster-management-policies \\
  -o jsonpath='{.spec.policy-templates[1].objectDefinition.spec.object-templates[0].objectDefinition.data.application\.html}' \\
  | grep -o '<title>[^<]*</title>'
```

### Check if Changes Applied on Managed Cluster
```bash
# Connect to ocp-hcp
./conn-ocp-hcp.sh

# Check ConfigMap
oc get configmap application-content -n webserver-prod \\
  -o jsonpath='{.data.application\.html}' | grep -o '<title>[^<]*</title>'

# Check deployment config-version
oc get deployment webserver -n webserver-prod \\
  -o jsonpath='{.spec.template.metadata.annotations.config-version}'

# Check pod age (should be recent if restarted)
oc get pods -n webserver-prod

# Test the application
oc get route webserver -n webserver-prod \\
  -o jsonpath='{.spec.host}{.spec.path}' | xargs -I {} curl -sk https://{} | grep '<title>'
```

---

## Troubleshooting Commands

### ArgoCD Not Syncing

```bash
# Check ArgoCD operator
oc get pods -n openshift-gitops-operator

# Check ArgoCD application controller
oc get pods -n openshift-gitops | grep application-controller

# Check ArgoCD logs
oc logs -n openshift-gitops \\
  deployment/openshift-gitops-application-controller --tail=50

# Force refresh
oc annotate application acm-webserver-app -n openshift-gitops \\
  argocd.argoproj.io/refresh=normal --overwrite
```

### ACM Policy Not Compliant

```bash
# Check policy status
oc describe policy policy-webserver-app -n open-cluster-management-policies

# Check placement decisions
oc get placementdecision -n open-cluster-management-policies

# Check on managed cluster
oc get configurationpolicy -n ocp-hcp
```

### Changes Not Appearing

```bash
# 1. Check ArgoCD sync
oc get application acm-webserver-app -n openshift-gitops

# 2. Check Git revision
cd /Users/pjalili/Projects/ocp-hcp-gitops
git log --oneline -3

# 3. Check policy on hub
oc get policy policy-webserver-app -n open-cluster-management-policies -o yaml | grep -A 3 "config-version"

# 4. Check on ocp-hcp
./conn-ocp-hcp.sh
oc get deployment webserver -n webserver-prod -o jsonpath='{.spec.template.metadata.annotations.config-version}'
oc get pods -n webserver-prod  # Check pod age
```

### Manual Force Update

```bash
# On ocp-hcp cluster
./conn-ocp-hcp.sh

# Force deployment restart
oc rollout restart deployment webserver -n webserver-prod

# Force pod delete
oc delete pod -n webserver-prod -l app=webserver
```

---

## Update Workflow Cheat Sheet

### Updating Webserver HTML

1. **Edit file:**
   ```bash
   vim policies/webserver-app/webserver-policy.yaml
   # Line 51: Edit HTML content
   # Line 85: Increment config-version: "4" → "5"
   ```

2. **Commit:**
   ```bash
   git add policies/webserver-app/webserver-policy.yaml
   git commit -m "Update webserver - v5"
   git push
   ```

3. **Wait 3-5 minutes** for auto-sync

4. **Verify:**
   ```bash
   ./conn-ocp-hcp.sh
   oc get pods -n webserver-prod  # Check age
   oc exec -n webserver-prod deployment/webserver -- cat /var/www/html/application.html | grep '<title>'
   ```

---

## Common File Paths

- **Policies:** `/Users/pjalili/Projects/ocp-hcp-gitops/policies/`
- **Webserver Policy:** `/Users/pjalili/Projects/ocp-hcp-gitops/policies/webserver-app/webserver-policy.yaml`
- **Connection Scripts:** `/Users/pjalili/Projects/conn-ocp-hcp.sh`, `disconnect-ocp-hcp.sh`
- **Documentation:** `/Users/pjalili/Projects/ocp-hcp-gitops/HOW-TO-UPDATE-WEBSERVER.md`

---

## Important Annotations & Labels

### ArgoCD Application
```yaml
ignoreDifferences:
  - group: policy.open-cluster-management.io
    jsonPointers:
      - /status
    kind: Policy
```

### ACM Policy
```yaml
annotations:
  policy.open-cluster-management.io/standards: NIST SP 800-53
  policy.open-cluster-management.io/categories: CM Configuration Management
  policy.open-cluster-management.io/controls: CM-2 Baseline Configuration
```

### Deployment (for auto-reload)
```yaml
annotations:
  configmap.reloader.stakater.com/reload: "application-content"
  config-version: "5"  # Increment when changing ConfigMap
```

---

## Useful Aliases (Add to ~/.bashrc or ~/.zshrc)

```bash
# Cluster connections
alias hub='oc login --token=sha256~PeZde2yGaERJZHZtME3kA9T8B8w4cNcnPVQj2pFUqU0 --server=https://api.cluster-nwjrk.dynamic2.redhatworkshops.io:6443'
alias hcp='cd /Users/pjalili/Projects && ./conn-ocp-hcp.sh'
alias hcpd='cd /Users/pjalili/Projects && ./disconnect-ocp-hcp.sh'

# ArgoCD
alias argoapps='oc get applications -n openshift-gitops'
alias argosync='oc get application acm-webserver-app -n openshift-gitops -o jsonpath="{.status.sync.status} - {.status.sync.revision}"'

# ACM
alias policies='oc get policies -n open-cluster-management-policies'
alias checkpolicy='oc get policy policy-webserver-app -n open-cluster-management-policies'

# Git
alias gitops='cd /Users/pjalili/Projects/ocp-hcp-gitops'
