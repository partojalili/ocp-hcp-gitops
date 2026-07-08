#!/bin/bash

# Cleanup script for ACM-managed GCP OpenShift clusters
# This script removes all resources for a cluster: ArgoCD app, namespace, git directory, and GCP resources
#
# Usage:
#   ./cleanup-acm-gcp-cluster.sh --cluster-name <name> --base-domain <domain> --gcp-project <project> [options]
#
# Required parameters:
#   --cluster-name      Name of the cluster to delete
#   --base-domain       Base domain for DNS (e.g., d967h.gcp.redhatworkshops.io)
#   --gcp-project       GCP project ID
#
# Optional parameters:
#   --gcp-region        GCP region (default: us-east1)
#   --git-repo-path     Path to git repository (default: current directory)
#   --skip-argocd       Skip ArgoCD application deletion
#   --skip-namespace    Skip namespace deletion
#   --skip-git          Skip git directory deletion
#   --skip-gcp          Skip GCP resource cleanup
#   --dry-run           Show what would be deleted without actually deleting

set -euo pipefail

# Default values
GCP_REGION="us-east1"
GIT_REPO_PATH="$(pwd)"
SKIP_ARGOCD=false
SKIP_NAMESPACE=false
SKIP_GIT=false
SKIP_GCP=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --cluster-name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --base-domain)
      BASE_DOMAIN="$2"
      shift 2
      ;;
    --gcp-project)
      GCP_PROJECT="$2"
      shift 2
      ;;
    --gcp-region)
      GCP_REGION="$2"
      shift 2
      ;;
    --git-repo-path)
      GIT_REPO_PATH="$2"
      shift 2
      ;;
    --skip-argocd)
      SKIP_ARGOCD=true
      shift
      ;;
    --skip-namespace)
      SKIP_NAMESPACE=true
      shift
      ;;
    --skip-git)
      SKIP_GIT=true
      shift
      ;;
    --skip-gcp)
      SKIP_GCP=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "${CLUSTER_NAME:-}" ]]; then
  echo "Error: --cluster-name is required"
  exit 1
fi

if [[ -z "${BASE_DOMAIN:-}" ]]; then
  echo "Error: --base-domain is required"
  exit 1
fi

if [[ -z "${GCP_PROJECT:-}" ]]; then
  echo "Error: --gcp-project is required"
  exit 1
fi

# Helper function to run commands or print in dry-run mode
run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] $*"
  else
    eval "$*" || true
  fi
}

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║           ACM GCP CLUSTER CLEANUP                                      ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Cluster Name:     $CLUSTER_NAME"
echo "Base Domain:      $BASE_DOMAIN"
echo "GCP Project:      $GCP_PROJECT"
echo "GCP Region:       $GCP_REGION"
echo "Git Repo Path:    $GIT_REPO_PATH"
echo "Dry Run:          $DRY_RUN"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  echo "⚠️  DRY RUN MODE - No resources will be deleted"
  echo ""
fi

