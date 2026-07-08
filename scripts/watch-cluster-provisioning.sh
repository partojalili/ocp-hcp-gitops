#!/bin/bash

# Watch cluster provisioning workflow
# Usage: ./watch-cluster-provisioning.sh <cluster-name>

CLUSTER_NAME=${1:-gcp-cluster}

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║           CLUSTER PROVISIONING MONITOR                                 ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Cluster Name: $CLUSTER_NAME"
echo ""

while true; do
    clear
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║           CLUSTER PROVISIONING MONITOR - $(date +"%H:%M:%S")                    ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""

    # 1. GitHub Status
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 GITHUB STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -d "clusters/acm-gcp/$CLUSTER_NAME" ]; then
        echo "✅ Cluster directory exists in Git"
        echo "   Latest commit: $(git log -1 --oneline | head -1)"
    else
        echo "⏳ Waiting for cluster directory to be created..."
    fi
    echo ""

    # 2. ArgoCD Status
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 ARGOCD STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if oc get application $CLUSTER_NAME -n openshift-gitops &>/dev/null; then
        SYNC_STATUS=$(oc get application $CLUSTER_NAME -n openshift-gitops -o jsonpath='{.status.sync.status}')
        HEALTH_STATUS=$(oc get application $CLUSTER_NAME -n openshift-gitops -o jsonpath='{.status.health.status}')

        if [ "$SYNC_STATUS" == "Synced" ]; then
            echo "✅ Application Sync: $SYNC_STATUS"
        else
            echo "⏳ Application Sync: $SYNC_STATUS"
        fi

        echo "   Health: $HEALTH_STATUS"
    else
        echo "⏳ Waiting for ArgoCD Application to be created..."
    fi
    echo ""

    # 3. Cluster Deployment Status
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 CLUSTER DEPLOYMENT STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if oc get clusterdeployment $CLUSTER_NAME -n $CLUSTER_NAME &>/dev/null; then
        INFRA_ID=$(oc get clusterdeployment $CLUSTER_NAME -n $CLUSTER_NAME -o jsonpath='{.status.infraID}')
        PROVISION_STATUS=$(oc get clusterdeployment $CLUSTER_NAME -n $CLUSTER_NAME -o jsonpath='{.status.conditions[?(@.type=="Provisioned")].status}')
        PROVISION_REASON=$(oc get clusterdeployment $CLUSTER_NAME -n $CLUSTER_NAME -o jsonpath='{.status.conditions[?(@.type=="Provisioned")].reason}')
        INSTALLED=$(oc get clusterdeployment $CLUSTER_NAME -n $CLUSTER_NAME -o jsonpath='{.status.installed}')

        echo "   Infrastructure ID: $INFRA_ID"
        echo "   Provision Status: $PROVISION_REASON"

        if [ "$PROVISION_STATUS" == "True" ]; then
            echo "✅ Provisioned: Yes"
        else
            echo "⏳ Provisioned: No"
        fi

        if [ "$INSTALLED" == "true" ]; then
            echo "✅ Installed: Yes"
        else
            echo "⏳ Installed: No"
        fi

        # Check for errors
        FAILED=$(oc get clusterdeployment $CLUSTER_NAME -n $CLUSTER_NAME -o jsonpath='{.status.conditions[?(@.type=="ProvisionFailed")].status}')
        if [ "$FAILED" == "True" ]; then
            FAIL_MESSAGE=$(oc get clusterdeployment $CLUSTER_NAME -n $CLUSTER_NAME -o jsonpath='{.status.conditions[?(@.type=="ProvisionFailed")].message}')
            echo "❌ Error: $FAIL_MESSAGE"
        fi
    else
        echo "⏳ Waiting for ClusterDeployment to be created..."
    fi
    echo ""

    # 4. Provision Pod Status
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 PROVISION POD STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if oc get namespace $CLUSTER_NAME &>/dev/null; then
        POD_STATUS=$(oc get pods -n $CLUSTER_NAME --no-headers 2>/dev/null | grep provision | tail -1)
        if [ -n "$POD_STATUS" ]; then
            echo "   $POD_STATUS"

            POD_NAME=$(echo "$POD_STATUS" | awk '{print $1}')
            POD_STATE=$(echo "$POD_STATUS" | awk '{print $3}')

            if [ "$POD_STATE" == "Running" ]; then
                echo "✅ Pod is running"
            elif [ "$POD_STATE" == "Error" ]; then
                echo "❌ Pod failed - check logs: oc logs $POD_NAME -n $CLUSTER_NAME"
            elif [ "$POD_STATE" == "Completed" ]; then
                echo "✅ Pod completed successfully"
            fi
        else
            echo "   No provision pods found"
        fi
    else
        echo "⏳ Waiting for namespace to be created..."
    fi
    echo ""

    # 5. ManagedCluster Status
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎯 MANAGEDCLUSTER STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if oc get managedcluster $CLUSTER_NAME &>/dev/null; then
        JOINED=$(oc get managedcluster $CLUSTER_NAME -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterJoined")].status}')
        AVAILABLE=$(oc get managedcluster $CLUSTER_NAME -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}')

        if [ "$JOINED" == "True" ]; then
            echo "✅ Joined: Yes"
        else
            echo "⏳ Joined: No"
        fi

        if [ "$AVAILABLE" == "True" ]; then
            echo "✅ Available: Yes"
        else
            echo "⏳ Available: No"
        fi
    else
        echo "⏳ Waiting for ManagedCluster to be created..."
    fi
    echo ""

    # 6. Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Press Ctrl+C to exit | Refreshing every 10 seconds..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    sleep 10
done
