# Red Hat OpenShift Dev Spaces Setup

This guide covers installing and configuring Red Hat OpenShift Dev Spaces to provide cloud-based development environments for your applications scaffolded through Developer Hub.

## Overview

Red Hat OpenShift Dev Spaces provides browser-based IDEs (VS Code) with pre-configured development environments. When integrated with Developer Hub templates, developers can click a link and start coding instantly—no local setup required.

**Benefits:**
- ✅ One-click launch from Developer Hub catalog
- ✅ Zero local environment setup
- ✅ Pre-configured dev containers with dependencies
- ✅ Consistent development environments across teams
- ✅ Integrated databases and services
- ✅ Works from any device with a browser

## Prerequisites

- OpenShift cluster with cluster-admin access
- `oc` CLI installed and logged in
- At least 8Gi memory available for Dev Spaces components

## Installation Steps

### Step 1: Create Namespace and Install Operator

Create the namespace and operator subscription:

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-devspaces
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: devspaces-operator-group
  namespace: openshift-devspaces
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: devspaces
  namespace: openshift-devspaces
spec:
  channel: stable
  installPlanApproval: Automatic
  name: devspaces
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

**Wait for operator installation** (~1-2 minutes):

```bash
oc get csv -n openshift-devspaces -w
```

**Expected output when ready:**
```
NAME                        DISPLAY                        VERSION   REPLACES                    PHASE
devspacesoperator.v3.28.1   Red Hat OpenShift Dev Spaces   3.28.1    devspacesoperator.v3.28.0   Succeeded
```

Press `Ctrl+C` to exit the watch.

**Verify operator pod is running:**
```bash
oc get pods -n openshift-devspaces
```

You should see:
```
NAME                                  READY   STATUS    RESTARTS   AGE
devspaces-operator-XXXXXXXXXX-XXXXX   1/1     Running   0          2m
```

### Step 2: Deploy Dev Spaces Instance

Create the CheCluster custom resource to deploy Dev Spaces:

```bash
cat <<EOF | oc apply -f -
apiVersion: org.eclipse.che/v2
kind: CheCluster
metadata:
  name: devspaces
  namespace: openshift-devspaces
spec:
  components:
    cheServer:
      debug: false
      logLevel: INFO
    metrics:
      enable: true
    pluginRegistry:
      openVSXURL: https://open-vsx.org
  containerRegistry: {}
  devEnvironments:
    startTimeoutSeconds: 600
    secondsOfRunBeforeIdling: -1
    maxNumberOfWorkspacesPerUser: -1
    maxNumberOfRunningWorkspacesPerUser: 5
    containerBuildConfiguration:
      openShiftSecurityContextConstraint: container-build
    disableContainerBuildCapabilities: false
    defaultEditor: che-incubator/che-code/latest
    defaultNamespace:
      autoProvision: true
      template: <username>-devspaces
    secondsOfInactivityBeforeIdling: 1800
    storage:
      pvcStrategy: per-user
  gitServices: {}
  networking: {}
EOF
```

**Monitor deployment** (~2-3 minutes):

```bash
# Watch CheCluster status
oc get checluster -n openshift-devspaces -w

# Watch pods
oc get pods -n openshift-devspaces -w
```

**Wait for status to show "Active":**
```bash
oc get checluster -n openshift-devspaces devspaces -o jsonpath='{.status.chePhase}'
# Output: Active
```

**Expected pods when ready:**
```
NAME                                   READY   STATUS    RESTARTS   AGE
che-gateway-XXXXXXXXXX-XXXXX           4/4     Running   0          3m
devspaces-XXXXXXXXXX-XXXXX             1/1     Running   0          2m
devspaces-dashboard-XXXXXXXXXX-XXXXX   1/1     Running   0          3m
devspaces-operator-XXXXXXXXXX-XXXXX    1/1     Running   0          5m
```

### Step 3: Get Dev Spaces URL

Retrieve the Dev Spaces URL:

```bash
# Get URL from CheCluster status
oc get checluster -n openshift-devspaces devspaces -o jsonpath='{.status.cheURL}'

# Or from route
echo "https://$(oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}')"
```

**Example output:**
```
https://devspaces.apps.cluster-XXXXX.domain.com
```

Open this URL in your browser to access Dev Spaces.