# Step 1: Delete ArgoCD Application
if [[ "$SKIP_ARGOCD" == "false" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "1️⃣  Deleting ArgoCD Application..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  run_cmd "oc delete application $CLUSTER_NAME -n openshift-gitops --ignore-not-found=true"
  echo ""
fi

# Step 2: Delete Namespace and Resources
if [[ "$SKIP_NAMESPACE" == "false" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "2️⃣  Deleting Kubernetes Resources..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Remove finalizers from ClusterDeployment
  if ! $DRY_RUN && oc get clusterdeployment $CLUSTER_NAME -n $CLUSTER_NAME &>/dev/null; then
    echo "Removing finalizers from ClusterDeployment..."
    oc patch clusterdeployment $CLUSTER_NAME -n $CLUSTER_NAME --type=merge -p '{"metadata":{"finalizers":[]}}' || true
  fi

  # Remove finalizers from ManagedCluster
  if ! $DRY_RUN && oc get managedcluster $CLUSTER_NAME &>/dev/null; then
    echo "Removing finalizers from ManagedCluster..."
    oc patch managedcluster $CLUSTER_NAME --type=merge -p '{"metadata":{"finalizers":[]}}' || true
  fi

  # Delete resources
  run_cmd "oc delete clusterdeployment $CLUSTER_NAME -n $CLUSTER_NAME --ignore-not-found=true"
  run_cmd "oc delete managedcluster $CLUSTER_NAME --ignore-not-found=true"
  run_cmd "oc delete namespace $CLUSTER_NAME --ignore-not-found=true"

  # Wait for namespace deletion
  if ! $DRY_RUN; then
    echo "Waiting for namespace deletion (max 2 minutes)..."
    timeout 120 bash -c "while oc get namespace $CLUSTER_NAME &>/dev/null; do sleep 5; done" || echo "Timeout waiting for namespace deletion"
  fi
  echo ""
fi

# Step 3: Delete Git Directory
if [[ "$SKIP_GIT" == "false" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "3️⃣  Deleting Git Directory..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  GIT_CLUSTER_DIR="$GIT_REPO_PATH/clusters/acm-gcp/$CLUSTER_NAME"

  if [[ -d "$GIT_CLUSTER_DIR" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY-RUN] Would delete directory: $GIT_CLUSTER_DIR"
    else
      cd "$GIT_REPO_PATH"
      git rm -rf "clusters/acm-gcp/$CLUSTER_NAME"
      git commit -m "Remove cluster: $CLUSTER_NAME"
      git push origin main
      echo "✅ Git directory deleted and changes pushed"
    fi
  else
    echo "Git directory not found: $GIT_CLUSTER_DIR"
  fi
  echo ""
fi

# Step 4: Clean up GCP Resources
if [[ "$SKIP_GCP" == "false" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "4️⃣  Cleaning up GCP Resources..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Find the cluster infrastructure ID (usually <cluster-name>-<random-suffix>)
  if ! $DRY_RUN; then
    INFRA_ID=$(gcloud compute networks list --project=$GCP_PROJECT --filter="name~$CLUSTER_NAME" --format="value(name)" | head -1)

    if [[ -z "$INFRA_ID" ]]; then
      echo "⚠️  No GCP infrastructure found for cluster $CLUSTER_NAME"
      echo "   Trying to find resources by cluster name pattern..."
      INFRA_ID="$CLUSTER_NAME"
    else
      echo "Found infrastructure ID: $INFRA_ID"
    fi
  else
    INFRA_ID="$CLUSTER_NAME-xxxxx"
    echo "[DRY-RUN] Would search for infrastructure ID"
  fi

  echo ""
  echo "Deleting GCP resources for: $INFRA_ID"
  echo ""

  # Delete forwarding rules
  echo "📍 Deleting forwarding rules..."
  run_cmd "gcloud compute forwarding-rules delete ${INFRA_ID}-apiserver --global --project=$GCP_PROJECT --quiet"
  run_cmd "gcloud compute forwarding-rules delete ${INFRA_ID}-api-internal --region=$GCP_REGION --project=$GCP_PROJECT --quiet"

  # Delete any load balancer forwarding rules
  if ! $DRY_RUN; then
    gcloud compute forwarding-rules list --project=$GCP_PROJECT --filter="name~k8s-.*" --format="value(name,region)" | while read name region; do
      if [[ "$region" == *"$GCP_REGION"* ]]; then
        run_cmd "gcloud compute forwarding-rules delete $name --region=$GCP_REGION --project=$GCP_PROJECT --quiet"
      fi
    done
  fi

  # Delete target TCP proxies
  echo "🎯 Deleting target TCP proxies..."
  run_cmd "gcloud compute target-tcp-proxies delete ${INFRA_ID}-apiserver --project=$GCP_PROJECT --quiet"

  # Delete backend services (global)
  echo "⚙️  Deleting global backend services..."
  run_cmd "gcloud compute backend-services delete ${INFRA_ID}-apiserver --global --project=$GCP_PROJECT --quiet"

  # Delete backend services (regional)
  echo "⚙️  Deleting regional backend services..."
  run_cmd "gcloud compute backend-services delete ${INFRA_ID}-api-internal --region=$GCP_REGION --project=$GCP_PROJECT --quiet"

  # Delete health checks
  echo "🏥 Deleting health checks..."
  run_cmd "gcloud compute health-checks delete ${INFRA_ID}-apiserver --project=$GCP_PROJECT --quiet"
  run_cmd "gcloud compute health-checks delete ${INFRA_ID}-api-internal --region=$GCP_REGION --project=$GCP_PROJECT --quiet"

  # Delete instance groups
  echo "📦 Deleting instance groups..."
  for zone in b c d; do
    run_cmd "gcloud compute instance-groups unmanaged delete ${INFRA_ID}-master-${GCP_REGION}-${zone} --zone=${GCP_REGION}-${zone} --project=$GCP_PROJECT --quiet"
  done

  # Delete compute instances
  echo "💻 Deleting compute instances..."
  if ! $DRY_RUN; then
    gcloud compute instances list --project=$GCP_PROJECT --filter="name~${INFRA_ID}" --format="value(name,zone)" | while read name zone; do
      run_cmd "gcloud compute instances delete $name --zone=$zone --project=$GCP_PROJECT --quiet"
    done
  fi

  # Delete disks
  echo "💾 Deleting persistent disks..."
  if ! $DRY_RUN; then
    gcloud compute disks list --project=$GCP_PROJECT --filter="name~${INFRA_ID}" --format="value(name,zone)" | while read name zone; do
      run_cmd "gcloud compute disks delete $name --zone=$zone --project=$GCP_PROJECT --quiet"
    done
  fi

  # Delete static IP addresses
  echo "📌 Deleting static IP addresses..."
  run_cmd "gcloud compute addresses delete ${INFRA_ID}-apiserver --global --project=$GCP_PROJECT --quiet"
  run_cmd "gcloud compute addresses delete ${INFRA_ID}-api-internal --region=$GCP_REGION --project=$GCP_PROJECT --quiet"

  # Delete firewall rules
  echo "🔥 Deleting firewall rules..."
  if ! $DRY_RUN; then
    gcloud compute firewall-rules list --project=$GCP_PROJECT --filter="network:${INFRA_ID}" --format="value(name)" | while read rule; do
      run_cmd "gcloud compute firewall-rules delete $rule --project=$GCP_PROJECT --quiet"
    done
  fi

  # Delete cloud router
  echo "🔀 Deleting cloud router..."
  run_cmd "gcloud compute routers delete ${INFRA_ID}-network-router --region=$GCP_REGION --project=$GCP_PROJECT --quiet"

  # Delete subnets
  echo "🌐 Deleting subnets..."
  if ! $DRY_RUN; then
    gcloud compute networks subnets list --network=${INFRA_ID}-network --project=$GCP_PROJECT --format="value(name,region)" 2>/dev/null | while read name region; do
      run_cmd "gcloud compute networks subnets delete $name --region=$region --project=$GCP_PROJECT --quiet"
    done
  fi

  # Delete VPC network
  echo "🌐 Deleting VPC network..."
  run_cmd "gcloud compute networks delete ${INFRA_ID}-network --project=$GCP_PROJECT --quiet"

  # Delete DNS zone and records
  echo "🌍 Deleting DNS resources..."
  DNS_ZONE="${INFRA_ID}-private-zone"

  if ! $DRY_RUN; then
    if gcloud dns managed-zones describe $DNS_ZONE --project=$GCP_PROJECT &>/dev/null; then
      # Delete DNS records (except NS and SOA)
      gcloud dns record-sets list --zone=$DNS_ZONE --project=$GCP_PROJECT --format="value(name,type)" | while read name type; do
        if [[ "$type" != "NS" && "$type" != "SOA" ]]; then
          run_cmd "gcloud dns record-sets delete $name --type=$type --zone=$DNS_ZONE --project=$GCP_PROJECT --quiet"
        fi
      done

      # Delete DNS zone
      run_cmd "gcloud dns managed-zones delete $DNS_ZONE --project=$GCP_PROJECT --quiet"
    else
      echo "DNS zone $DNS_ZONE not found"
    fi
  fi

  echo ""
  echo "✅ GCP cleanup complete"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║             ✅ CLEANUP COMPLETE                                        ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  echo "This was a dry run. Re-run without --dry-run to actually delete resources."
else
  echo "All resources for cluster '$CLUSTER_NAME' have been removed."
  echo ""
  echo "Verification commands:"
  echo "  oc get application $CLUSTER_NAME -n openshift-gitops"
  echo "  oc get namespace $CLUSTER_NAME"
  echo "  oc get managedcluster $CLUSTER_NAME"
  echo "  gcloud compute networks list --project=$GCP_PROJECT --filter='name~$CLUSTER_NAME'"
fi

echo ""
