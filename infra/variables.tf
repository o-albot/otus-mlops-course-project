variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
  sensitive   = true
}

variable "folder_id" {
  description = "Yandex Folder ID"
  type        = string
  sensitive   = true
}

variable "zone" {
  description = "Default availability zone for nodes"
  type        = string
  default     = "ru-central1-a"
}

variable "yc_token" {
  description = "Yandex Cloud OAuth token"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "mlops"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "node_cores" {
  description = "CPU cores per node"
  type        = number
  default     = 2
}

variable "node_memory" {
  description = "Memory per node (GB)"
  type        = number
  default     = 4
}

variable "node_count" {
  description = "Number of nodes"
  type        = number
  default     = 3
}

variable "service_account_id" {
  description = "Service account ID for cluster"
  type        = string
}
