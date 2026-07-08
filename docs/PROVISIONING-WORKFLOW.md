# OpenShift Cluster Provisioning Workflow

## Overview
This document describes the automated workflow from Developer Hub form submission to OpenShift cluster provisioning on GCP.

---

## Step-by-Step Flow

### 1️⃣ Developer Hub - Form Submission
**Component:** Red Hat Developer Hub (Backstage)

**What Happens:**
- User fills out the "ACM-Managed OpenShift Cluster on GCP" form
- Clicks "Create"

**Action:** Developer Hub scaffolder starts execution

---

### 2️⃣ Developer Hub - Template Processing
**Component:** Backstage Scaffolder

**What Gets Created:**
- Processes Jinja2 templates with user input values
- Generates cluster manifests from skeleton files

**Files Generated:**
```
clusters/acm-gcp/<cluster-name>/
├── base/
│   ├── namespace.yaml           # Cluster namespace
│   ├── install-config.yaml      # OpenShift install configuration
│   ├── clusterdeployment.yaml   # Hive ClusterDeployment
│   ├── managedcluster.yaml      # ACM ManagedCluster
│   ├── gcp-creds.yaml           # GCP service account credentials
│   ├── pull-secret.yaml         # Red Hat pull secret
│   ├── ssh-key.yaml             # SSH key for cluster access
│   └── kustomization.yaml       # Kustomize resource list
├── catalog-info.yaml            # Backstage catalog entry
└── README.md                    # Cluster documentation
```

---

### 3️⃣ GitHub - Commit & Push
**Component:** GitHub Integration

**What Happens:**
- Scaffolder commits generated files to repository
- Pushes to `main` branch
- Branch: `clusters/acm-gcp/<cluster-name>/`

**Git Commit Message:**
```
Add ACM-managed GCP cluster: <cluster-name>

Configuration:
- Region: us-east1
- OpenShift Version: 4.20.24
- Workers: 3 x n2-standard-4
- Masters: 3 x n2-standard-4
```

---

### 4️⃣ ArgoCD - Directory Detection
**Component:** ArgoCD ApplicationSet

**What Gets Created:**
- ArgoCD detects new directory in `clusters/acm-gcp/`
- ApplicationSet generator creates new Application resource

**Resource Created:**
```yaml
kind: Application
metadata:
  name: <cluster-name>
  namespace: openshift-gitops
spec:
  source:
    path: clusters/acm-gcp/<cluster-name>
  destination:
    namespace: <cluster-name>
```

**Status:** Application appears in ArgoCD UI with "OutOfSync" status

---

### 5️⃣ ArgoCD - Resource Synchronization
**Component:** ArgoCD Application Controller

**What Gets Created on Hub Cluster:**

1. **Namespace**
   ```yaml
   kind: Namespace
   metadata:
     name: <cluster-name>
   ```

2. **Secrets** (5 secrets)
   - `<cluster-name>-install-config` - OpenShift configuration
   - `<cluster-name>-gcp-creds` - GCP service account
   - `<cluster-name>-pull-secret` - Red Hat pull secret
   - `<cluster-name>-ssh-private-key` - SSH key
   - `<cluster-name>-ssh-public-key` - SSH public key

3. **ClusterDeployment** (Hive CRD)
   ```yaml
   kind: ClusterDeployment
   metadata:
     name: <cluster-name>
     namespace: <cluster-name>
   spec:
     platform:
       gcp:
         projectID: openenv-d967h
         region: us-east1
   ```

4. **ManagedCluster** (ACM CRD)
   ```yaml
   kind: ManagedCluster
   metadata:
     name: <cluster-name>
     labels:
       cluster.open-cluster-management.io/clusterset: global
   spec:
     hubAcceptsClient: true
   ```

**Status:** ArgoCD shows "Synced" and "Progressing"

---

### 6️⃣ Hive - Provision Job Creation
**Component:** Hive Operator

**What Gets Created:**

1. **ClusterProvision** (tracking resource)
   ```yaml
   kind: ClusterProvision
   metadata:
     name: <cluster-name>-0-xxxxx
     namespace: <cluster-name>
   ```

