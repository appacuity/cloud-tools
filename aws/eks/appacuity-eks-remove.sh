#!/bin/bash

restoreAwsAuthConfigMap=false

allArgs=($*)

existingConfigsDir=${allArgs[0]}
if [ "${existingConfigsDir}" = "" ]; then
    echo Must specify stored configuration directory.
    exit 1
fi

clusterNames=${allArgs[@]:1}

function get_cluster_names() {
    aws eks list-clusters | jq -r ' . | .clusters[]'
}

function restore_cluster_config() {

    account=$1
    region=$2
    clusterName=$3
    sqsUrl=$4

    mkdir -p ${existingConfigsDir}

    appacuityScannerRole=arn:aws:iam::${account}:role/TFAppAcuity_Scanner

    if [ $restoreAwsAuthConfigMap = "true" ] ; then
        # next, apply the previous aws-auth ConfigMap
        kubectl get -n kube-system configmap/aws-auth -o json | grep -q "${appacuityScannerRole}"
        if [ $? -eq 0 ] ; then
            # TODO properly prune the mapping
            # FIXME this isn't reliable!
            # Operation cannot be fulfilled on configmaps "aws-auth": the object has been modified; please apply your changes to the latest version and try again
            kubectl apply --force -f ${existingConfigsDir}/${clusterName}.aws-auth.yaml
        else
            echo "${appacuityScannerRole} not mapped."
        fi

        # remove the ClusterRole giving AppAcuity read-only access
        kubectl delete -f appacuity-read-access-clusterrole.yaml
    fi

    # get existing config if it exists
    helm get values -n falco -o json falco > ${existingConfigsDir}/${clusterName}.yaml 2> /dev/null

    # update the release and add in the AppAcuity values - Sidekick enabled, SQS export, ebpf enabled, and AppAcuity custom rules
    helm upgrade --create-namespace --install falco falcosecurity/falco --namespace falco \
        --values ${existingConfigsDir}/${clusterName}.falco.yaml
}

account=$(aws sts get-caller-identity | jq -r '.Account')
region=$(aws configure get region)

if ((${#clusterNames[@]})); then
    echo "Clusters specified on command line: ${clusterNames[@]}"
else
    echo "Looking for clusters in ${account}:${region} ..."
    clusterNames=($(get_cluster_names))
fi

for clusterName in ${clusterNames[@]} ; do
    echo "### Found cluster: ${clusterName} ###"
    aws eks update-kubeconfig --region ${region} --name ${clusterName} --kubeconfig ./kubeconfig
    if [ $? -ne 0 ] ; then
        echo "Cannot generate kubeconfig"
        continue
    fi
    echo "Updating cluster configuration ..."
    KUBECONFIG=./kubeconfig restore_cluster_config ${account} ${region} ${clusterName} ${sqsUrl}
    rm -f ./kubeconfig
done
