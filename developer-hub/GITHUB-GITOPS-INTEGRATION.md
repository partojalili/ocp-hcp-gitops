# GitHub GitOps Integration for Developer Hub

This guide explains how to enable full GitHub integration in Red Hat Developer Hub so it can automatically commit cluster configurations to your Git repository.

## Overview

By default, Developer Hub templates can only generate files locally. With GitHub App integration, Developer Hub can:
- ✅ Automatically commit files to your GitHub repository
- ✅ Create branches and pull requests
- ✅ Trigger ArgoCD sync automatically
- ✅ Provide full self-service cluster provisioning

## Prerequisites

- Red Hat Developer Hub installed and running
- GitHub account with admin access to your repository
- Access to `https://github.com/settings/apps`

---

## Step 1: Create GitHub App

### 1.1 Navigate to GitHub Apps

Open this URL in your browser:
```
https://github.com/settings/apps/new
```

### 1.2 Configure GitHub App Settings

Fill in the following fields:

| Field | Value |
|-------|-------|
| **GitHub App name** | `developer-hub-gitops-YOUR-USERNAME` (must be globally unique) |
| **Homepage URL** | `https://backstage-developer-hub-rhdh-operator.apps.cluster-q2pfv.dynamic2.redhatworkshops.io` |
| **Webhook URL** | `https://backstage-developer-hub-rhdh-operator.apps.cluster-q2pfv.dynamic2.redhatworkshops.io` |
| **Webhook Active** | ☐ Uncheck this box |

**Note:** Replace the URLs with your actual Developer Hub route if different.

### 1.3 Set Repository Permissions

Configure these permissions for the GitHub App:

| Permission | Access Level | Required For |
|------------|-------------|--------------|
| **Contents** | Read and write | Committing files, creating branches |
| **Pull requests** | Read and write | Creating PRs (optional) |
| **Metadata** | Read-only | Auto-selected, required |

**Important:** Only grant the minimum permissions needed.

### 1.4 Installation Scope

- Select: **Only on this account**

### 1.5 Create the App

Click **"Create GitHub App"** at the bottom of the page.

---

## Step 2: Generate Credentials

After creating the app, you need three pieces of information:

### 2.1 Get App ID

At the top of the GitHub App settings page:
```
App ID: 123456
```
Copy this number - this is your **App ID**.

### 2.2 Generate Private Key

1. Scroll down to **"Private keys"** section
2. Click **"Generate a private key"**
3. A `.pem` file will download automatically
4. **Save this file securely** - you'll need it in the next step

**Security Note:** 
- Never commit the `.pem` file to git
- Store it securely (password manager, vault, etc.)
- You cannot download it again - if lost, generate a new one

### 2.3 Install the App on Your Repository

1. In the left sidebar, click **"Install App"**
2. Click **"Install"** next to your GitHub account
3. Select: **Only select repositories**
4. Choose: `ocp-hcp-gitops` (or your repository name)
5. Click **"Install"**

### 2.4 Get Installation ID

After installation, check the URL in your browser:
```
https://github.com/settings/installations/12345678
```

The number at the end (e.g., `12345678`) is your **Installation ID**.

**Summary - You should now have:**
- ✅ App ID (e.g., `123456`)
- ✅ Installation ID (e.g., `12345678`)
- ✅ Private Key file (e.g., `developer-hub-gitops.2024-05-20.private-key.pem`)

---

## Step 3: Configure Developer Hub with GitHub App

### 3.1 Create GitHub App Secret

Create a Kubernetes secret containing your GitHub App credentials:

```bash
# Replace these values with your actual credentials
APP_ID="123456"
INSTALLATION_ID="12345678"
PRIVATE_KEY_FILE="path/to/your-github-app.private-key.pem"

# Create the secret
oc create secret generic backstage-github-app \
  -n rhdh-operator \
  --from-literal=APP_ID="$APP_ID" \
  --from-literal=CLIENT_ID="Iv1.XXXXXXXXXXXXXXXX" \
  --from-literal=CLIENT_SECRET="your-client-secret-here" \
  --from-literal=WEBHOOK_SECRET="" \
  --from-file=PRIVATE_KEY="$PRIVATE_KEY_FILE"
```