2. **Provision Job**
   ```yaml
   kind: Job
   metadata:
     name: <cluster-name>-0-xxxxx-provision
     namespace: <cluster-name>
   ```

3. **Provision Pod**
   ```yaml
   kind: Pod
   metadata:
     name: <cluster-name>-0-xxxxx-provision-yyyyy
   spec:
     containers:
     - name: installer
       image: quay.io/openshift-release-dev/ocp-v4.0-art-dev
   ```

**Status:** Pod status changes: Pending → Running

---

### 7️⃣ OpenShift Installer - Manifest Generation
**Component:** OpenShift Installer (running in provision pod)

**What Happens:**
- Reads `install-config.yaml` from secret
- Validates configuration
- Generates ignition configs
- Creates cluster manifests

**Log Output:**
```
level=info msg="creating cluster manifests"
level=info msg="validating install-config"
level=info msg="generating cluster assets"
```

---

### 8️⃣ GCP Infrastructure - Network Creation
**Component:** Cluster API Provider GCP (CAPG)

**GCP Resources Created:**

1. **VPC Network**
   - Name: `<cluster-name>-<infra-id>-network`
   - Type: Custom mode

2. **Subnets** (2 subnets)
   - `<cluster-name>-<infra-id>-master-subnet` (CIDR: 10.0.0.0/24)
   - `<cluster-name>-<infra-id>-worker-subnet` (CIDR: 10.0.1.0/24)

3. **Cloud Router**
   - Name: `<cluster-name>-<infra-id>-network-router`
   - Cloud NAT enabled

4. **Firewall Rules** (9 rules)
   - `<cluster-name>-<infra-id>-api` - Allow 6443
   - `<cluster-name>-<infra-id>-health-checks` - Allow health checks
   - `<cluster-name>-<infra-id>-internal-network` - Allow internal
   - `<cluster-name>-<infra-id>-control-plane` - Control plane communication
   - `<cluster-name>-<infra-id>-etcd` - etcd communication
   - etc.

**Status:** Network infrastructure ready (~2-3 minutes)

---

### 9️⃣ GCP Infrastructure - Load Balancers
**Component:** Cluster API Provider GCP (CAPG)

**GCP Resources Created:**

1. **Instance Groups** (3 groups, one per zone)
   - `<cluster-name>-<infra-id>-master-us-east1-b`
   - `<cluster-name>-<infra-id>-master-us-east1-c`
   - `<cluster-name>-<infra-id>-master-us-east1-d`

2. **Health Checks** (2 checks)
   - `<cluster-name>-<infra-id>-apiserver` (global)
   - `<cluster-name>-<infra-id>-api-internal` (regional)

3. **Backend Services** (2 services)
   - `<cluster-name>-<infra-id>-apiserver` (global)
   - `<cluster-name>-<infra-id>-api-internal` (regional)

4. **Target TCP Proxy**
   - `<cluster-name>-<infra-id>-apiserver`

5. **Static IP Addresses** (2 IPs)
   - `<cluster-name>-<infra-id>-apiserver` (global, external)
   - `<cluster-name>-<infra-id>-api-internal` (regional, internal)

6. **Forwarding Rules** (2 rules)
   - External: `<cluster-name>-<infra-id>-apiserver` → External IP:6443
   - Internal: `<cluster-name>-<infra-id>-api-internal` → Internal IP:6443

**Status:** Load balancers ready (~3-4 minutes)

---

### 🔟 GCP Infrastructure - DNS Records
**Component:** Cloud DNS (if not userProvisionedDNS)

**DNS Resources Created:**

1. **Private DNS Zone**
   - Name: `<cluster-name>-<infra-id>-private-zone`
   - Domain: `<cluster-name>.<base-domain>`

2. **DNS Records** (3 records)
   - `api.<cluster-name>.<base-domain>` → External IP
   - `api-int.<cluster-name>.<base-domain>` → Internal IP
   - `*.apps.<cluster-name>.<base-domain>` → External IP (for routes)

**Status:** DNS ready

---

### 1️⃣1️⃣ GCP Infrastructure - Bootstrap VM
**Component:** OpenShift Installer

