resource "random_password" "db_password" {
  length = 16
  special = true
}

resource "kubenetes_secret" "db_password" {
  metadata {
    name      = "db-password"
    namespace = kubernetes_namespace.db.metadata[0].name
  }

  data = {
    password = var.db_password
  }
}

resource "kubenetes_secret" "db_password_grafana" {
  metadata {
    name      = "db-password"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    password = var.db_password
  }
}