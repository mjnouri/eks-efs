data "terraform_remote_state" "efs_id" {
  # depends_on = [kubernetes_cluster_role.efs_csi_external_provisioner_role, kubernetes_cluster_role_binding.efs_csi_provisioner_binding, kubernetes_deployment.efs_csi_controller, kubernetes_daemonset.efs_csi_node, kubernetes_csi_driver.efs_csi_aws_com]
  depends_on = [kubernetes_cluster_role.efs_csi_external_provisioner_role, kubernetes_cluster_role_binding.efs_csi_provisioner_binding, kubernetes_deployment.efs_csi_controller, kubernetes_daemonset.efs_csi_node]

  backend = "local"

  config = {
    path = "/mnt/c/Users/Nouri/repos/eks-efs/terraform/terraform.tfstate"
  }
}

resource "kubernetes_storage_class" "efs_sc" {
  depends_on = [data.terraform_remote_state.efs_id]

  metadata {
    name = "efs-sc"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    directoryPerms = "700"

    fileSystemId = data.terraform_remote_state.efs_id.outputs.efs_id

    provisioningMode = "efs-ap"
  }
}

resource "kubernetes_persistent_volume_claim" "efs_claim" {
  depends_on = [kubernetes_storage_class.efs_sc]

  metadata {
    name = "efs-claim"
  }

  spec {
    access_modes = ["ReadWriteMany"]

    resources {
      requests = {
        storage = "20Gi"
      }
    }

    storage_class_name = "efs-sc"
  }
}

resource "kubernetes_deployment" "ubuntu_deployment" {
  depends_on = [kubernetes_persistent_volume_claim.efs_claim]

  metadata {
    name = "ubuntu-deployment"

    labels = {
      env = "dev-deploy"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        env = "dev-pod"
      }
    }

    template {
      metadata {
        name = "ubuntu-pod"

        labels = {
          env = "dev-pod"
        }
      }

      spec {
        volume {
          name = "efs-vol"

          persistent_volume_claim {
            claim_name = "efs-claim"
          }
        }

        container {
          name    = "ubuntu-container"
          image   = "ubuntu"
          command = ["sleep"]
          args    = ["1000"]

          volume_mount {
            name       = "efs-vol"
            mount_path = "/efs"
          }
        }
      }
    }
  }
}
