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
