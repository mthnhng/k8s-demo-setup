resource "kubernetes_persistent_volume" "postgres_pv" {
  metadata {
    name = "postgres-pv"
  }
  spec {
    capacity = {
      storage = "5Gi"
    }
    access_modes = ["ReadWriteOnce"]
    
    storage_class_name = "database"

    persistent_volume_source {
      host_path {
        path = "/data/postgres" # will change to aws EBS in the future
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  metadata {
    name      = "postgres-pvc"
    namespace = kubernetes_namespace.db.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "database"
    resources {
      requests = {
        storage = "5Gi"
      }
    }

    volume_name = kubernetes_persistent_volume.postgres_pv.metadata[0].name
  }
}