### Step 4: Verify Installation

Test that Dev Spaces is working:

1. **Open Dev Spaces URL** in your browser
2. **Log in** using your OpenShift credentials
3. You should see the Dev Spaces dashboard

**Check all components are healthy:**
```bash
# Check CheCluster status
oc get checluster -n openshift-devspaces devspaces -o yaml | grep -A 5 status

# Verify route is accessible
curl -k -I https://$(oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}')
```

Expected HTTP status: `200 OK`

## Integrating with Developer Hub Templates

To enable "Open in Dev Spaces" functionality for applications scaffolded through Developer Hub, you need to add two files to your template's skeleton directory.

### 1. Add devfile.yaml to Template Skeleton

Create `devfile.yaml` in your template's skeleton directory. Here's an example for a Node.js application:

**File:** `developer-hub/templates/YOUR-TEMPLATE/skeleton/devfile.yaml`

```yaml
schemaVersion: 2.2.0
metadata:
  name: ${{ values.name }}
  displayName: ${{ values.name }}
  description: ${{ values.description }}
  tags:
    - Node.js
    - Express
  projectType: Node.js
  language: JavaScript
  version: 1.0.0

components:
  # Main development container
  - name: nodejs
    container:
      image: registry.redhat.io/devspaces/udi-rhel8:latest
      memoryLimit: 1Gi
      memoryRequest: 512Mi
      cpuLimit: 1000m
      cpuRequest: 200m
      mountSources: true
      sourceMapping: /projects
      endpoints:
        - name: nodejs
          targetPort: 3000
          exposure: public
          protocol: http
      env:
        - name: NODE_ENV
          value: development

  # Optional: Add database or other services
  - name: mongodb
    container:
      image: registry.redhat.io/rhel8/mongodb-42:latest
      memoryLimit: 512Mi
      memoryRequest: 256Mi
      mountSources: false
      endpoints:
        - name: mongodb
          targetPort: 27017
          exposure: internal
      env:
        - name: MONGODB_USER
          value: user
        - name: MONGODB_PASSWORD
          value: password
        - name: MONGODB_DATABASE
          value: myapp

commands:
  - id: install-dependencies
    exec:
      component: nodejs
      workingDir: ${PROJECT_SOURCE}
      commandLine: npm install
      group:
        kind: build
        isDefault: true

  - id: run-dev
    exec:
      component: nodejs
      workingDir: ${PROJECT_SOURCE}
      commandLine: npm run dev
      group:
        kind: run
        isDefault: true

  - id: test
    exec:
      component: nodejs
      workingDir: ${PROJECT_SOURCE}
      commandLine: npm test
      group:
        kind: test

events:
  postStart:
    - install-dependencies
```

**Key sections explained:**
- **components.nodejs**: Main development container with VS Code
- **components.mongodb**: Optional database service
- **commands**: Available actions (install, run, test)
- **events.postStart**: Runs automatically when workspace starts
- **endpoints**: Exposed ports for accessing your app

### 2. Add Dev Spaces Link to catalog-info.yaml

Update your template's `catalog-info.yaml` to include a Dev Spaces link:

**File:** `developer-hub/templates/YOUR-TEMPLATE/skeleton/catalog-info.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.name }}
  description: ${{ values.description }}
  annotations:
    github.com/project-slug: ${{ values.repoUrl | projectSlug }}
  tags:
    - nodejs
  links:
    - url: https://github.com/${{ values.repoUrl | projectSlug }}
      title: GitHub Repository
      icon: github
    # Add this Dev Spaces link
    - url: https://devspaces.apps.YOUR-CLUSTER-DOMAIN.com/#https://github.com/${{ values.repoUrl | projectSlug }}
      title: Open in Dev Spaces
      icon: catalog
spec:
  type: service
  lifecycle: experimental
  owner: ${{ values.owner }}
```

**Replace `YOUR-CLUSTER-DOMAIN.com`** with your actual cluster domain. Get it with:
```bash
oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}'
```

## Using Dev Spaces with Scaffolded Applications

### Method 1: From Developer Hub Catalog (Recommended)

