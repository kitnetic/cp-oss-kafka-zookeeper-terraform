data "google_compute_image" "zookeeper_image" {
  name = var.zookeeper_image_name
}

data "google_compute_image" "kafka_image" {
  name = var.kafka_image_name
}
