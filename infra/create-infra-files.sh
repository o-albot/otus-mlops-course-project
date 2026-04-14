#!/bin/bash

# Скрипт для создания всех файлов Terraform в директории infra
# Запуск: ./create-infra-files.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Переменные
PROJECT_DIR="/opt/git_repository/github/o-albot/otus-mlops-course-project"
INFRA_DIR="${PROJECT_DIR}/infra"

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}🚀 Создание Terraform конфигураций${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "Директория: ${INFRA_DIR}"

# Создание директории
mkdir -p ${INFRA_DIR}
cd ${INFRA_DIR}

# Удаляем старые файлы, если есть
rm -f *.tf

# Файл: provider.tf
cat > provider.tf << 'EOF'
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8"
    }
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
  token     = var.yc_token
}
EOF
echo -e "${GREEN}✅ provider.tf${NC}"

# Файл: variables.tf
cat > variables.tf << 'EOF'
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
EOF
echo -e "${GREEN}✅ variables.tf${NC}"

# Файл: terraform.tfvars.example
cat > terraform.tfvars.example << 'EOF'
# Example variables file - copy to terraform.tfvars and fill your values
cloud_id   = "b1gXXXXXXXXXX"
folder_id  = "b1gXXXXXXXXXX"
zone       = "ru-central1-a"
yc_token   = "AQAAAA...your_token..."
project_name = "mlops"
service_account_id = "ajeXXXXXXXXXX"
EOF
echo -e "${GREEN}✅ terraform.tfvars.example${NC}"

# Файл: k8s-cluster.tf (без release_channel - он не поддерживается)
cat > k8s-cluster.tf << 'EOF'
data "yandex_vpc_network" "default" {
  name = "default"
}

data "yandex_vpc_subnet" "default_a" {
  name = "default-ru-central1-a"
}

data "yandex_vpc_subnet" "default_b" {
  name = "default-ru-central1-b"
}

data "yandex_vpc_subnet" "default_d" {
  name = "default-ru-central1-d"
}

resource "yandex_kubernetes_cluster" "mlops" {
  name        = "${var.project_name}-cluster"
  description = "MLOps Kubernetes Cluster"
  network_id  = data.yandex_vpc_network.default.id

  master {
    version   = var.cluster_version
    public_ip = true

    regional {
      region = "ru-central1"
      location {
        zone      = "ru-central1-a"
        subnet_id = data.yandex_vpc_subnet.default_a.id
      }
      location {
        zone      = "ru-central1-b"
        subnet_id = data.yandex_vpc_subnet.default_b.id
      }
      location {
        zone      = "ru-central1-d"
        subnet_id = data.yandex_vpc_subnet.default_d.id
      }
    }
  }

  service_account_id      = var.service_account_id
  node_service_account_id = var.service_account_id
}
EOF
echo -e "${GREEN}✅ k8s-cluster.tf${NC}"

# Файл: node-group.tf
cat > node-group.tf << 'EOF'
resource "yandex_kubernetes_node_group" "mlops" {
  cluster_id = yandex_kubernetes_cluster.mlops.id
  name       = "${var.project_name}-nodes"
  version    = var.cluster_version

  labels = {
    "mlops" = "true"
  }

  instance_template {
    platform_id = "standard-v2"
    resources {
      cores         = var.node_cores
      memory        = var.node_memory
      core_fraction = 100
    }

    boot_disk {
      type = "network-ssd"
      size = 64
    }

    network_interface {
      subnet_ids = [data.yandex_vpc_subnet.default_a.id]
      nat        = true
    }
  }

  scale_policy {
    fixed_scale {
      size = var.node_count
    }
  }

  allocation_policy {
    location {
      zone = var.zone
    }
  }
}
EOF
echo -e "${GREEN}✅ node-group.tf${NC}"

# Файл: s3-bucket.tf
cat > s3-bucket.tf << 'EOF'
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "yandex_storage_bucket" "mlops" {
  bucket    = "${var.project_name}-${random_string.suffix.result}"
  folder_id = var.folder_id
  max_size  = 10737418240

  versioning {
    enabled = true
  }
}
EOF
echo -e "${GREEN}✅ s3-bucket.tf${NC}"

# Файл: outputs.tf
cat > outputs.tf << 'EOF'
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
EOF
echo -e "${GREEN}✅ outputs.tf${NC}"

# Файл: .terraform-version
cat > .terraform-version << 'EOF'
1.9.0
EOF
echo -e "${GREEN}✅ .terraform-version${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ Все файлы Terraform созданы!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Содержимое директории:"
ls -la ${INFRA_DIR}
echo ""
echo -e "${YELLOW}Следующие шаги:${NC}"
echo "1. cd ${INFRA_DIR}"
echo "2. cp terraform.tfvars.example terraform.tfvars"
echo "3. Отредактируйте terraform.tfvars (укажите cloud_id, folder_id, yc_token, service_account_id)"
echo "4. terraform init"
echo "5. terraform plan"
echo "6. terraform apply -auto-approve"
echo ""
echo -e "${YELLOW}Для удаления инфраструктуры:${NC}"
echo "   terraform destroy -auto-approve"
echo -e "${GREEN}=========================================${NC}"