**Note:** You can find `CLIENT_ID` and `CLIENT_SECRET` on your GitHub App settings page.

### 3.2 Update GitHub Integration ConfigMap

Edit `github-integration-config.yaml` to use GitHub App authentication:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backstage-github-integration
  namespace: rhdh-operator
data:
  app-config-github.yaml: |
    integrations:
      github:
        - host: github.com
          apps:
            - appId: ${APP_ID}
              clientId: ${CLIENT_ID}
              clientSecret: ${CLIENT_SECRET}
              webhookSecret: ${WEBHOOK_SECRET}
              privateKey: |
                ${PRIVATE_KEY}

    # Scaffolder configuration
    scaffolder:
      defaultAuthor:
        name: Red Hat Developer Hub
        email: developer-hub@redhat.com
      defaultCommitMessage: 'Provisioned via Developer Hub'
```

### 3.3 Update Backstage Instance

Update `backstage-instance.yaml` to reference the GitHub App secret:

```yaml
spec:
  application:
    appConfig:
      configMaps:
        - name: backstage-guest-auth-config
        - name: backstage-github-integration
        - name: backstage-catalog-locations
    extraEnvs:
      secrets:
        - name: backstage-github-app
```

### 3.4 Apply Configuration

```bash
cd developer-hub

# Apply the updated ConfigMap
oc apply -f github-integration-config.yaml

# Apply the updated Backstage instance
oc apply -f backstage-instance.yaml

# Wait for pod to restart (~2 minutes)
oc get pods -n rhdh-operator -w
```

---

## Step 4: Update Software Template

Update the HCP cluster template to use GitHub App for commits:

Edit `templates/hcp-cluster-template/template.yaml`:

```yaml
steps:
  - id: fetch-base
    name: Fetch Skeleton
    action: fetch:template
    input:
      url: ./skeleton
      values:
        clusterName: ${{ parameters.clusterName }}
        baseDomain: ${{ parameters.baseDomain }}
        pullSecret: ${{ parameters.pullSecret }}
        workerReplicas: ${{ parameters.workerReplicas }}
        cpuCores: ${{ parameters.cpuCores }}
        memoryGi: ${{ parameters.memoryGi }}
        repoUrl: ${{ parameters.repoUrl }}

  - id: publish
    name: Publish to GitHub
    action: publish:github
    input:
      repoUrl: github.com?owner=partojalili&repo=ocp-hcp-gitops
      defaultBranch: main
      sourcePath: ./
      targetPath: clusters/${{ parameters.clusterName }}
      commitMessage: |
        Add HCP cluster: ${{ parameters.clusterName }}

        Cluster configuration:
        - Workers: ${{ parameters.workerReplicas }}
        - CPU: ${{ parameters.cpuCores }} cores
        - Memory: ${{ parameters.memoryGi }}Gi
        - Domain: ${{ parameters.baseDomain }}

        Provisioned via Red Hat Developer Hub

  - id: register
    name: Register Cluster
    action: catalog:register
    input:
      optional: true
      catalogInfoUrl: ${{ steps.publish.output.catalogInfoUrl }}
```

Commit and push the changes:

```bash
git add developer-hub/templates/hcp-cluster-template/template.yaml
git commit -m "Enable GitHub publish action in HCP cluster template"
git push
```

---

## Step 5: Test the Integration

### 5.1 Restart Developer Hub

```bash
# Delete pod to reload configuration
oc delete pod -l app.kubernetes.io/name=backstage -n rhdh-operator

# Wait for new pod to be ready
oc get pods -n rhdh-operator -w
```

### 5.2 Create a Test Cluster

1. Open Developer Hub in browser
2. Click **"Create"** → **"OpenShift HCP Cluster"**
3. Fill in the form:
   - Cluster Name: `test-cluster`
   - Base Domain: `apps.cluster-abc.redhat.com`
   - Pull Secret: (paste your pull secret)
   - Workers: 2
   - CPU: 4
   - Memory: 8
4. Click **"Create"**

### 5.3 Verify Automatic Commit

Check your GitHub repository:
```bash
# You should see a new commit in your repository:
# "Add HCP cluster: test-cluster"

