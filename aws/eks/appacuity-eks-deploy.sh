#!/bin/bash

updateAwsAuthConfigMap=true

existingConfigsDir=existing-configs-$(date +"%Y%m%d-%H%M%S")

function get_sqs_url() {
    clusterName=$1
    aws sqs get-queue-url --queue-name appacuity-eks-${clusterName} | jq -r '.QueueUrl'
}

function get_cluster_names() {
    aws eks list-clusters | jq -r ' . | .clusters[]'
}

function deploy_cluster() {

    account=$1
    region=$2
    clusterName=$3
    sqsUrl=$4

    mkdir -p ${existingConfigsDir}

    appacuityScannerRole=arn:aws:iam::${account}:role/TFAppAcuity_Scanner

    if [ $updateAwsAuthConfigMap = "true" ] ; then
        # first, create a ClusterRole giving AppAcuity read-only access
        kubectl apply -f appacuity-read-access-clusterrole.yaml

        existingAwsAuthConfig=${existingConfigsDir}/${clusterName}.aws-auth.yaml
        kubectl get -n kube-system configmap/aws-auth -o json > ${existingAwsAuthConfig}

        # next, map the AppAcuity 'scanner' role to a Kubernetes user associated with the ClusterRole created above
        grep -q "${appacuityScannerRole}" ${existingAwsAuthConfig}
        if [ $? -ne 0 ] ; then
            cat ${existingAwsAuthConfig} | jq '.data.mapRoles |= "- rolearn: '${appacuityScannerRole}'\n  username: appacuity-scanner\n  groups:\n    - appacuity-read-access-group\n\(.)"' | kubectl apply -f -
        else
            echo "${appacuityScannerRole} already mapped."
        fi
    fi

    # now, set up Falco, and Falco Sidekick to export flows to AppAcuity via SQS ...

    helm repo add falcosecurity https://falcosecurity.github.io/charts

    # get existing config if it exists
    existingFalcoConfig=${existingConfigsDir}/${clusterName}.falco.yaml
    helm get values -n falco -o yaml falco > ${existingFalcoConfig} 2> /dev/null

    # # update the release and add in the AppAcuity values - Sidekick enabled, SQS export, ebpf enabled, and AppAcuity custom rules
    helm upgrade --create-namespace --install falco falcosecurity/falco --namespace falco \
        --values ${existingFalcoConfig} \
        --set falcosidekick.enabled=true \
        --set falcosidekick.config.aws.sqs.url=${sqsUrl} \
        --set falcosidekick.config.aws.region=${region} \
        --set ebpf.enabled=true \
        --values customRules.yaml

}

account=$(aws sts get-caller-identity | jq -r '.Account')
region=$(aws configure get region)

echo "Looking for clusters in ${account}:${region} ..."

for clusterName in $(get_cluster_names) ; do
    echo "### Found cluster: ${clusterName} ###"
    aws eks update-kubeconfig --region ${region} --name ${clusterName} --kubeconfig ./kubeconfig
    if [ $? -ne 0 ] ; then
        echo "Cannot generate kubeconfig"
        continue
    fi
    sqsUrl=$(get_sqs_url ${clusterName}) || continue
    if [ "${sqsUrl}" = "" ] ; then
        echo "Cannot determine SQS URL"
        continue
    fi
    echo "SQS URL = ${sqsUrl}"
    echo "Updating cluster configuration ..."
    KUBECONFIG=./kubeconfig deploy_cluster ${account} ${region} ${clusterName} ${sqsUrl}
    rm -f ./kubeconfig
done
