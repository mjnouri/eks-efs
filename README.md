# eks-efs
Deploy a sample containerized app using EFS storage to EKS

    article outline
- explain at 10k level what we are building. maybe 3-5 plain english sentences. exec summary.
- show diagram ("we'll zoom in to specific areas as we build each part")
- explain eks in a few sentences
- efs part
    - what is persistent storage and why it's important in k8s
    - say what EFS is, what problems it solves (aws managed nfs, storage sharing)
- go over more detailed infra build steps with zoomed in diagram and noted tf/yaml
    - spin up all resources with tf
    - verify deployments
    - take time to explain
        - eks pod SGs
        - efs policy allowing eks pods
        - efs iam policy allowing pods
        - efs access points
        - install EFS CSI driver and why we need it (https://aws.amazon.com/premiumsupport/knowledge-center/eks-persistent-storage/)
        - deploy app with efs to eks
    - kubectl execs as proof in pod1
        - show list of NFS mount points
        - show contents of EFS mount point
        - make a file, or edit WordPress config file
        - restart services on other pods if you have to
        - on pod2, check contents of file
        - on pod3, check contents of file
    - teardown deployments and infra

    to do:
- make everything 3 subnets
- efs should be One Zone storage class
- find better way to listing 3 subnets
- replace efs line 51 with IAM role on EKS worker nodes
- show mount command from k describe pod that is run in containers
- trace efs resource-based policy allowing only eks worker nodes, and nodes have policy accessing efs id, maybe
- trace iam policy -> iam role -> oidc url to k8s serviceaccount -> clusterrolebinding -> role with permissions to k8s
- deploy sc and run waiter to make sure it's good
- deploy pvc and run waiter to make sure it's bound, then deploy the deployment
- add that you got efs csi config files with kubectl kustomize "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.2"

---

to add other IAM users access to EKS cluster
kubectl edit -n kube-system configmap/aws-auth
  mapUsers: |
    - groups:
      - system:masters
      userarn: arn:aws:iam::765981046280:user/devils
      username: devils

or this does the same thing
eksctl create iamidentitymapping --cluster test_eks_cluster --region=us-east-1 --arn arn:aws:iam::765981046280:user/devils --group system:masters --no-duplicate-arns

here is an example aws-auth config map from the documentation
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::111122223333:role/my-role
      username: system:node:{{EC2PrivateDNSName}}
    - groups:
      - eks-console-dashboard-full-access-group
      rolearn: arn:aws:iam::111122223333:role/my-console-viewer-role
      username: my-console-viewer-role
  mapUsers: |
    - groups:
      - system:masters
      userarn: arn:aws:iam::111122223333:user/admin
      username: admin
    - groups:
      - eks-console-dashboard-restricted-access-group      
      userarn: arn:aws:iam::444455556666:user/my-user
      username: my-user