1. **Scaffold an application** using a Developer Hub template
2. **Merge the PR** created by the scaffolder
3. **Find the component** in the Developer Hub catalog
4. **Click "Open in Dev Spaces"** link in the component page
5. Dev Spaces will:
   - Clone your repository
   - Start containers defined in devfile.yaml
   - Run post-start commands (e.g., `npm install`)
   - Open VS Code in your browser

### Method 2: Direct URL

Open any GitHub repository directly in Dev Spaces:

```
https://devspaces.apps.YOUR-CLUSTER.com/#https://github.com/OWNER/REPO
```

**Example:**
```
https://devspaces.apps.cluster-r8knr.redhat.com/#https://github.com/myorg/myapp
```

### Method 3: From Dashboard

1. Open Dev Spaces dashboard
2. Click **"Create Workspace"**
3. Enter your Git repository URL
4. Click **"Create & Open"**

## Configuration

### Customize Workspace Resources

Adjust memory and CPU limits in the CheCluster CR:

```bash
oc patch checluster devspaces -n openshift-devspaces --type=merge -p '
spec:
  devEnvironments:
    containerBuildConfiguration:
      openShiftSecurityContextConstraint: container-build
    storage:
      pvcStrategy: per-user
      pvcSize: 10Gi
'
```

### Set Workspace Idle Timeout

Configure automatic workspace shutdown after inactivity:

```bash
oc patch checluster devspaces -n openshift-devspaces --type=merge -p '
spec:
  devEnvironments:
    secondsOfInactivityBeforeIdling: 1800  # 30 minutes
    secondsOfRunBeforeIdling: -1           # Never idle based on runtime
'
```

### Limit Workspaces per User

```bash
oc patch checluster devspaces -n openshift-devspaces --type=merge -p '
spec:
  devEnvironments:
    maxNumberOfWorkspacesPerUser: 5
    maxNumberOfRunningWorkspacesPerUser: 2
'
```

## Devfile Examples

### Python/Flask Application

```yaml
schemaVersion: 2.2.0
metadata:
  name: python-flask-app
components:
  - name: python
    container:
      image: registry.redhat.io/devspaces/udi-rhel8:latest
      memoryLimit: 1Gi
      endpoints:
        - name: flask
          targetPort: 5000
      env:
        - name: FLASK_ENV
          value: development
commands:
  - id: install
    exec:
      component: python
      commandLine: pip install -r requirements.txt
      group:
        kind: build
        isDefault: true
  - id: run
    exec:
      component: python
      commandLine: python app.py
      group:
        kind: run
        isDefault: true
events:
  postStart:
    - install
```

### Java/Quarkus Application

```yaml
schemaVersion: 2.2.0
metadata:
  name: quarkus-app
components:
  - name: tools
    container:
      image: registry.redhat.io/devspaces/udi-rhel8:latest
      memoryLimit: 2Gi
      endpoints:
        - name: quarkus
          targetPort: 8080
      env:
        - name: MAVEN_OPTS
          value: -Xmx1024m
commands:
  - id: build
    exec:
      component: tools
      commandLine: mvn clean package
      group:
        kind: build
        isDefault: true
  - id: run
    exec:
      component: tools
      commandLine: mvn quarkus:dev
      group:
        kind: run
        isDefault: true
```

### React/TypeScript Application

```yaml
schemaVersion: 2.2.0
metadata:
  name: react-app
components:
  - name: nodejs
    container:
      image: registry.redhat.io/devspaces/udi-rhel8:latest
      memoryLimit: 2Gi
      endpoints:
        - name: react
          targetPort: 3000
          attributes:
            urlRewriteSupported: true
commands:
  - id: install
    exec:
      component: nodejs
      commandLine: npm install
      group:
        kind: build
  - id: build
    exec:
      component: nodejs
      commandLine: npm run build
      group:
        kind: build
        isDefault: true
  - id: dev
    exec:
      component: nodejs
      commandLine: npm start
      group:
        kind: run
        isDefault: true
```

## Troubleshooting

### Issue: Workspace won't start

**Check workspace logs:**
```bash
# List workspaces
oc get devworkspace -A

# Check specific workspace
oc describe devworkspace WORKSPACE-NAME -n USERNAME-devspaces

# View workspace logs
oc logs -n USERNAME-devspaces deployment/WORKSPACE-NAME
```

**Common causes:**
- Insufficient cluster resources (memory/CPU)
- Invalid devfile.yaml syntax
- Image pull errors
- Missing permissions

