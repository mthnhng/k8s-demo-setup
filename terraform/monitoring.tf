resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "kube_prometheus" {
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "kubernetes_namespace.monitoring.metadata[0].name"

  values = [file("${path.module}./helm_values/kube_prometheus_stack.yaml")]

  depends_on = [
    kubernetes_service.postgres
  ]
}