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
