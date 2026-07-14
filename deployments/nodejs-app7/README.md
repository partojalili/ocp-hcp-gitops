# nodejs-app7

Node.js application deployment to **hcp-cluster**

## Configuration

- **Namespace:** `nodejs-app7`
- **Replicas:** 2
- **Image:** `quay.io/pjalili/nodejs-app`
- **Port:** 8080

## Deployment

This application is managed by ArgoCD and will automatically sync from Git.

### Manual Pipeline Trigger

To manually trigger the build pipeline:

```bash
oc create -f pipeline/pipelinerun.yaml -n nodejs-app7
```

### View Pipeline Runs

```bash
oc get pipelinerun -n nodejs-app7
```

### View Application

```bash
oc get all -n nodejs-app7
```


### Access Application

The application is exposed via OpenShift Route:

```bash
oc get route nodejs-app7 -n nodejs-app7
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
oc get deployment nodejs-app7 -n nodejs-app7
oc get pods -l app=nodejs-app7 -n nodejs-app7
oc logs -l app=nodejs-app7 -n nodejs-app7
```
