data "terraform_remote_state" "eks_serviceaccount_role" {
  backend = "local"

  config = {
    path = "../terraform_aws/terraform.tfstate"
  }
}

resource "kubernetes_service_account" "efs_csi_controller_sa" {
  metadata {
    name      = "efs-csi-controller-sa"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = data.terraform_remote_state.eks_serviceaccount_role.outputs.eks_serviceaccount_role
    }
  }

  # secret {
  #   name = "efs-csi-controller-sa-token-bxmlg"
  # }
}

resource "kubernetes_cluster_role" "efs_csi_external_provisioner_role" {
  metadata {
    name = "efs-csi-external-provisioner-role"

    labels = {
      "app.kubernetes.io/name" = "aws-efs-csi-driver"
    }
  }

  rule {
    verbs      = ["get", "list", "watch", "create", "delete"]
    api_groups = [""]
    resources  = ["persistentvolumes"]
  }

  rule {
    verbs      = ["get", "list", "watch", "update"]
    api_groups = [""]
    resources  = ["persistentvolumeclaims"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
  }

  rule {
    verbs      = ["list", "watch", "create"]
    api_groups = [""]
    resources  = ["events"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["storage.k8s.io"]
    resources  = ["csinodes"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["nodes"]
  }

  rule {
    verbs      = ["get", "watch", "list", "delete", "update", "create"]
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
  }
}

resource "kubernetes_cluster_role_binding" "efs_csi_provisioner_binding" {
  depends_on = [kubernetes_cluster_role.efs_csi_external_provisioner_role]

  metadata {
    name = "efs-csi-provisioner-binding"

    labels = {
      "app.kubernetes.io/name" = "aws-efs-csi-driver"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = "efs-csi-controller-sa"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "efs-csi-external-provisioner-role"
  }
}

resource "kubernetes_deployment" "efs_csi_controller" {
  depends_on = [kubernetes_cluster_role_binding.efs_csi_provisioner_binding]

  metadata {
    name      = "efs-csi-controller"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/name" = "aws-efs-csi-driver"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "efs-csi-controller"

        "app.kubernetes.io/instance" = "kustomize"

        "app.kubernetes.io/name" = "aws-efs-csi-driver"
      }
    }

    template {
      metadata {
        labels = {
          app = "efs-csi-controller"

          "app.kubernetes.io/instance" = "kustomize"

          "app.kubernetes.io/name" = "aws-efs-csi-driver"
        }
      }

      spec {
        volume {
          name      = "socket-dir"
          # empty_dir = {}
        }

        container {
          name  = "efs-plugin"
          image = "amazon/aws-efs-csi-driver:v1.2.0"
          args  = ["--endpoint=$(CSI_ENDPOINT)", "--logtostderr", "--v=2", "--delete-access-point-root-dir=false"]

          port {
            name           = "healthz"
            container_port = 9909
            protocol       = "TCP"
          }

          env {
            name  = "CSI_ENDPOINT"
            value = "unix:///var/lib/csi/sockets/pluginproxy/csi.sock"
          }

          volume_mount {
            name       = "socket-dir"
            mount_path = "/var/lib/csi/sockets/pluginproxy/"
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = "healthz"
            }

            initial_delay_seconds = 10
            timeout_seconds       = 3
            period_seconds        = 10
            failure_threshold     = 5
          }

          image_pull_policy = "IfNotPresent"

          security_context {
            privileged = true
          }
        }

        container {
          name  = "csi-provisioner"
          image = "public.ecr.aws/eks-distro/kubernetes-csi/external-provisioner:v2.1.1-eks-1-18-2"
          args  = ["--csi-address=$(ADDRESS)", "--v=2", "--feature-gates=Topology=true", "--leader-election"]

          env {
            name  = "ADDRESS"
            value = "/var/lib/csi/sockets/pluginproxy/csi.sock"
          }

          volume_mount {
            name       = "socket-dir"
            mount_path = "/var/lib/csi/sockets/pluginproxy/"
          }
        }

        container {
          name  = "liveness-probe"
          image = "public.ecr.aws/eks-distro/kubernetes-csi/livenessprobe:v2.2.0-eks-1-18-2"
          args  = ["--csi-address=/csi/csi.sock", "--health-port=9909"]

          volume_mount {
            name       = "socket-dir"
            mount_path = "/csi"
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        service_account_name = "efs-csi-controller-sa"
        host_network         = true

        toleration {
          operator = "Exists"
        }

        priority_class_name = "system-cluster-critical"
      }
    }
  }
}

resource "kubernetes_daemonset" "efs_csi_node" {
  depends_on = [kubernetes_cluster_role_binding.efs_csi_provisioner_binding]

  metadata {
    name      = "efs-csi-node"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/name" = "aws-efs-csi-driver"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "efs-csi-node"

        "app.kubernetes.io/instance" = "kustomize"

        "app.kubernetes.io/name" = "aws-efs-csi-driver"
      }
    }

    template {
      metadata {
        labels = {
          app = "efs-csi-node"

          "app.kubernetes.io/instance" = "kustomize"

          "app.kubernetes.io/name" = "aws-efs-csi-driver"
        }
      }

      spec {
        volume {
          name = "kubelet-dir"

          host_path {
            path = "/var/lib/kubelet"
            type = "Directory"
          }
        }

        volume {
          name = "plugin-dir"

          host_path {
            path = "/var/lib/kubelet/plugins/efs.csi.aws.com/"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "registration-dir"

          host_path {
            path = "/var/lib/kubelet/plugins_registry/"
            type = "Directory"
          }
        }

        volume {
          name = "efs-state-dir"

          host_path {
            path = "/var/run/efs"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "efs-utils-config"

          host_path {
            path = "/var/amazon/efs"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "efs-utils-config-legacy"

          host_path {
            path = "/etc/amazon/efs"
            type = "DirectoryOrCreate"
          }
        }

        container {
          name  = "efs-plugin"
          image = "amazon/aws-efs-csi-driver:v1.2.0"
          args  = ["--endpoint=$(CSI_ENDPOINT)", "--logtostderr", "--v=2"]

          port {
            name           = "healthz"
            container_port = 9809
            protocol       = "TCP"
          }

          env {
            name  = "CSI_ENDPOINT"
            value = "unix:/csi/csi.sock"
          }

          volume_mount {
            name              = "kubelet-dir"
            mount_path        = "/var/lib/kubelet"
            mount_propagation = "Bidirectional"
          }

          volume_mount {
            name       = "plugin-dir"
            mount_path = "/csi"
          }

          volume_mount {
            name       = "efs-state-dir"
            mount_path = "/var/run/efs"
          }

          volume_mount {
            name       = "efs-utils-config"
            mount_path = "/var/amazon/efs"
          }

          volume_mount {
            name       = "efs-utils-config-legacy"
            mount_path = "/etc/amazon/efs-legacy"
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = "healthz"
            }

            initial_delay_seconds = 10
            timeout_seconds       = 3
            period_seconds        = 2
            failure_threshold     = 5
          }

          security_context {
            privileged = true
          }
        }

        container {
          name  = "csi-driver-registrar"
          image = "public.ecr.aws/eks-distro/kubernetes-csi/node-driver-registrar:v2.1.0-eks-1-18-2"
          args  = ["--csi-address=$(ADDRESS)", "--kubelet-registration-path=$(DRIVER_REG_SOCK_PATH)", "--v=2"]

          env {
            name  = "ADDRESS"
            value = "/csi/csi.sock"
          }

          env {
            name  = "DRIVER_REG_SOCK_PATH"
            value = "/var/lib/kubelet/plugins/efs.csi.aws.com/csi.sock"
          }

          env {
            name = "KUBE_NODE_NAME"

            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          volume_mount {
            name       = "plugin-dir"
            mount_path = "/csi"
          }

          volume_mount {
            name       = "registration-dir"
            mount_path = "/registration"
          }
        }

        container {
          name  = "liveness-probe"
          image = "public.ecr.aws/eks-distro/kubernetes-csi/livenessprobe:v2.2.0-eks-1-18-2"
          args  = ["--csi-address=/csi/csi.sock", "--health-port=9809", "--v=2"]

          volume_mount {
            name       = "plugin-dir"
            mount_path = "/csi"
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "linux"
        }

        host_network = true

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "eks.amazonaws.com/compute-type"
                  operator = "NotIn"
                  values   = ["fargate"]
                }
              }
            }
          }
        }

        toleration {
          operator = "Exists"
        }

        priority_class_name = "system-node-critical"
      }
    }
  }
}

# Got an error saying efs.csi.aws.com was already installed. Left this out and everything still worked, but understand why.
# resource "kubernetes_csi_driver" "efs_csi_aws_com" {
#   depends_on = [kubernetes_daemonset.efs_csi_node]

#   metadata {
#     name = "efs.csi.aws.com"

#     annotations = {
#       "helm.sh/hook" = "pre-install, pre-upgrade"

#       "helm.sh/hook-delete-policy" = "before-hook-creation"

#       "helm.sh/resource-policy" = "keep"
#     }
#   }
# }