# Or check via CLI:
git pull
ls clusters/test-cluster/
```

Expected output:
```
clusters/test-cluster/
├── base/
│   ├── hostedcluster.yaml
│   ├── nodepool.yaml
│   ├── namespace.yaml
│   ├── pull-secret.yaml
│   ├── ssh-key.yaml
│   └── kustomization.yaml
└── argocd/
    └── application.yaml
```

### 5.4 Monitor Cluster Provisioning

ArgoCD will automatically detect the new files and provision the cluster:

```bash
# Watch ArgoCD Application
oc get application test-cluster-hosted-cluster -n openshift-gitops

# Watch HostedCluster status
oc get hostedcluster test-cluster -n clusters-test-cluster -w
```

---

## Troubleshooting

### Issue: "GitHub App not configured" error

**Solution:**
1. Verify the secret exists:
   ```bash
   oc get secret backstage-github-app -n rhdh-operator
   ```
2. Check secret contains all required keys:
   ```bash
   oc get secret backstage-github-app -n rhdh-operator -o yaml
   ```
3. Verify environment variables are mounted:
   ```bash
   oc get pod -l app.kubernetes.io/name=backstage -n rhdh-operator -o yaml | grep -A 10 envFrom
   ```

### Issue: "Permission denied" when committing

**Solution:**
1. Verify GitHub App has **Contents: Read and write** permission
2. Check the app is installed on the correct repository
3. Verify Installation ID is correct:
   ```bash
   # Check GitHub App installation
   curl -H "Authorization: token YOUR_PERSONAL_ACCESS_TOKEN" \
        https://api.github.com/user/installations
   ```

### Issue: Template shows "publish:github action not found"

**Solution:**
1. Ensure the GitHub scaffolder plugin is enabled in dynamic plugins
2. Check pod logs for plugin loading errors:
   ```bash
   oc logs -l app.kubernetes.io/name=backstage -n rhdh-operator --tail=100 | grep github
   ```
3. Verify dynamic plugins ConfigMap exists:
   ```bash
   oc get configmap backstage-dynamic-plugins -n rhdh-operator
   ```

### Issue: Commits appear but not from GitHub App

**Solution:**
- If commits show as coming from your personal GitHub account instead of the app:
  1. Verify you're using `backstage-github-app` secret, not `backstage-github-secret` (PAT)
  2. Check the Backstage instance references the correct secret
  3. Restart the pod after fixing

---

## Security Best Practices

1. **Private Key Storage**
   - Store the `.pem` file in a secure location
   - Use Sealed Secrets for production deployments
   - Rotate keys periodically

2. **Minimal Permissions**
   - Only grant Contents: Read/write (not Admin)
   - Install app only on required repositories
   - Review app permissions regularly

3. **Secret Management**
   - Never commit `.pem` files to git
   - Use `.gitignore` to prevent accidental commits
   - Consider using External Secrets Operator for production

4. **Audit Trail**
   - GitHub App commits show as bot commits (good for auditing)
   - All cluster provisions are tracked in git history
   - Review GitHub App activity in Settings → Installed Apps

---

## Alternative: GitHub Personal Access Token (Not Recommended)

If you cannot create a GitHub App, you can use a Personal Access Token (PAT):

**Limitations:**
- ❌ Commits appear as your personal account
- ❌ Less secure (broader scope)
- ❌ Token expires (need rotation)
- ❌ No fine-grained permissions

**Only use PAT for testing/development, not production.**

---

## Additional Resources

- [GitHub Apps Documentation](https://docs.github.com/en/apps)
- [Backstage GitHub Integration](https://backstage.io/docs/integrations/github/github-apps)
- [RHDH GitHub Provider](https://access.redhat.com/documentation/en-us/red_hat_developer_hub)

## Support

For issues with:
- **GitHub App creation**: Check GitHub's documentation or support
- **Developer Hub integration**: Check Red Hat Developer Hub documentation
- **Cluster provisioning**: See main README.md troubleshooting section
