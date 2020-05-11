 
provider "google" {
  version = "~> 2.15"
  project = var.project
  region  = var.region
}

resource "google_compute_instance" "docker-node-" {
  count        = var.node_count
  name         = "docker-node-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["reddit-dock"]
  boot_disk {
    initialize_params { image = var.disk_image }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    # путь до публичного ключа
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
}