**GCP Resources Created:**

1. **Bootstrap VM**
   - Name: `<cluster-name>-<infra-id>-bootstrap`
   - Machine type: n2-standard-4
   - Zone: us-east1-b
   - Disk: 60GB
   - Ignition: Bootstrap ignition config

2. **Bootstrap Disk**
   - Name: `<cluster-name>-<infra-id>-bootstrap`

**What Bootstrap Does:**
- Starts temporary Kubernetes control plane
- Serves ignition configs to master nodes
- Waits for master nodes to join

**Status:** Bootstrap running (~5 minutes)

---

### 1️⃣2️⃣ GCP Infrastructure - Master Nodes
**Component:** OpenShift Installer

**GCP Resources Created (3 master nodes):**

1. **Master VMs** (one per zone)
   - `<cluster-name>-<infra-id>-master-0` (zone b)
   - `<cluster-name>-<infra-id>-master-1` (zone c)
   - `<cluster-name>-<infra-id>-master-2` (zone d)
   - Machine type: n2-standard-4
   - Disk: 200GB each

2. **Master Disks** (3 disks)
   - `<cluster-name>-<infra-id>-master-0`
   - `<cluster-name>-<infra-id>-master-1`
   - `<cluster-name>-<infra-id>-master-2`

**What Masters Do:**
- Download ignition config from bootstrap
- Join etcd cluster
- Start Kubernetes control plane components
- Join instance groups (for load balancer)

**Status:** Masters booting (~10 minutes)

---

### 1️⃣3️⃣ OpenShift Control Plane - Bootstrap Complete
**Component:** OpenShift Installer

**What Happens:**
- Masters form etcd quorum
- Kubernetes API becomes available
- Machine API starts
- Bootstrap node destroys itself

**GCP Resources Deleted:**
- Bootstrap VM deleted
- Bootstrap disk deleted

**Cluster State:**
- Kubernetes API: Available at `api.<cluster-name>.<base-domain>:6443`
- etcd: 3-member cluster running
- Control plane operators: Starting

**Status:** Bootstrap complete (~15 minutes)

---

### 1️⃣4️⃣ OpenShift Control Plane - Operators Starting
**Component:** Cluster Version Operator (CVO)

**What Gets Created:**

1. **Core Operators Deploy:**
   - `openshift-kube-apiserver`
   - `openshift-kube-controller-manager`
   - `openshift-kube-scheduler`
   - `openshift-etcd`

2. **Network Operator:**
   - `openshift-ovn-kubernetes`
   - OVN pods on each master

3. **Machine API:**
   - `openshift-machine-api`
   - Creates MachineSet for workers

**Status:** Operators progressing (~20 minutes)

---

### 1️⃣5️⃣ GCP Infrastructure - Worker Nodes
**Component:** Machine API Operator

**GCP Resources Created (3 worker nodes):**

1. **Worker VMs** (3 workers)
   - `<cluster-name>-<infra-id>-worker-<zone>-<id>`
   - Machine type: n2-standard-4
   - Disk: 60GB each
   - Distributed across zones

2. **Worker Disks** (3 disks)

**What Workers Do:**
- Download ignition config from Machine Config Server
- Join cluster
- Start kubelet
- Run workload pods

**Status:** Workers joining (~25 minutes)

---

### 1️⃣6️⃣ OpenShift - Cluster Operators Installation
**Component:** Cluster Version Operator (CVO)

**Operators Being Installed (~40 operators):**
- `authentication` - OAuth and user authentication
- `cloud-credential` - Cloud credentials management
- `cluster-autoscaler` - Autoscaling
- `config-operator` - Cluster configuration
- `console` - Web console
- `dns` - CoreDNS
- `image-registry` - Internal registry
- `ingress` - Router/ingress controller
- `insights` - Telemetry
- `monitoring` - Prometheus stack
- `network` - OVN-Kubernetes
- `node-tuning` - Node performance tuning
- `operator-lifecycle-manager` - OLM
- `service-ca` - Service CA certificates
- `storage` - Storage classes
- And 25+ more operators...

