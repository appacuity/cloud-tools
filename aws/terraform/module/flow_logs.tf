data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


// ---- S3 buckets to store logs

// NOTE: bucket name must be globally unique
resource "aws_s3_bucket" "vpc_logs" {
  count  = var.enable_flow_logs ? length(var.vpc_id_list) : 0
  bucket = join("-", [var.s3_bucket_prefix, data.aws_caller_identity.current.account_id, var.vpc_id_list[count.index]]) # MUST MATCH
  acl    = "private"
  force_destroy = var.s3_force_destroy
  policy = templatefile(
    "${path.module}/templates/s3_flow_logs_policy.json.tmpl",
    { bucket = join("-", [var.s3_bucket_prefix, data.aws_caller_identity.current.account_id, var.vpc_id_list[count.index]]) } # MUST MATCH
  )
}

resource "aws_s3_bucket_public_access_block" "vpc_logs" {
  count                   = var.enable_flow_logs ? length(var.vpc_id_list) : 0
  bucket                  = aws_s3_bucket.vpc_logs[count.index].id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}


// ---- VPC flow logs

resource "aws_flow_log" "vpc_logs" {
  count = var.enable_flow_logs ? length(var.vpc_id_list) : 0
  log_destination = "${aws_s3_bucket.vpc_logs[count.index].arn}/"
  log_destination_type     = "s3"
  log_format               = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${pkt-src-aws-service} $${pkt-dst-aws-service} $${flow-direction} $${traffic-path}"
  traffic_type             = "ALL"
  max_aggregation_interval = (var.store_logs_more_frequently == false ? 600 : 60)
  vpc_id                   = var.vpc_id_list[count.index]
}


// ---- SQS

resource "aws_sqs_queue" "sqs_queues" {
  count = var.enable_flow_logs ? length(var.vpc_id_list) : 0
  name = join("-", [var.s3_bucket_prefix, data.aws_caller_identity.current.account_id, var.vpc_id_list[count.index], "queue"]) # MUST MATCH BELOW
  message_retention_seconds = 600 # seconds
  policy = templatefile(
    "${path.module}/templates/sqs_flow_logs_policy.json.tmpl",
    {
      account_id = data.aws_caller_identity.current.account_id,
      region = data.aws_region.current.name,
      receiver_role = aws_iam_role.flow_logs_role[0].arn,
      bucket_arn = aws_s3_bucket.vpc_logs[count.index].arn,
      queue_name = join("-", [var.s3_bucket_prefix, data.aws_caller_identity.current.account_id, var.vpc_id_list[count.index], "queue"]) # MUST MATCH ABOVE
    }
  )
}

resource "aws_s3_bucket_notification" "bucket_notifications" {
  count = var.enable_flow_logs ? length(var.vpc_id_list) : 0
  bucket = aws_s3_bucket.vpc_logs[count.index].id
  queue {
    queue_arn = aws_sqs_queue.sqs_queues[count.index].arn
    events = ["s3:ObjectCreated:Put", "s3:ObjectCreated:Post"]
  }
}

# vim: nospell
