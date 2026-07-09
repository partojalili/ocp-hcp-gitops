# ${{ values.name }}

Node.js application deployment to **${{ values.targetCluster }}**

## Configuration

- **Namespace:** `${{ values.namespace }}`
- **Replicas:** ${{ values.replicas }}
- **Image:** `${{ values.imageRegistry }}/${{ values.imageRepository }}`
- **Port:** ${{ values.port }}

## Deployment

This application is managed by ArgoCD and will automatically sync from Git.

### Manual Pipeline Trigger

To manually trigger the build pipeline:

```bash
oc create -f pipeline/pipelinerun.yaml -n ${{ values.namespace }}
```

### View Pipeline Runs

```bash
oc get pipelinerun -n ${{ values.namespace }}
```

### View Application

```bash
oc get all -n ${{ values.namespace }}
```

{% if values.enableRoute %}
### Access Application

The application is exposed via OpenShift Route:

```bash
oc get route ${{ values.name }} -n ${{ values.namespace }}
```
{% endif %}

## CI/CD

{% if values.enablePipeline %}
The Tekton pipeline includes:

1. **git-clone** - Clone source code from GitHub
2. **build-image** - Build container image using Buildah
3. **update-deployment** - Update the deployment with new image
4. **verify-deployment** - Verify the deployment is healthy

### Webhook Integration

An EventListener is configured to trigger builds automatically on GitHub push events.
{% endif %}

## Monitoring

Check application health:

```bash
oc get deployment ${{ values.name }} -n ${{ values.namespace }}
oc get pods -l app=${{ values.name }} -n ${{ values.namespace }}
oc logs -l app=${{ values.name }} -n ${{ values.namespace }}
```
