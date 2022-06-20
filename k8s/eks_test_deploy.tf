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

        container {
          name    = "ubuntu-container"
          image   = "ubuntu"
          command = ["sleep"]
          args    = ["1000"]

        }
      }
    }
  }
}