**Cluster State:**
```bash
$ oc get clusteroperators
NAME                  VERSION   AVAILABLE   PROGRESSING   DEGRADED
authentication        4.20.24   True        False         False
cloud-credential      4.20.24   True        False         False
...
```

**Status:** All operators available (~35-40 minutes)

---

### 1️⃣7️⃣ Hive - Installation Complete
**Component:** Hive Operator

**What Gets Updated:**

1. **ClusterDeployment Status**
   ```yaml
   status:
     installed: true
     conditions:
     - type: Provisioned
       status: True
       reason: ClusterProvisioned
     installedTimestamp: "2026-07-08T15:15:00Z"
     webConsoleURL: https://console-openshift-console.apps.<cluster>.<domain>
     apiURL: https://api.<cluster>.<domain>:6443
   ```

2. **Admin Kubeconfig Secret**
   - Secret created: `<cluster-name>-admin-kubeconfig`
   - Contains cluster admin credentials

3. **Admin Password Secret**
   - Secret created: `<cluster-name>-admin-password`
   - Contains `kubeadmin` password

**Status:** ClusterDeployment shows "Installed: True"

---

### 1️⃣8️⃣ ACM - Cluster Import
**Component:** ACM Multicluster Engine

**What Happens:**

1. **Import Job Created**
   - Job: `<cluster-name>-import`
   - Deploys import manifest to target cluster

2. **Klusterlet Deployed** (on managed cluster)
   - Namespace: `open-cluster-management-agent`
   - Deployments:
     - `klusterlet`
     - `klusterlet-registration-agent`
     - `klusterlet-work-agent`

3. **ManagedCluster Status Updated**
   ```yaml
   status:
     conditions:
     - type: ManagedClusterJoined
       status: True
     - type: ManagedClusterConditionAvailable
       status: True
   ```

4. **ManagedClusterSet Membership**
   - Cluster joins "global" ManagedClusterSet
   - Appears in ACM console

**Status:** Cluster shows as "Ready" in ACM

---

### 1️⃣9️⃣ ArgoCD - Health Check
**Component:** ArgoCD Application Controller

**What Gets Updated:**

**Application Status:**
```yaml
status:
  sync:
    status: Synced
  health:
    status: Healthy
  resources:
  - kind: Namespace
    status: Synced
  - kind: ClusterDeployment
    status: Synced
  - kind: ManagedCluster
    status: Synced
```

**Status:** ArgoCD shows green checkmark

---

### 2️⃣0️⃣ Developer Hub - Catalog Registration
**Component:** Backstage Catalog

**What Happens:**

1. **GitHub Provider Scans Repository**
   - Finds: `clusters/acm-gcp/<cluster-name>/catalog-info.yaml`

2. **Entity Registered**
   ```yaml
   kind: Resource
   metadata:
     name: <cluster-name>
   spec:
     type: kubernetes-cluster
     owner: user:default/guest
     lifecycle: production
   ```

3. **Cluster Appears in Catalog**
   - Listed under "Resources"
   - Type: kubernetes-cluster
   - Links to ArgoCD and ACM

**Status:** Cluster visible in Developer Hub UI

---

## Final State - Cluster Ready

### Hub Cluster Resources Created:
- ✅ 1 Namespace
- ✅ 5 Secrets (credentials)
- ✅ 1 ClusterDeployment (Hive)
- ✅ 1 ManagedCluster (ACM)
- ✅ 1 ArgoCD Application

### GCP Resources Created:
- ✅ 1 VPC Network
- ✅ 2 Subnets
- ✅ 1 Cloud Router
- ✅ 9 Firewall Rules
- ✅ 3 Instance Groups
- ✅ 2 Health Checks
- ✅ 2 Backend Services
- ✅ 1 Target TCP Proxy
- ✅ 2 Static IP Addresses
- ✅ 2 Forwarding Rules
- ✅ 1 DNS Zone (optional)
- ✅ 3 DNS Records (optional)
- ✅ 6 VM Instances (3 masters + 3 workers)
- ✅ 6 Persistent Disks

