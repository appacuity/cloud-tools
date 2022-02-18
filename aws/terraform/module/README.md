# AppAcuity AWS Deployment Tool

The AppAcuity AWS Deployment Tool can be used to configure all 
roles, permissions, and services necessary for AppAcuity to:

1. scan your AWS configuration
2. examine AWS network flows


## Prerequisites

1. Terraform 0.13.0 or greater. Terraform is an open-source tool to
   manage AWS services.
2. AWS admin credentials
3. Unique Customer ID supplied by AppAcuity


## What Is Configured?

### Configuration Scan

1. An IAM role ``TFAppAcuity_Scanner`` is created. This has a trust relationship to AppAcuity AWS account so that we can assume this role.
2. The AWS built-in ``SecurityAudit`` policy is attached to (1)
3. A custom ``TFAppAcuity_ScanExtras`` policy is attached to (1). This policy is needed to grant read access to resources not covered by the default SecurityAudit


### Network Flows (VPCs)

1. An IAM role ``TFAppAcuity_FlowLogs`` is created. This has a trust relationship to AppAcuity AWS account so that we can assume this role.
2. The AWS built-in ``EC2ReadOnlyAccess`` policy is attached to (1). This is so the flow log collector can get a list of VPCs and other information necessary to run.
3. A custom ``TFAppAccuity_S3PolicyAccess`` policy is attached to (1). This grants access to the S3 buckets used to store the flow logs.
4. An S3 bucket _per_ VPC is configured for writing flow logs to. This is fully locked down with the only read access granted to (1).
5. Flow logging is enabled _per_ VPC and set to write to the S3 buckets (4)
6. For each S3 bucket an SQS queue is created for notifications. This is used to notify the flow log collector to pick up new logs. These queues are locked down so that only the bucket can write to them, and only our role can read from the queue.
7. Each S3 bucket is configured to send notifications to it's SQS queue when objects are created (new logs added).

### Network Flows (EKS)

1. Uses the same IAM role as for VPC Network Flows
2. For each EKS cluster an SQS queue is created for sending flows. This is used by the flow log collector to injest EKS logs. These queues are locked down so that only the EKS cluster can write to them, and only our role can read from the queue.

### Installation Options

1. (required) Set the Customer ID: set ``customer_id = "..."`` (this needs to be supplied by AppAcuity)
2. Configure the AWS region: set ``region = ...`` (default is ``us-east-1``)<br>_Note: only a single region is currently supported_
3. Disable Configuration Scan: set ``create_scan_role = false``
4. Disable Network Flows: set ``enable_flow_logs = false``
5. Limit Network Flows to specific VPCs: replace ``vpc_id_list`` with an array of VPC ids. These will need to be looked up in your AWS environment.


## Installation

_Note: It's assumed Terraform is already installed and AWS credentials
are configured for use by Terraform. Refer to the AWS Provider
documentation for more information: https://registry.terraform.io/providers/hashicorp/aws/latest/docs_

1. unzip the tool distribution and change into the directory
2. edit ``main.tf`` (see _Installation Options_ above)
3. run ``$ terraform init``
4. run ``$ terraform validate``
5. run ``$ terraform plan``<br>This command will print out the planned set of changes which can be inspected if desired.
6. run ``$ terraform apply`` to deploy the plan


## Removing AppAcuity

From the same system used to install Terraform can be used to remove
anything deployed by this tool. Run the following command:

```
$ terraform destroy
```

