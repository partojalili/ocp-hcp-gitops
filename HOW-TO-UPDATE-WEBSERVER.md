# How to Update the Webserver Application

## Overview
The webserver application now has **automatic reload** configured. When you update the HTML content, the deployment will automatically restart to pick up changes.

## The Auto-Reload Mechanism

### What Was Fixed:
1. **Removed `subPath` mount** - ConfigMaps with subPath don't update on pod restart
2. **Changed compliance type** - Using `mustonlyhave` instead of `musthave` forces ACM to update resources
3. **Added `config-version` annotation** - Changing this triggers deployment restart

### How It Works:
```
Change HTML + Bump config-version → Commit & Push
   ↓
ArgoCD syncs to Hub (auto, ~3 min)
   ↓  
ACM enforces policy on ocp-hcp (auto, ~1 min)
   ↓
ConfigMap updated + Deployment restarted (auto)
   ↓
New pod serves updated content!
```

## Step-by-Step: How to Update the HTML

### 1. Edit the HTML Content
Edit `policies/webserver-app/webserver-policy.yaml` line 51:

```yaml
data:
  application.html: "<!DOCTYPE html><html><head><title>YOUR NEW TITLE</title>..."
```

### 2. Increment the config-version
Edit line 85 and increment the version number:

```yaml
annotations:
  configmap.reloader.stakater.com/reload: "application-content"
  config-version: "4"  # Increment: 3 → 4 → 5, etc.
```

### 3. Commit and Push
```bash
cd /Users/pjalili/Projects/ocp-hcp-gitops
git add policies/webserver-app/webserver-policy.yaml
git commit -m "Update webserver content to v4"
git push
```

### 4. Wait for Sync (3-5 minutes)
- ArgoCD syncs automatically (~3 minutes)
- ACM enforces policy (~1 minute)
- Deployment restarts automatically
- New pod serves updated content

### 5. Verify
```bash
# Connect to ocp-hcp
cd /Users/pjalili/Projects
./conn-ocp-hcp.sh

# Check the deployment
oc get pods -n webserver-prod

# Test the content
oc exec -n webserver-prod deployment/webserver -- cat /var/www/html/application.html | grep -o '<title>[^<]*</title>'

# Or curl the route
oc get route webserver -n webserver-prod -o jsonpath='{.spec.host}{.spec.path}' | xargs -I {} curl -sk https://{} | grep -o '<title>[^<]*</title>'
```

## Important Notes

### ⚠️ Always Increment config-version
If you change the HTML but **forget to increment config-version**, the ConfigMap will update but the pod **won't restart**. You'll need to manually delete the pod:

```bash
oc delete pod -n webserver-prod -l app=webserver
```

### ✅ The config-version Annotation
- This is what triggers the deployment restart
- ACM sees the annotation changed → applies new deployment spec → pod restarts
- **Always increment it** when changing ConfigMap content

### 📝 Compliance Type: mustonlyhave
- `musthave` = "Resource should exist with at least these fields" (doesn't update)
- `mustonlyhave` = "Resource must match exactly" (forces updates)
- This is why we changed it in the ConfigMap and Deployment policies

### 🔄 No subPath
- We removed `subPath: application.html` from the volume mount
- subPath mounts don't update even on pod restart (Kubernetes limitation)
- Now mounting the whole ConfigMap directory to `/var/www/html`

## Troubleshooting

### Changes not appearing after 5 minutes?

1. **Check ArgoCD sync:**
```bash
# On hub cluster
oc get applications.argoproj.io acm-webserver-app -n openshift-gitops -o jsonpath='{.status.sync.status} - {.status.sync.revision}'
```

2. **Check ACM policy:**
```bash
# On hub cluster
oc get policy policy-webserver-app -n open-cluster-management-policies
```

3. **Check ConfigMap on ocp-hcp:**
```bash
# On ocp-hcp
oc get configmap application-content -n webserver-prod -o jsonpath='{.data.application\.html}' | grep -o '<title>[^<]*</title>'
```

4. **Check deployment annotation:**
```bash
# On ocp-hcp
oc get deployment webserver -n webserver-prod -o jsonpath='{.spec.template.metadata.annotations.config-version}'
```

5. **Check pod age:**
```bash
# On ocp-hcp
oc get pods -n webserver-prod
```

### Manual Force Sync
If auto-sync isn't working, force it manually:

```bash
# Force ArgoCD refresh (on hub)
oc annotate application acm-webserver-app -n openshift-gitops argocd.argoproj.io/refresh=normal --overwrite

# Force pod restart (on ocp-hcp)
oc rollout restart deployment webserver -n webserver-prod
```

## Example Update Workflow

```bash
# 1. Make changes
vim policies/webserver-app/webserver-policy.yaml
# - Update HTML on line 51
# - Increment config-version on line 85: "3" → "4"

# 2. Commit and push
git add policies/webserver-app/webserver-policy.yaml
git commit -m "Update homepage title - v4"
git push

# 3. Wait 3-5 minutes

# 4. Verify
cd /Users/pjalili/Projects && ./conn-ocp-hcp.sh
oc get pods -n webserver-prod  # Check pod age (should be < 5 min)
oc exec -n webserver-prod deployment/webserver -- cat /var/www/html/application.html | grep '<title>'
```

## Summary

✅ **What works now:**
- Change HTML + increment config-version → auto-deploy in 3-5 minutes
- No more manual pod restarts needed
- GitOps workflow: commit → ArgoCD → ACM → deployed

✅ **What you need to remember:**
- Always increment `config-version` when changing ConfigMap
- Wait 3-5 minutes for auto-sync
- Verify with `oc get pods -n webserver-prod` (pod age)

✅ **What was fixed:**
- Removed subPath (was blocking ConfigMap updates)
- Changed to mustonlyhave (forces ACM to update)
- Added config-version annotation (triggers restart)
