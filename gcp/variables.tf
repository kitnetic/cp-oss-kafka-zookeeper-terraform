variable "gcp_project_id" {
  type = "string"
}

variable "gcp_zone" {
  type = "string"
  default = "us-central1-a"
}

variable "environment" {
  type = string
}

variable "cluster_sub_network" {
  type = "string"
}

variable "cluster_network" {
  type = "string"
}

variable "clustername" {
  description = "Name of the  cluster, used as base for all kafka and zookeper nodes"
}

variable "zookeeper_image_name" {
  type = "string"
}

variable "zookeper_machine_type" {
  type = "string"
  default = "n1-standard-1"
}

variable "kafka_machine_type" {
  type = "string"
  default = "n1-standard-4"
}

variable "zookeeper_count" {
  type = number
  default = 3
}

variable "kafka_count" {
  type = number
  default = 3
}

variable "kafka_image_name" {
  type = "string"
}

variable "kafka_access_network_range" {
  type = list
}

variable "ssh_access_network_range" {
  type = list
}
