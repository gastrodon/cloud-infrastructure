variable "labels_dashboard" {
  description = "Labels to assign to and look for on dashboard resources"
  type        = map(string)
}

variable "labels_metrics_scraper" {
  description = "Labels to assign to and look for on metrics-scraper resources"
  type        = map(string)
}

variable "image_dashboard" {
  description = "kubernetes dashboard docker image"
  type        = string
}

variable "image_metrics_scraper" {
  description = "metrics-scraper docker image"
  type        = string
}

variable "name_dashboard" {
  description = "A name to give the dashboard"
  type        = string
}

variable "name_dashboard_config_map" {
  description = "A name to give the dashboard config map"
  type        = string
}

variable "name_dashboard_service_user" {
  description = "A name to give the created dashboard service user"
  type        = string
}

variable "name_metrics_scraper" {
  description = "A name to give the metrics-scraper"
  type        = string
}

variable "name_namespace" {
  description = "A name to give the dashboard namespace"
  type        = string
}
