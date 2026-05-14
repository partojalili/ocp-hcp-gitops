# GitOps Flow: From Git to Cluster

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 1: Developer Makes Changes                                            │
└─────────────────────────────────────────────────────────────────────────────┘

Developer Workstation
├── Edit: policies/webserver-app/webserver-policy.yaml
│   └── Change: HTML title + increment config-version
├── Git commit: "Update webserver to v5"
└── Git push: → GitHub

                              ↓

┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 2: GitHub Repository Updated                                          │
└─────────────────────────────────────────────────────────────────────────────┘

GitHub Repository
https://github.com/partojalili/ocp-hcp-gitops.git
├── Branch: main
├── Commit: 4c14342
└── Changed Files:
    └── policies/webserver-app/webserver-policy.yaml
        ├── Line 51: HTML content (title changed)
        └── Line 85: config-version: "4" → "5"

                              ↓ (~3 minutes)
                         ArgoCD polls Git
                    (or webhook triggers sync)

┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 3: ArgoCD Detects Changes (Hub Cluster)                               │
└─────────────────────────────────────────────────────────────────────────────┘

Hub Cluster (cluster-nwjrk)
Namespace: openshift-gitops

ArgoCD Application: acm-webserver-app
├── Monitors: https://github.com/partojalili/ocp-hcp-gitops.git
├── Path: policies/webserver-app
├── Target: main branch
├── Current Revision: 4c14342 (latest)
└── Sync Status: OutOfSync → Syncing...

