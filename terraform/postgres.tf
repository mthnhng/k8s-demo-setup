resource "kubernetes_namespace" "db" {
  metadata {
    name = "database"
  }
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres-grafana"
    namespace = kubernetes_namespace.db.metadata[0].name
    labels = {
      app  = "postgres"
      tier = "db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app  = "postgres"
        tier = "db"
      }
    }

    template {
      metadata {
        labels = {
          app  = "postgres"
          tier = "db"
        }
      }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.io/hostname"
                  operator = "In"
                  values   = ["node01", "controlplane01"]
                }
              }
            }
          }
        }

        container {
          image = "postgres:15"
          name  = "postgres"
          
          env {
            name  = "POSTGRES_DB"
            value = "grafana"
          }
          env {
            name  = "POSTGRES_USER"
            value = "grafana"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_password.metadata[0].name
                key  = "password"
              }
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
          
          port {
            container_port = 5432
          }
        }

        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres-svc"
    namespace = kubernetes_namespace.db.metadata[0].name
  }
  spec {
    selector = {
      app = "postgres"
    }
    port {
      port        = 5432
      target_port = 5432
    }
  }
}

