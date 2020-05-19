resource "google_compute_firewall" "kafka-internode" {
  name    = "${var.clustername}-firewall-allow-internode"
  network = var.cluster_network

  allow {
    protocol = "tcp"
    ports    = ["2181","2888","3888","8080","9092"]
  }

  source_tags = [var.clustername]
}

resource "google_compute_firewall" "ssh-access" {
  name    = "${var.clustername}-firewall-allow-ssh"
  network = var.cluster_network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = [var.clustername]

  source_ranges = var.ssh_access_network_range
}

resource "google_compute_firewall" "kafka-access" {
  name    = "${var.clustername}-firewall-allow-kafka"
  network = var.cluster_network

  allow {
    protocol = "tcp"
    ports    = ["2181","9092"]
  }

  target_tags = [var.clustername]

  source_ranges = var.kafka_access_network_range
}
