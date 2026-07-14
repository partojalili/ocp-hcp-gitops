# nodejs-app1

Node.js application deployment to **hcp-cluster**

## Configuration

- **Namespace:** `nodejs-app1`
- **Replicas:** 1
- **Image:** `quay.io/partojalili/nodejs-app1`
- **Port:** 8080

## Deployment

This application is managed by ArgoCD and will automatically sync from Git.

### Manual Pipeline Trigger

To manually trigger the build pipeline:

```bash
oc create -f pipeline/pipelinerun.yaml -n nodejs-app1
```

### View Pipeline Runs

```bash
oc get pipelinerun -n nodejs-app1
```

### View Application

```bash
oc get all -n nodejs-app1
```


### Access Application

The application is exposed via OpenShift Route:

```bash
oc get route nodejs-app1 -n nodejs-app1
```


## CI/CD


The Tekton pipeline includes:

1. **git-clone** - Clone source code from GitHub
2. **build-image** - Build container image using Buildah
3. **update-deployment** - Update the deployment with new image
4. **verify-deployment** - Verify the deployment is healthy

### Webhook Integration

An EventListener is configured to trigger builds automatically on GitHub push events.


## Monitoring

Check application health:

```bash
oc get deployment nodejs-app1 -n nodejs-app1
oc get pods -l app=nodejs-app1 -n nodejs-app1
oc logs -l app=nodejs-app1 -n nodejs-app1
```
