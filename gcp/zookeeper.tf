


resource "google_compute_instance_template" "zookeeper" {
  provider       = google-beta
  name_prefix    = "${var.clustername}-zookeeper"
  project        = "${var.gcp_project_id}"
  can_ip_forward = false
  machine_type   = "n1-standard-1"

  tags = ["${var.clustername}", "zookeeper-node", "${var.environment}"]

  # metadata_startup_script = "${data.template_file.zookeeper_userdata_script.rendered}"

  metadata_startup_script = templatefile("${path.module}/templates/zookeeper_user_data.sh", local.zookeeper_userdata_vars)


  disk {
    source_image = data.google_compute_image.zookeeper_image.self_link
    boot         = true
    disk_type    = "pd-standard"
    disk_size_gb = 30
    auto_delete = false
  }

  disk {
    device_name  = "xvdh"
    disk_type    = "pd-standard"
    disk_size_gb = 50
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

resource "google_compute_instance_from_template" "zookeeper" {
  count = var.zookeeper_count

  name = "${var.clustername}-zoo-${count.index+1}"
  source_instance_template = google_compute_instance_template.zookeeper.self_link

  machine_type = "${var.zookeper_machine_type}"

  zone = var.gcp_zone

  depends_on = [google_compute_instance_template.zookeeper]
}

locals {
  zookeeper_userdata_vars = {
    allZookeeperIds = slice(["1","2","3","4","5","6","7"],0,var.zookeeper_count),
    host_name_base = "${var.clustername}-zoo"
  }

}



