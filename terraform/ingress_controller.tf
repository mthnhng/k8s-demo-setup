resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.14.0"
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [file("${path.module}./helm_values/ingress_nginx.yaml")]
}