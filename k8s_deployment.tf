resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx"
    labels = {
      App = "nginx-pod-node"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "nginx-pod-node"
      }
    }
    template {
      metadata {
        labels = {
          App = "nginx-pod-node"
        }
      }
      spec {

        volume {
          name = "workdir"
          empty_dir {}
        }

        init_container {
          name  = "nginx-init"
          image = "busybox:1.28"

          env {
            name = "MY_NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "MY_POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "MY_POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name = "MY_POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

          command = ["sh", "-c", "echo 'Welcome to   POD:$(MY_POD_NAME)   NODE:$(MY_NODE_NAME)   NAMESPACE:$(MY_POD_NAMESPACE)   POD_IP:$(MY_POD_IP)' > /work-dir/index.html"]

          volume_mount {
            name       = "workdir"
            mount_path = "/work-dir"
          }
        }

        container {
          image = "nginx:1.7.8"
          name  = "nginx-pod-node"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          volume_mount {
            name       = "workdir"
            mount_path = "/usr/share/nginx/html"
          }

        }
      }
    }
  }
}
