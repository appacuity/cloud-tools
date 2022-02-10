
// ---- SQS per cluster

data "aws_eks_clusters" "all_clusters" {}

data "aws_eks_node_groups" "all_groups" {
    for_each = data.aws_eks_clusters.all_clusters.names
    cluster_name = each.value
}

locals {
    // need this to drive node_group_detail
    node_group_list = flatten([
        for cluster in data.aws_eks_node_groups.all_groups: [
            for name in cluster.names: {
                id = "${cluster.cluster_name}:${name}"
                cluster = "${cluster.cluster_name}"
                node_group = "${name}"
            }
        ]
    ])
}

data "aws_eks_node_group" "node_group_detail" {
    for_each = {
        for entry in local.node_group_list : entry.id => entry
    }
    cluster_name = each.value.cluster
    node_group_name = each.value.node_group
}


locals {
    clusters = tolist(data.aws_eks_clusters.all_clusters.names)

    arns_by_cluster = {
        for cluster in data.aws_eks_node_groups.all_groups:
            "${cluster.cluster_name}" =>
                distinct(flatten([
                    for detail in data.aws_eks_node_group.node_group_detail : detail.node_role_arn
                    if detail.cluster_name == cluster.cluster_name
                ]))
    }

}

resource "aws_sqs_queue" "eks_sqs_queues" {
  count = var.enable_flow_logs ? length(local.clusters) : 0
  // TODO: we truncate cluster name since this may exceed SQS name max length. Perhaps there is a better way....
  name = join("-", [var.eks_queue_prefix, substr(local.clusters[count.index], 0, 65)]) # MUST MATCH BELOW
  message_retention_seconds = 600 # seconds
  policy = templatefile(
    "${path.module}/templates/sqs_eks_policy.json.tmpl",
    {
      receiver_role = aws_iam_role.flow_logs_role[0].arn,
      bucket_arns = local.arns_by_cluster[local.clusters[count.index]],
      queue_name = join("-", [var.eks_queue_prefix, substr(local.clusters[count.index], 0, 65)]) # MUST MATCH ABOVE
    }
  )
  tags = {
      ClusterName = local.clusters[count.index]
  }
}


# vim: nospell
