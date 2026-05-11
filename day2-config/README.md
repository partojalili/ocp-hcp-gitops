# Day 2 Operations Configuration

This directory contains Day 2 operational configurations for OpenShift clusters.

## Network Policies

The `network-policies/` folder contains baseline network security policies:

### Policies Included

1. **deny-all-default.yaml** - Default deny-all policy (zero-trust baseline)
2. **allow-dns.yaml** - Allow DNS queries (UDP/TCP port 53)
3. **allow-ingress-controller.yaml** - Allow traffic from OpenShift ingress controller
4. **allow-monitoring.yaml** - Allow monitoring system access (ports 8443, 8080)

### Security Model

These policies implement a **zero-trust network security** approach:
- Default deny all traffic (ingress and egress)
- Explicitly allow only required traffic patterns
- Applied to all pods in the `baseline-policies` namespace

### Deployment

**Using Kustomize:**
```bash
oc apply -k day2-config/network-policies/
```

**Using ArgoCD:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: network-policies
spec:
  source:
    repoURL: https://github.com/partojalili/ocp-hcp-gitops.git
    targetRevision: main
    path: day2-config/network-policies
  destination:
    namespace: baseline-policies
```

### Network Policy Details

| Policy | Type | Purpose |
|--------|------|---------|
| deny-all | Ingress + Egress | Blocks all traffic by default |
| allow-dns | Egress | Permits DNS resolution |
| allow-from-ingress | Ingress | Allows OpenShift router traffic |
| allow-from-monitoring | Ingress | Permits monitoring on ports 8443, 8080 |

All policies apply to all pods in the namespace (empty `podSelector: {}`).

### Requirements

- Namespace: `baseline-policies` (auto-created)
- OpenShift cluster with NetworkPolicy support
- Namespaces must be labeled appropriately:
  - Ingress: `network.openshift.io/policy-group=ingress`
  - Monitoring: `network.openshift.io/policy-group=monitoring`
