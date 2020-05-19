
resource "google_compute_instance_template" "kafka" {
  provider       = google-beta
  name_prefix    = "${var.clustername}-kafka"
  project        = var.gcp_project_id
  can_ip_forward = false
  machine_type   = "n1-standard-4"

  tags = [
    var.clustername, "kafka-node", var.environment]

  metadata_startup_script = templatefile("${path.module}/templates/kafka_user_data.sh", local.kafka_userdata_vars)

  disk {
    source_image = data.google_compute_image.kafka_image.self_link
    boot         = true
    disk_type    = "pd-standard"
    disk_size_gb = 30
    auto_delete = false
  }

  disk {
    device_name  = "xvdh"
    disk_type    = "pd-ssd"
    disk_size_gb = 500
    source_image = ""
    auto_delete = false
  }

  network_interface {
    subnetwork = var.cluster_sub_network
    access_config {}
  }

  service_account {
    scopes = ["userinfo-email", "compute-rw", "storage-ro", "logging-write"]
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "google_compute_instance_from_template" "kafka-nodes" {
  count = var.kafka_count

  name = "${var.clustername}-kafka-${count.index+1}"
  source_instance_template = google_compute_instance_template.kafka.self_link

  machine_type = "${var.kafka_machine_type}"

  zone = var.gcp_zone

}

locals {


  kafka_userdata_vars = {
    zookeepers_string = join(",",[ for i in range(var.zookeeper_count) : format("${var.clustername}-zoo-%d:2181", i+1) ])
  }

}

