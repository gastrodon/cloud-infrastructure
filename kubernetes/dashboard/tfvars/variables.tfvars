labels_dashboard       = { resource = "dashboard" }
labels_metrics_scraper = { resource = "metrics-scraper" }

image_dashboard       = "kubernetesui/dashboard:v2.4.0"
image_metrics_scraper = "kubernetesui/metrics-scraper:v1.0.7"

name_dashboard              = "dashboard"
name_dashboard_config_map   = "dashboard-config"
name_dashboard_service_user = "dashboard-admin"
name_metrics_scraper        = "metrics-scraper"
name_namespace              = "dashboard"