### Cluster Components Running:
- ✅ 3 etcd members
- ✅ 3 Kubernetes API servers
- ✅ 3 control plane nodes
- ✅ 3 worker nodes
- ✅ 40+ cluster operators
- ✅ OVN-Kubernetes networking
- ✅ Internal image registry
- ✅ Web console
- ✅ Ingress router
- ✅ Monitoring stack
- ✅ ACM agent (klusterlet)

### Access Points:
- 🌐 **Web Console:** `https://console-openshift-console.apps.<cluster>.<domain>`
- 🔧 **API Server:** `https://api.<cluster>.<domain>:6443`
- 📊 **ACM Console:** Hub cluster → Infrastructure → Clusters
- 🔄 **ArgoCD:** Hub cluster → ArgoCD UI → Applications

---

## Timeline Summary

| Time | Component | Action |
|------|-----------|--------|
| T+0s | Developer Hub | Form submitted |
| T+10s | GitHub | Files committed |
| T+20s | ArgoCD | Application created |
| T+30s | Hive | Provision job started |
| T+2m | GCP | Network created |
| T+5m | GCP | Load balancers ready |
| T+5m | GCP | Bootstrap VM started |
| T+10m | GCP | Master VMs started |
| T+15m | OpenShift | Bootstrap complete |
| T+20m | OpenShift | Masters ready |
| T+25m | GCP | Worker VMs started |
| T+30m | OpenShift | Workers joined |
| T+40m | OpenShift | All operators available |
| T+45m | ACM | Cluster imported |
| **T+45m** | **COMPLETE** | **Cluster Ready** |

**Total Time:** ~45 minutes from form submission to fully operational cluster

---

## Key Technologies Used

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Developer Hub | Red Hat Developer Hub (Backstage) | Self-service portal |
| Scaffolder | Backstage Scaffolder | Template processing |
| Git | GitHub | GitOps repository |
| CD | ArgoCD + ApplicationSet | Continuous deployment |
| Provisioning | Hive Operator | OpenShift cluster lifecycle |
| Management | ACM (Advanced Cluster Management) | Multi-cluster management |
| Infrastructure | Cluster API Provider GCP (CAPG) | GCP resource provisioning |
| Installer | OpenShift Installer | OpenShift deployment |
| Networking | OVN-Kubernetes | Cluster networking |
| Monitoring | Prometheus + Grafana | Observability |

---

## Next Steps After Provisioning

1. **Access Cluster:**
   ```bash
   # Get admin kubeconfig
   oc get secret <cluster-name>-admin-kubeconfig -n <cluster-name> -o jsonpath='{.data.kubeconfig}' | base64 -d > kubeconfig
   
   # Get admin password
   oc get secret <cluster-name>-admin-password -n <cluster-name> -o jsonpath='{.data.password}' | base64 -d
   ```

2. **Configure Cluster:**
   - Add identity providers (OAuth)
   - Configure storage classes
   - Install operators via OperatorHub
   - Deploy applications

3. **ACM Policies:**
   - Apply governance policies
   - Configure backup schedules
   - Set up disaster recovery

4. **Monitoring:**
   - Access Prometheus
   - View Grafana dashboards
   - Configure alerts

---

## Troubleshooting

### Check Provisioning Status:
```bash
# Overall status
oc get clusterdeployment <cluster-name> -n <cluster-name>

# Provision logs
oc logs -f $(oc get pods -n <cluster-name> -o name | grep provision) -n <cluster-name>

# ACM status
oc get managedcluster <cluster-name>

# ArgoCD status
oc get application <cluster-name> -n openshift-gitops
```

### Common Issues:

| Issue | Component | Solution |
|-------|-----------|----------|
| Form validation error | Developer Hub | Check required fields |
| Git push fails | GitHub | Verify permissions |
| Application not created | ArgoCD | Check ApplicationSet |
| Provision fails | Hive | Check provision pod logs |
| GCP quota exceeded | GCP | Increase quotas |
| Network timeout | GCP | Check firewall rules |
| DNS resolution fails | Cloud DNS | Verify DNS records |
| Cluster not joining ACM | Klusterlet | Check import job |

---

**Document Version:** 1.0  
**Last Updated:** 2026-07-08  
**Maintained By:** Platform Team