### Issue: Cannot access workspace URL

**Verify route exists:**
```bash
oc get routes -n USERNAME-devspaces
```

**Check ingress/route configuration:**
```bash
oc get checluster devspaces -n openshift-devspaces -o yaml | grep -A 10 networking
```

### Issue: Slow workspace startup

**Increase timeout:**
```bash
oc patch checluster devspaces -n openshift-devspaces --type=merge -p '
spec:
  devEnvironments:
    startTimeoutSeconds: 900
'
```

**Check if image is cached:**
```bash
# Pre-pull images on nodes
oc get nodes -o name | xargs -I {} oc debug {} -- chroot /host podman pull registry.redhat.io/devspaces/udi-rhel8:latest
```

### Issue: Dev Spaces dashboard not loading

**Check all components are running:**
```bash
oc get pods -n openshift-devspaces

# Check logs
oc logs deployment/devspaces -n openshift-devspaces
oc logs deployment/devspaces-dashboard -n openshift-devspaces
```

**Verify route TLS:**
```bash
oc get route devspaces -n openshift-devspaces -o yaml | grep tls -A 5
```

### Issue: Workspace storage full

**Check PVC usage:**
```bash
oc get pvc -n USERNAME-devspaces
oc describe pvc -n USERNAME-devspaces
```

**Increase PVC size:**
```bash
oc patch checluster devspaces -n openshift-devspaces --type=merge -p '
spec:
  devEnvironments:
    storage:
      pvcSize: 20Gi
'
```

### Issue: Git authentication fails in workspace

**Add Git credentials to workspace:**

Dev Spaces automatically mounts Git credentials if you authenticate through the dashboard. For manual setup:

```bash
# In workspace terminal
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# For HTTPS repositories (use PAT)
git config --global credential.helper store
```

## Monitoring and Metrics

### View Dev Spaces Metrics

Dev Spaces exposes Prometheus metrics:

```bash
# Check if metrics are enabled
oc get checluster devspaces -n openshift-devspaces -o jsonpath='{.spec.components.metrics.enable}'

# Access metrics endpoint
oc port-forward -n openshift-devspaces svc/devspaces 8087:8087
# Then visit http://localhost:8087/metrics
```

### Common Metrics

- `che_workspace_started_total` - Total workspaces started
- `che_workspace_stopped_total` - Total workspaces stopped
- `che_workspace_running` - Currently running workspaces
- `che_workspace_start_time_seconds` - Workspace startup duration

## Backup and Restore

### Backup Dev Spaces Configuration

```bash
# Backup CheCluster CR
oc get checluster devspaces -n openshift-devspaces -o yaml > devspaces-backup.yaml

# Backup user workspaces
oc get devworkspace -A -o yaml > workspaces-backup.yaml
```

### Restore from Backup

```bash
# Restore CheCluster
oc apply -f devspaces-backup.yaml

# Restore workspaces
oc apply -f workspaces-backup.yaml
```

## Uninstallation

To completely remove Dev Spaces:

```bash
# Delete all workspaces first
oc delete devworkspace --all -A

# Delete CheCluster instance
oc delete checluster devspaces -n openshift-devspaces

# Delete operator subscription
oc delete subscription devspaces -n openshift-devspaces

# Delete CSV
oc delete csv -n openshift-devspaces -l operators.coreos.com/devspaces.openshift-devspaces

# Delete namespace
oc delete namespace openshift-devspaces

# Clean up user workspace namespaces (if any)
oc get namespaces | grep "\-devspaces" | awk '{print $1}' | xargs oc delete namespace
```

## Additional Resources

- [Red Hat OpenShift Dev Spaces Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_dev_spaces)
- [Devfile 2.2.0 Specification](https://devfile.io/docs/2.2.0/)
- [Dev Spaces on GitHub](https://github.com/redhat-developer/devspaces)
- [Eclipse Che Documentation](https://eclipse.dev/che/docs/)
- [Devfile Registry](https://registry.devfile.io/)

## Support

For issues and questions:
- Red Hat Support Portal: https://access.redhat.com/support
- Dev Spaces GitHub Issues: https://github.com/redhat-developer/devspaces/issues
- Devfile Slack: https://devfile.io/community
