
provider "aws" {
    region = "us-east-1"
}

data "aws_vpcs" "all_vpcs" {}

module "appacuity_aws_integration" {
    source = "github.com/appacuity/cloud-tools/aws/terraform/module"

    // REQUIRED: contact AppAcuity to get a unique customer id
    // then uncomment the line below and set the value
    // customer_id = ""

    create_scan_role = true
    enable_flow_logs = true
    // example custom VPCs: vpc_id_list = ["vpc-012345678abc123"]
    vpc_id_list = data.aws_vpcs.all_vpcs.ids

    s3_force_destroy = true
    rw_s3_access = true
}


# vim: nospell
