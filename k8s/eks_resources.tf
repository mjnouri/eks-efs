resource "kubernetes_storage_class" "efs_sc" {
  metadata {
    name = "efs-sc"
  }

  parameters = {
    directoryPerms = "700"

    fileSystemId = "fs-02efb1468487d0c4c"

    provisioningMode = "efs-ap"
  }
}

resource "kubernetes_persistent_volume_claim" "efs_claim" {
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
