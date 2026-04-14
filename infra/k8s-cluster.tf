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
