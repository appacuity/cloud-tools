// ---- AWS SCAN

resource "aws_iam_role" "scan_role" {
    count = var.create_scan_role ? 1 : 0
    name = "${var.iam_role_prefix}_Scanner"

    description = "Provides access for AppAcuity to scan a customer's AWS environment"
    force_detach_policies = true

    assume_role_policy = templatefile("${path.module}/templates/assume_role.json.tmpl", {
        external_id = var.customer_id
    })
    tags = {
        Provisioner = "TFAppAcuity"
    }
}

resource "aws_iam_policy" "appacuity_scan_policy" {
    count = var.create_scan_role ? 1 : 0
    name        = "${var.iam_role_prefix}_ScanExtrasPolicy"

    description = "Provides additional access not provided by SecurityAudit"
    path        = "/"
    policy = templatefile("${path.module}/templates/scan_extras_policy.json.tmpl", {})
}

resource "aws_iam_role_policy_attachment" "attach_scan_policy" {
  count      = var.create_scan_role ? 1 : 0
  role       = aws_iam_role.scan_role[count.index].name
  policy_arn = aws_iam_policy.appacuity_scan_policy[count.index].arn
}

resource "aws_iam_role_policy_attachment" "attach_secaudit_policy" {
  count      = var.create_scan_role ? 1 : 0
  role       = aws_iam_role.scan_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}



// ---- FLOW LOGS

resource "aws_iam_role" "flow_logs_role" {
    count = var.enable_flow_logs && var.create_flow_logs_role ? 1 : 0
    name = "${var.iam_role_prefix}_FlowLogs"

    description = "Provides access for AppAcuity to read Flow Logs"
    force_detach_policies = true

    assume_role_policy = templatefile("${path.module}/templates/assume_role.json.tmpl", {
        external_id = var.customer_id
    })
    tags = {
        Provisioner = "TFAppAcuity"
    }
}

resource "aws_iam_policy" "appacuity_s3_policy" {
    count = var.enable_flow_logs && var.create_flow_logs_role ? 1 : 0
    name        = "${var.iam_role_prefix}_S3PolicyAccess"

    description = "Provides access to S3 resources (Flow Logs)"
    path        = "/"
    policy = templatefile(
        "${path.module}/templates/s3_read_logs_policy.json.tmpl",
        {
            actions_list = (var.rw_s3_access == false ? ["s3:Get*", "s3:List*", "s3:HeadBucket"] : ["s3:*"]),
            buckets_list = [for bucketobject in aws_s3_bucket.vpc_logs : bucketobject.arn],
        }
    )
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  count      = var.enable_flow_logs && var.create_flow_logs_role ? 1 : 0
  role       = aws_iam_role.flow_logs_role[count.index].name
  policy_arn = aws_iam_policy.appacuity_s3_policy[count.index].arn
}

resource "aws_iam_role_policy_attachment" "attach_ec2readonly_policy" {
  count      = var.enable_flow_logs && var.create_flow_logs_role ? 1 : 0
  role       = aws_iam_role.flow_logs_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# vim: nospell
