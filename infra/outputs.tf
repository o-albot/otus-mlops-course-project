# Cluster outputs
output "cluster_id" {
  value = yandex_kubernetes_cluster.mlops.id
}

output "cluster_name" {
  value = yandex_kubernetes_cluster.mlops.name
}

# S3 bucket outputs
output "bucket_name" {
  value = yandex_storage_bucket.mlops.bucket
}

output "bucket_url" {
  value = "s3://${yandex_storage_bucket.mlops.bucket}"
}

# Node group outputs
output "node_group_id" {
  value = yandex_kubernetes_node_group.mlops.id
}

output "node_group_name" {
  value = yandex_kubernetes_node_group.mlops.name
}

# Project info
output "project_info" {
  value = {
    project_name     = var.project_name
    zone            = var.zone
    cluster_version = var.cluster_version
    node_count      = var.node_count
    node_cores      = var.node_cores
    node_memory     = var.node_memory
  }
}
