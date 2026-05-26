# GitHub App Secret Setup Guide

This guide explains how to create the `backstage-github-app` secret for Red Hat Developer Hub with full GitHub App authentication.

## Table of Contents
- [Authentication Methods Comparison](#authentication-methods-comparison)
- [Prerequisites](#prerequisites)
- [Creating a GitHub App](#creating-a-github-app)
- [Creating the Secret](#creating-the-secret)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Authentication Methods Comparison

Developer Hub supports two authentication methods for GitHub integration:

### Simple Token Authentication (Basic)

**Secret Name:** `backstage-github-secret`

**Fields:**
```yaml
GITHUB_TOKEN: ghp_xxxxxxxxxxxx
```

**Use Cases:**
- Quick testing/development
- Simple read-only catalog integration
- Personal projects

**Limitations:**
- ❌ No webhook support (manual catalog refresh only)
- ❌ Lower rate limits (5,000 requests/hour)
- ❌ Acts as a specific user (not organization-level)
- ❌ Broad token permissions
- ❌ Not recommended for production

### GitHub App Authentication (Production)

**Secret Name:** `backstage-github-app`

**Fields:**
```yaml
APP_ID: "123456"
CLIENT_ID: "Iv1.xxxxxxxxxxxxxx"
CLIENT_SECRET: "xxxxxxxxxxxxxxxxxxxxx"
WEBHOOK_SECRET: "random-secret-string"
PRIVATE_KEY: "-----BEGIN RSA PRIVATE KEY-----..."
```

**Use Cases:**
- Production deployments
- Organization-wide installations
- Self-service cluster provisioning
- Automated GitOps workflows

**Advantages:**
- ✅ **Webhook support** - Real-time catalog updates
- ✅ **Higher rate limits** (15,000 requests/hour per repository)
- ✅ Acts as an app (independent of user accounts)
- ✅ **Fine-grained repository permissions**
- ✅ Better audit trail (commits show as bot, not user)
- ✅ **Production-ready and secure**

---

## Prerequisites

Before creating the GitHub App:

1. **Admin access** to your GitHub organization or personal account
2. **OpenShift cluster** with Red Hat Developer Hub deployed
3. **Developer Hub route URL** - Get it with:
   ```bash
   oc get route backstage-developer-hub -n rhdh-operator -o jsonpath='{.spec.host}'
   ```

4. **Sealed Secrets Controller** (for production):
   ```bash
   oc get pods -n sealed-secrets-controller
   ```

---

## Creating a GitHub App

### Step 1: Generate Webhook Secret

First, generate a secure random string for the webhook secret:

```bash
openssl rand -base64 32
```

Save this output - you'll need it later. Example output:
```
DyswkkTwh47WmLVhfJDBt5WNd2vZH2YftqSeIHq8TUA=
```

### Step 2: Register the GitHub App

1. **Navigate to GitHub App settings:**
   - Organization: `https://github.com/organizations/YOUR_ORG/settings/apps/new`
   - Personal: `https://github.com/settings/apps/new`

2. **Fill in the following fields:**

   **GitHub App name:** `Developer Hub - [your-cluster-name]`
   - Must be globally unique across all GitHub
   - Example: `Developer Hub - Production OCP`

   **Homepage URL:**
   ```
   https://backstage-developer-hub-rhdh-operator.apps.cluster-gzk6k.dynamic2.redhatworkshops.io
   ```
   _(Use your actual route URL)_

   **Webhook URL:**
   ```
   https://backstage-developer-hub-rhdh-operator.apps.cluster-gzk6k.dynamic2.redhatworkshops.io/api/github/webhook
   ```

   **Webhook secret:**
   - Paste the random string generated in Step 1

3. **Set Repository Permissions:**

   - **Contents:** `Read & write` _(Required for committing files)_
   - **Metadata:** `Read-only` _(Automatically required)_
   - **Pull requests:** `Read & write` _(For creating PRs)_
   - **Webhooks:** `Read & write` _(For catalog updates)_
   - **Administration:** `Read & write` _(For repository management)_

4. **Set Organization Permissions:**

   - **Members:** `Read-only` _(For user/team discovery)_

5. **Subscribe to Events:**

   - [x] **Push** - Triggers catalog refresh on commits
   - [x] **Pull request** - Updates catalog when PRs change

6. **Installation Access:**

   - Select: **Only on this account**

7. **Click "Create GitHub App"**

### Step 3: Collect Credentials

After creating the app, you'll see the app settings page:

1. **App ID:** Note this down (shown at the top of the page)
   - Example: `123456`

2. **Client ID:** Copy this value
   - Example: `Iv1.abc123def456`

3. **Generate Client Secret:**
   - Click **Generate a new client secret**
   - Copy the secret immediately (it won't be shown again)
   - Example: `abc123def456...`

4. **Generate Private Key:**
   - Scroll to **Private keys** section
   - Click **Generate a private key**
   - A `.pem` file will download to your computer
   - **Keep this file secure!**

### Step 4: Install the App

1. Click **Install App** (left sidebar)
2. Select your organization/account
3. Choose installation type:
   - **All repositories** - App has access to all repos
   - **Only select repositories** - Recommended for security
4. Select `ocp-hcp-gitops` repository (or your specific repos)
5. Click **Install**

---

## Creating the Secret

You now have all the values needed to create the secret.

### Option A: Using kubectl/oc with Files (Recommended for Production)

1. **Save the private key:**
   ```bash
   # Move the downloaded .pem file to a secure location
   mv ~/Downloads/your-app-name.*.private-key.pem /tmp/github-app-private-key.pem
   
   # Verify the file format
   head -n 1 /tmp/github-app-private-key.pem
   # Should show: -----BEGIN RSA PRIVATE KEY-----
   ```

2. **Create the secret:**
   ```bash
   oc create secret generic backstage-github-app \
     -n rhdh-operator \
     --from-literal=APP_ID="123456" \
     --from-literal=CLIENT_ID="Iv1.abc123def456" \
     --from-literal=CLIENT_SECRET="your_client_secret_here" \
     --from-literal=WEBHOOK_SECRET="DyswkkTwh47WmLVhfJDBt5WNd2vZH2YftqSeIHq8TUA=" \
     --from-file=PRIVATE_KEY=/tmp/github-app-private-key.pem
   ```

3. **Clean up the private key file:**
   ```bash
   rm /tmp/github-app-private-key.pem
   ```

### Option B: Using YAML (For Development/Testing)

1. **Create the secret YAML:**
   ```bash
   cat > /tmp/github-app-secret.yaml <<'EOF'
   apiVersion: v1
   kind: Secret
   metadata:
     name: backstage-github-app
     namespace: rhdh-operator
   type: Opaque
   stringData:
     APP_ID: "123456"
     CLIENT_ID: "Iv1.abc123def456"
     CLIENT_SECRET: "your_client_secret_here"
     WEBHOOK_SECRET: "DyswkkTwh47WmLVhfJDBt5WNd2vZH2YftqSeIHq8TUA="
     PRIVATE_KEY: |
       -----BEGIN RSA PRIVATE KEY-----
       MIIEpAIBAAKCAQEA1234567890abcdef...
       [Paste entire private key content here]
       ...xyz890
       -----END RSA PRIVATE KEY-----
   EOF
   ```

2. **Apply the secret:**
   ```bash
   oc apply -f /tmp/github-app-secret.yaml
   ```

3. **Delete the temporary file:**
   ```bash
   rm /tmp/github-app-secret.yaml
   ```

### Option C: Using Sealed Secrets (Production - Most Secure)

For production, use Sealed Secrets to encrypt the secret before committing to Git:

1. **Create temporary secret file:**
   ```bash
   cat > /tmp/github-app-secret.yaml <<'EOF'
   apiVersion: v1
   kind: Secret
   metadata:
     name: backstage-github-app
     namespace: rhdh-operator
   type: Opaque
   stringData:
     APP_ID: "123456"
     CLIENT_ID: "Iv1.abc123def456"
     CLIENT_SECRET: "your_client_secret_here"
     WEBHOOK_SECRET: "DyswkkTwh47WmLVhfJDBt5WNd2vZH2YftqSeIHq8TUA="
     PRIVATE_KEY: |
       -----BEGIN RSA PRIVATE KEY-----
       [Your private key content]
       -----END RSA PRIVATE KEY-----
   EOF
   ```

2. **Encrypt using kubeseal:**
   ```bash
   kubeseal --format=yaml \
     --controller-name=sealed-secrets-controller \
     --controller-namespace=sealed-secrets-controller \
     < /tmp/github-app-secret.yaml \
     > developer-hub/github-app-sealed-secret.yaml
   ```

3. **Verify the sealed secret:**
   ```bash
   cat developer-hub/github-app-sealed-secret.yaml | head -20
   ```

4. **Apply the sealed secret:**
   ```bash
   oc apply -f developer-hub/github-app-sealed-secret.yaml
   ```

5. **Clean up temporary files:**
   ```bash
   rm /tmp/github-app-secret.yaml
   rm /tmp/github-app-private-key.pem
   ```

6. **Commit to Git (SAFE - it's encrypted!):**
   ```bash
   git add developer-hub/github-app-sealed-secret.yaml
   git commit -m "Add encrypted GitHub App credentials"
   git push
   ```

---

## Verification

### Step 1: Verify Secret Creation

```bash
# Check if secret exists
oc get secret backstage-github-app -n rhdh-operator

# Verify it has all required fields
oc get secret backstage-github-app -n rhdh-operator -o jsonpath='{.data}' | jq -r 'keys'
```

Expected output:
```json
[
  "APP_ID",
  "CLIENT_ID",
  "CLIENT_SECRET",
  "PRIVATE_KEY",
  "WEBHOOK_SECRET"
]
```

### Step 2: Verify Developer Hub Configuration

```bash
# Check Backstage CR references the secret
oc get backstage developer-hub -n rhdh-operator -o yaml | grep -A 5 "extraEnvs"
```

Expected output:
```yaml
extraEnvs:
  secrets:
  - name: backstage-github-app
```

### Step 3: Check Developer Hub Deployment

```bash
# Verify deployment is healthy
oc get pods -n rhdh-operator

# Check logs for GitHub integration
oc logs -n rhdh-operator deployment/backstage-developer-hub | grep -i github
```

### Step 4: Test GitHub Integration

1. **Access Developer Hub:**
   ```bash
   echo "https://$(oc get route backstage-developer-hub -n rhdh-operator -o jsonpath='{.spec.host}')"
   ```

2. **Check catalog:**
   - Navigate to the Developer Hub UI
   - Go to **Create** → Should see your templates
   - Templates should load from GitHub

3. **Test webhook:**
   ```bash
   # Make a change to your template in GitHub
   # Wait 5 minutes or trigger manual refresh
   # Catalog should update automatically
   ```

---

## Troubleshooting

### Secret Not Found

**Error:** `Secret "backstage-github-app" not found`

**Solution:**
```bash
# Verify namespace
oc project rhdh-operator

# List all secrets
oc get secrets | grep github

# Recreate secret if missing (see Creating the Secret section)
```

### Missing Fields in Secret

**Error:** `failed to get external config from backstage-github-app`

**Solution:**
```bash
# Check which fields are present
oc get secret backstage-github-app -n rhdh-operator -o jsonpath='{.data}' | jq -r 'keys'

# Should show: APP_ID, CLIENT_ID, CLIENT_SECRET, PRIVATE_KEY, WEBHOOK_SECRET
# Delete and recreate if any are missing
oc delete secret backstage-github-app -n rhdh-operator
# Then recreate using one of the methods above
```

### Private Key Format Issues

**Error:** `Error: Invalid PEM formatted message`

**Solution:**
```bash
# Verify private key format
oc get secret backstage-github-app -n rhdh-operator -o jsonpath='{.data.PRIVATE_KEY}' | base64 -d | head -1

# Should output: -----BEGIN RSA PRIVATE KEY-----
# If not, the key wasn't formatted correctly
# Recreate with proper format (ensure no extra spaces or newlines)
```

### GitHub App Not Authenticating

**Error:** Catalog shows "GitHub authentication failed"

**Check:**
1. Verify App ID matches the GitHub App
   ```bash
   oc get secret backstage-github-app -n rhdh-operator -o jsonpath='{.data.APP_ID}' | base64 -d
   ```

2. Verify Client ID is correct
   ```bash
   oc get secret backstage-github-app -n rhdh-operator -o jsonpath='{.data.CLIENT_ID}' | base64 -d
   ```

3. Check GitHub App installation:
   - Go to: `https://github.com/settings/installations`
   - Verify app is installed on correct repositories

### Webhook Not Working

**Error:** Catalog doesn't auto-refresh when GitHub changes

**Check:**
1. Verify webhook URL is correct in GitHub App settings
2. Check webhook deliveries:
   - GitHub App settings → Advanced → Recent Deliveries
   - Look for failed deliveries and error messages

3. Verify webhook secret matches:
   ```bash
   oc get secret backstage-github-app -n rhdh-operator -o jsonpath='{.data.WEBHOOK_SECRET}' | base64 -d
   ```

### Pod Crashes After Secret Creation

**Check logs:**
```bash
oc logs -n rhdh-operator deployment/backstage-developer-hub --tail=100
```

**Common issues:**
- Private key formatting
- Client secret typos
- App not installed on the repository

---

## Security Best Practices

1. **Never commit unencrypted secrets to Git**
   - Always use Sealed Secrets for production
   - Add `*-secret.yaml` to `.gitignore`

2. **Rotate credentials regularly**
   - Generate new client secrets every 90 days
   - Regenerate private keys annually

3. **Use minimal permissions**
   - Only grant permissions needed for your use case
   - Don't install on all repositories unless necessary

4. **Monitor GitHub App activity**
   - Check GitHub audit logs regularly
   - Review webhook deliveries for suspicious activity

5. **Store private keys securely**
   - Delete local `.pem` files after creating secret
   - Don't store in browser downloads folder

---

## Next Steps

After creating the secret:

1. **Configure catalog locations** - See `catalog-locations-config.yaml`
2. **Deploy cluster templates** - See `templates/hcp-cluster-template/`
3. **Test self-service provisioning** - Create a test cluster
4. **Monitor ArgoCD sync** - Verify GitOps automation works

---

## References

- [Red Hat Developer Hub Documentation](https://access.redhat.com/documentation/en-us/red_hat_developer_hub/)
- [GitHub Apps Documentation](https://docs.github.com/en/apps)
- [Backstage GitHub Integration](https://backstage.io/docs/integrations/github/locations)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