ArgoCD Application Controller:
├── Fetches: policies/webserver-app/* from Git
├── Compares: Git state vs Hub cluster state
├── Detects: Policy spec changed
└── Action: Sync to Hub cluster

                              ↓ (~30 seconds)

┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 4: ArgoCD Applies to Hub Cluster                                      │
└─────────────────────────────────────────────────────────────────────────────┘

Hub Cluster (cluster-nwjrk)
Namespace: open-cluster-management-policies

ArgoCD applies:
├── kubectl apply -f webserver-policy.yaml
├── kubectl apply -f placement.yaml
└── kubectl apply -f placementbinding.yaml

Resources Created/Updated:
├── Policy: policy-webserver-app
│   ├── remediationAction: enforce
│   ├── complianceType: mustonlyhave (forces updates!)
│   └── Contains:
│       ├── ConfigMap with new HTML (title changed)
│       └── Deployment with config-version: "5"
│
├── Placement: placement-webserver-app
│   └── Selects: ManagedClusters with label "environment=production"
│
└── PlacementBinding: binding-policy-webserver-app
    └── Binds: Policy → Placement

ArgoCD Status:
└── Sync Status: Synced ✓
    └── Revision: 4c14342

                              ↓ (~10-30 seconds)
                         ACM Policy Controller
                         detects policy change

┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 5: ACM Policy Controller (Hub Cluster)                                │
└─────────────────────────────────────────────────────────────────────────────┘

Hub Cluster Components:

1. Placement Controller:
   ├── Reads: Placement (placement-webserver-app)
   ├── Queries: ManagedClusters
   ├── Matches: ocp-hcp (has label environment=production)
   └── Creates: PlacementDecision
       └── clusterName: ocp-hcp

2. Policy Controller:
   ├── Reads: Policy (policy-webserver-app)
   ├── Reads: PlacementBinding
   ├── Reads: PlacementDecision → Target: ocp-hcp
   └── Creates: Replicated Policy on managed cluster namespace

Hub Cluster
Namespace: ocp-hcp (managed cluster namespace)

Replicated Policy:
└── ConfigurationPolicy objects created for ocp-hcp
    ├── policy-webserver-configmap
    └── policy-webserver-deployment

                              ↓ (~10-20 seconds)
                         Policy is replicated to
                         managed cluster via ACM agent

┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 6: ACM Governance Policy Propagator                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Hub Cluster → Managed Cluster Communication:

ACM Hub (clusters-ocp-hcp namespace):
├── grc-policy-propagator pod
│   └── Watches: Replicated policies for ocp-hcp
│   └── Sends: Policy spec to managed cluster
│
└── Communication Channel:
    └── Via: Klusterlet agent on managed cluster
        └── Endpoint: Hosted cluster's kube-apiserver

Policy Propagation:
├── Source: Hub cluster (open-cluster-management-policies namespace)
├── Destination: ocp-hcp cluster (open-cluster-management-agent-addon namespace)
└── Content:
    ├── ConfigurationPolicy: policy-webserver-configmap
    │   └── ConfigMap spec with new HTML
    └── ConfigurationPolicy: policy-webserver-deployment
        └── Deployment spec with config-version: "5"

                              ↓ (~10-20 seconds)

┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 7: Managed Cluster Policy Agent (ocp-hcp)                             │
└─────────────────────────────────────────────────────────────────────────────┘

Managed Cluster: ocp-hcp
Namespace: open-cluster-management-agent-addon

Components:
├── config-policy-controller pod
│   ├── Receives: Policy from hub
│   ├── Evaluates: Current state vs desired state
│   └── Actions: Create/Update/Delete based on complianceType
│
└── governance-policy-framework pod
    └── Reports: Compliance status back to hub

Policy Evaluation:

1. ConfigurationPolicy: policy-webserver-configmap
   ├── complianceType: mustonlyhave (exact match required!)
   ├── Current ConfigMap: title="Old Title", data hash=abc123
   ├── Desired ConfigMap: title="New Title", data hash=xyz789
   ├── Status: NonCompliant (content differs)
   └── Action: UPDATE ConfigMap in namespace webserver-prod

2. ConfigurationPolicy: policy-webserver-deployment
   ├── complianceType: mustonlyhave (exact match required!)
   ├── Current Deployment: config-version="4"
   ├── Desired Deployment: config-version="5"
   ├── Status: NonCompliant (annotation differs)
   └── Action: UPDATE Deployment in namespace webserver-prod

                              ↓ (immediate)

┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 8: Resources Updated on Managed Cluster                               │
└─────────────────────────────────────────────────────────────────────────────┘

Managed Cluster: ocp-hcp
Namespace: webserver-prod

1. ConfigMap Update:
   ├── Resource: application-content
   ├── Action: kubectl apply
   ├── Changes:
   │   └── data.application.html: HTML updated with new title
   └── Result: ConfigMap updated ✓

2. Deployment Update:
   ├── Resource: webserver
   ├── Action: kubectl apply
   ├── Changes:
   │   └── spec.template.metadata.annotations.config-version: "4" → "5"
   └── Result: Deployment updated ✓

                              ↓ (immediate)
                         Kubernetes detects
                         Deployment change

┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 9: Kubernetes Reconciliation (ocp-hcp)                                │
└─────────────────────────────────────────────────────────────────────────────┘

Managed Cluster: ocp-hcp
Namespace: webserver-prod

Deployment Controller:
├── Detects: spec.template changed (config-version annotation)
├── Calculates: Template hash changed
├── Action: Rolling update triggered
└── Creates: New ReplicaSet

ReplicaSet Controller:
├── Current ReplicaSet: webserver-699bdb8cbc (config-version="4")
├── New ReplicaSet: webserver-7a8b9c0d1e (config-version="5")
└── Action: Create new pod

Pod Creation:
├── Old Pod: webserver-699bdb8cbc-xyz (running, age: 2 hours)
├── New Pod: webserver-7a8b9c0d1e-abc (creating...)
│   ├── Pull image: registry.access.redhat.com/ubi9/httpd-24:latest
│   ├── Mount ConfigMap: application-content (new version!)
│   │   └── Path: /var/www/html/application.html
│   └── Status: Running ✓
└── Old Pod: Terminating → Terminated

                              ↓ (~30 seconds)

┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 10: Application Serving New Content                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Managed Cluster: ocp-hcp
Namespace: webserver-prod

Pod: webserver-7a8b9c0d1e-abc
├── Container: httpd
├── Status: Running (age: 30s)
└── Serving: /var/www/html/application.html
    └── Content: NEW HTML with updated title ✓

Service: webserver
├── Type: ClusterIP
├── Selector: app=webserver
└── Endpoints: 10.133.0.50:8080 (new pod IP)

Route: webserver
├── Host: webserver-webserver-prod.apps.ocp-hcp...
├── Path: /application.html
├── Backend: service/webserver:8080
└── Serving: NEW content to users ✓

                              ↓ (~5-10 seconds)
                         Compliance check

┌─────────────────────────────────────────────────────────────────────────────┐
│  STEP 11: Compliance Status Reported Back                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Managed Cluster → Hub Cluster:

Managed Cluster (ocp-hcp):
├── config-policy-controller
│   ├── Evaluates: Resources match desired state
│   ├── ConfigMap: ✓ Compliant (content matches)
│   ├── Deployment: ✓ Compliant (config-version matches)
│   └── Reports: Status to hub
│
└── Status Message:
    └── compliant: "Compliant"
        └── message: "All resources match desired state"

Hub Cluster (cluster-nwjrk):
Namespace: open-cluster-management-policies

Policy: policy-webserver-app
└── status:
    ├── compliant: Compliant ✓
    └── status:
        └── - clustername: ocp-hcp
            ├── clusternamespace: ocp-hcp
            └── compliant: Compliant

ArgoCD Application: acm-webserver-app
└── health:
    └── status: Healthy ✓

┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPLETE! End-to-End GitOps Flow Successful                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Timeline Summary

```
Time     | Component           | Action
---------|---------------------|------------------------------------------
T+0      | Developer           | Edit file, git push
T+3m     | ArgoCD              | Detect change, sync to hub
T+3m30s  | Hub Cluster         | Policy updated
T+4m     | ACM Placement       | Select target clusters
T+4m30s  | ACM Propagator      | Send policy to managed cluster
T+5m     | Managed Cluster     | Apply ConfigMap & Deployment
T+5m30s  | Kubernetes          | Rolling update triggered
T+6m     | Pod                 | New pod running with new content
T+6m10s  | ACM Agent           | Report compliance back to hub
---------|---------------------|------------------------------------------
Total:   | ~6 minutes          | From commit to production!
```

---

## Detailed Component Interactions

### 1. ArgoCD Components

```
Hub Cluster: openshift-gitops namespace

┌─────────────────────────────────────────┐
│  ArgoCD Application Controller          │
│  ├── Polls Git every 3 minutes          │
│  ├── Compares: Git vs Cluster           │
│  └── Syncs when different               │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│  Application: acm-webserver-app         │
│  ├── source: Git repo                   │
│  ├── destination: Hub cluster           │
│  ├── syncPolicy:                        │
│  │   ├── automated: true                │
│  │   ├── selfHeal: true                 │
│  │   └── prune: true                    │
│  └── ignoreDifferences:                 │
│      └── /status (ACM policies)         │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│  Applies to: open-cluster-management-   │
│              policies namespace          │
│  ├── Policy                              │
│  ├── Placement                           │
│  └── PlacementBinding                    │
└─────────────────────────────────────────┘
```

### 2. ACM Components

```
Hub Cluster: ACM Operators

┌─────────────────────────────────────────┐
│  Placement Controller                   │
│  ├── Watches: Placement resources       │
│  ├── Queries: ManagedClusters           │
│  ├── Evaluates: Label selectors         │
│  └── Creates: PlacementDecisions        │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│  Policy Controller                      │
│  ├── Watches: Policy + PlacementBinding │
│  ├── Reads: PlacementDecisions          │
│  ├── Creates: Replicated policies       │
│  └── Target: Managed cluster namespace  │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│  Policy Propagator                      │
│  ├── Watches: Replicated policies       │
│  ├── Sends: Policy to managed clusters  │
│  └── Via: Klusterlet agent connection   │
└─────────────────────────────────────────┘
```

### 3. Managed Cluster Components

```
Managed Cluster: ocp-hcp

┌─────────────────────────────────────────┐
│  Klusterlet Agent                       │
│  ├── Receives: Policies from hub        │
│  ├── Forwards: To policy controllers    │
│  └── Reports: Status back to hub        │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│  Config Policy Controller               │
│  ├── Evaluates: Compliance               │
│  ├── complianceType: mustonlyhave       │
│  │   └── Forces exact match             │
│  ├── Actions: Create/Update/Delete      │
│  └── Reports: Status to framework       │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│  Kubernetes Resources                   │
│  ├── ConfigMap: application-content     │
│  ├── Deployment: webserver              │
│  ├── Service: webserver                 │
│  └── Route: webserver                   │
└─────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│          │     │          │     │   Hub    │     │ Managed  │     │   Pod    │
│  GitHub  │────▶│  ArgoCD  │────▶│  Cluster │────▶│ Cluster  │────▶│ Serving  │
│          │     │          │     │   ACM    │     │   ACM    │     │  Users   │
└──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
    │                 │                 │                 │                │
    │ Git commit      │ Poll/Webhook    │ Apply Policy    │ Apply K8s      │ HTTP
    │ & push          │ ~3min           │ ~30sec          │ ~30sec         │ Request
    │                 │                 │                 │                │
    └─────────────────┴─────────────────┴─────────────────┴────────────────┘
                        Total: ~4-6 minutes
```

---

## Key Mechanisms

### 1. ArgoCD Sync Modes

**Automatic Sync (Your Setup):**
```yaml
syncPolicy:
  automated:
    prune: true       # Delete resources not in Git
    selfHeal: true    # Revert manual changes
```

- ArgoCD polls Git every 3 minutes
- Detects drift and auto-corrects
- No manual intervention needed

### 2. ACM Compliance Types

**mustonlyhave (Your Setup):**
```yaml
complianceType: mustonlyhave
```

- **Enforces exact match** of resources
- **Updates existing resources** when changed
- **Perfect for GitOps** - forces sync with Git state

**vs. musthave (Don't Use):**
```yaml
complianceType: musthave
```

- Only checks resource exists
- Doesn't update if content changes
- Not suitable for auto-updates

### 3. Auto-Reload Mechanism

**config-version Annotation:**
```yaml
annotations:
  config-version: "5"  # Increment to force restart
```

- Changing this annotation triggers Deployment update
- Kubernetes sees template change → creates new ReplicaSet
- New pods mount updated ConfigMap
- **No manual pod restart needed!**

---

## Verification Commands

### Check Each Step

```bash
# 1. Check Git commit
cd /Users/pjalili/Projects/ocp-hcp-gitops
git log --oneline -1

# 2. Check ArgoCD sync
oc get application acm-webserver-app -n openshift-gitops \
  -o jsonpath='{.status.sync.status} - Rev: {.status.sync.revision}'

# 3. Check Hub policy
oc get policy policy-webserver-app -n open-cluster-management-policies \
  -o jsonpath='{.spec.policy-templates[1].objectDefinition.spec.object-templates[0].objectDefinition.data.application\.html}' \
  | grep -o '<title>[^<]*</title>'

# 4. Check Placement decision
oc get placementdecision -n open-cluster-management-policies -o yaml | grep clusterName

# 5. Check on managed cluster
./conn-ocp-hcp.sh
oc get configmap application-content -n webserver-prod \
  -o jsonpath='{.data.application\.html}' | grep -o '<title>[^<]*</title>'

# 6. Check deployment version
oc get deployment webserver -n webserver-prod \
  -o jsonpath='{.spec.template.metadata.annotations.config-version}'

# 7. Check pod age (should be recent)
oc get pods -n webserver-prod

# 8. Check compliance status
./disconnect-ocp-hcp.sh
oc get policy policy-webserver-app -n open-cluster-management-policies \
  -o jsonpath='{.status.compliant}'
```

---

## Troubleshooting the Flow

### Where Can Things Break?

```
1. Git → ArgoCD
   Problem: ArgoCD not syncing
   Check: oc get application -n openshift-gitops
   Fix: oc annotate application <name> argocd.argoproj.io/refresh=normal

2. ArgoCD → Hub Policy
   Problem: RBAC issues
   Check: oc describe clusterrolebinding argocd-acm-policy-manager
   Fix: Ensure ArgoCD has ACM permissions

3. Hub Policy → Placement
   Problem: No clusters selected
   Check: oc get placementdecision -n open-cluster-management-policies
   Fix: Check ManagedCluster labels match Placement selector

4. Placement → Managed Cluster
   Problem: Policy not propagated
   Check: oc get pods -n open-cluster-management | grep propagator
   Fix: Check klusterlet agent health on managed cluster

5. Managed Cluster → Resources
   Problem: Policy shows NonCompliant
   Check: oc describe policy <name> -n open-cluster-management-policies
   Fix: Check config-policy-controller logs on managed cluster

6. Resources → Pod Restart
   Problem: Pod not restarting
   Check: Did you increment config-version annotation?
   Fix: Increment config-version in Git, commit & push
```

---

## Summary

**The Complete Flow:**
1. ✅ Developer commits to Git
2. ✅ ArgoCD syncs from Git to Hub (~3 min)
3. ✅ ACM Placement selects clusters (~30 sec)
4. ✅ ACM propagates policy to managed cluster (~30 sec)
5. ✅ Policy controller applies resources (~10 sec)
6. ✅ Kubernetes updates deployment (~30 sec)
7. ✅ New pod serves updated content (~30 sec)
8. ✅ Compliance reported back to hub (~10 sec)

**Total Time:** ~4-6 minutes from commit to production!

**Key Advantages:**
- ✅ Fully automated
- ✅ Version controlled
- ✅ Auditable (Git history)
- ✅ Self-healing (ArgoCD + ACM)
- ✅ Multi-cluster (ACM Placement)
- ✅ Declarative (GitOps)
