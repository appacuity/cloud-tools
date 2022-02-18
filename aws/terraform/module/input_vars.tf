
// --- AWS environment scanning related

variable "create_scan_role" {
    description = "Create role used for AWS infrastructure scanning"
    type = bool
    default = true
}



// --- flow log related

variable "create_flow_logs_role" {
    description = "Create role used for monitoring flow logs"
    type = bool
    default = true
}

variable "enable_flow_logs" {
    description = "Create S3 bucket and enable flow logs for vpc_id_list"
    type = bool
    default = false
}

variable "s3_force_destroy" {
  description = "Delete bucket even if it is not empty"
  type        = bool
  default     = false
}

variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket name (must be lowercase)"
  type        = string
  default     = "appacuity-flowlogs"
}

variable "eks_queue_prefix" {
  description = "Prefix for S3 bucket name (must be lowercase)"
  type        = string
  default     = "appacuity-eks"
}

variable "rw_s3_access" {
  description = "If set to true, AppAcuity will be able to delete old logs from s3 bucket"
  type        = bool
}

variable "vpc_id_list" {
  description = "List of VPSs to enable flow logs for"
  type        = list(string)
  default     = [""]
}

variable "store_logs_more_frequently" {
  description = "Adds option to store data in 1 minute interval (default is 10 minutes)"
  type        = bool
  default     = false
}



// --- Miscellaneous

variable "iam_role_prefix" {
    description = "Use prefix on all IAM roles managed by AppAcuity"
    type = string
    default = "TFAppAcuity"
}

variable "customer_id" {
    description = "External ID used for AssumeRole operations"
    type = string
}


# vim: nospell
