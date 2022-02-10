# AppAcuity EKS Deployment

This document describes how to configure your EKS clusters so that AppAcuity can

1. scan the cluster configuration
2. examine Kubernetes network flows, both internal and external

## Prerequisites

1. Kubernetes CLI - kubectl 
2. AWS CLI
3. AWS admin credentials
4. jq utility - https://stedolan.github.io/jq/download/

It is assumed that either the AWS Deployment Tool has been run, or appropriate roles created for

1. Scanning the AWS environment
2. Consuming flow logs

## What Is Configured?

### Configuration Scan

The IAM role ``TFAppAcuity_Scanner`` is mapped to the ``appacuity-scanner`` Kubernetes role.  This is achieved by updating the ``aws-auth`` ConfigMap.  The following element is added to the ``data.mapRoles`` value:
```
    - roleArn: arn:aws:iam::<ACCOUNT>:role/TFAppAcuity_Scanner
      username: appacuity-scanner
      groups:
        - appacuity-read-access-group
```

### Flow Collection

The ``appacuity-eks-deploy.sh`` script assumes Falco is (or can be) installed with the Falco Helm chart.  It upgrades the release to:
1. enable eBPF
2. add some custom rules to provide AppAcuity with cluster network flow events
3. enable Falco Sidekick
4. configure Sidekick to export events to the SQS queues created for it (see https://github.com/appacuity/cloud-tools/tree/main/aws/terraform/module) 

## Deployment

Examine ``appacuity-eks-deploy.sh`` - comment out any actions you'd rather it didn't perform automatically.  The script runs in the context of the AWS CLI, so make sure AWS_PROFILE is set appropriately.  Also ensure your profile configuration specifies a default region.

For example:
```
AWS_PROFILE=devel ./appacuity-eks-deploy.sh
```

A directory is created with the prefix ``existing-configs`` in the current directory.  It contains configuration state which can be used later to restore the cluster configuration to the previous state.

## Removal

A script is provided to restore EKS clusters to the state they were in when the deploy script encountered them.  Specify the directory in which previous configs were cached, for example:
```
AWS_PROFILE=devel ./appacuity-eks-remove.sh existing-configs-20222608-142601
```

The script conservatively does not attempt to restore the ``aws-auth`` ConfigMap.  Edit the script and set the ``restoreAwsAuthConfigMap`` variable to ``true`` to enable.  Be aware that it will force the ``aws-auth`` map state to what it was prior to ``appacuity-eks-deploy.sh`` being run.  You can check the ``<clusterName>.aws-auth.yaml`` file in the ``existing-configs-<DATE>`` directory to see what this is.