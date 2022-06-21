# eks-efs
Deploy a sample containerized app using EFS storage to EKS

    determine audience:
- technical people wanting to see how this is done (code snippets)
- manager/exec level who can follow the overarcing concepts (each concept needs a non-technical, plain english explaination)

    not in scope(control scope creep):
- made cluster with work-windows, which is why iam:mark doesn't have access. (not in scope, but get this working, https://docs.aws.amazon.com/eks/latest/userguide/view-kubernetes-resources.html#view-kubernetes-resources-permissions)
- terraform modules. (not going to use them, since the focus is eks/efs/iam)
- explaining terraform and k8s concepts in great detail
- no pipeline to launch this (jenkins, gitlab, github actions), going to just run it locally
- helm

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
- variable out things like env, eks worker node instance type, etc?
- test mount points util on wordpress image, or find another image that has what you need, or make one(scope creep)!
- check each EKS cluster and pod policy to see if you need it
- find better way to authenticate to the cluster
- optionally, enable Security Groups for Pods. in scope? would be good to talk about opening EFS port in SG used by pods (https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html)
- add s3 backend
- diagram of everything resource and connection
- restrict efs access policy
- efs should be One Zone storage class
- find better way to listing 3 subnets
- do the whole thing without the efa access policy to see if it allows all
- replace efs line 51 with IAM role on EKS worker nodes
- go through each tf resource and add optional arguments, retest
- remove root access and use posix user in efs mount access?
- show mount command from k describe pod that is run in containers
- since eksctl is out, try renaming the eks cluster to include "_"
- eksctl documentation: If you used instance roles, and are considering to use IRSA instead, you shouldn't mix the two.
- add cleanup steps - delete deployment, service, then tf destroy
- deploy sc and run waiter to make sure it's good
- deploy pvc and run waiter to make sure it's bound, then deploy the deployment
- add that you got efs csi config files with kubectl kustomize "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.2"

    steps:
- aws cli and auth, tf, kubectl, eksctl
- spin up tf-infra (vpc, efs, eks)
- AWSACCOUNTNUMBER=$(aws sts get-caller-identity --query Account --output text)
- eksctl create iamserviceaccount --cluster=eks1 --region us-east-1 --namespace=kube-system --name=efs-csi-controller-sa --override-existing-serviceaccounts --attach-policy-arn=arn:aws:iam::$AWSACCOUNTNUMBER:policy/EFSCSIControllerIAMPolicy --approve
    This creates an IAM role and attaches a TF-made IAM policy, and a k8s ServiceAccount, both reference each other
- cd ../k8s
- spin up tf-k8s (efs_cs_driver, ..., sc, pvc, deployment)

    cleanup:
1. cd k8s -> terraform destroy -auto-approve
2. destroy eksctl cloudformation role
3. cd terraform -> terraform destroy -auto-approve

    automation:
3. this makes an iam role with trusted entity policy, and k8s serviceaccount

    automation notes:
5.
    aws iam role:
name                eksctl-eks1-addon-iamserviceaccount-kube-sys-Role1-128WXYDV011BM
policy attached     EFSCSIControllerIAMPolicy
trust policy        ...
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::765981046280:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/C3DD7659EDACE01DBB8BBF96E953C97F"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.us-east-1.amazonaws.com/id/C3DD7659EDACE01DBB8BBF96E953C97F:sub": "system:serviceaccount:kube-system:efs-csi-controller-sa",
                    "oidc.eks.us-east-1.amazonaws.com/id/C3DD7659EDACE01DBB8BBF96E953C97F:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}

    eks sa:
name                efs-csi-controller-sa
yaml                ...
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::765981046280:role/eksctl-eks1-addon-iamserviceaccount-kube-sys-Role1-128WXYDV011BM
  creationTimestamp: "2022-06-08T17:04:41Z"
  labels:
    app.kubernetes.io/managed-by: eksctl
  name: efs-csi-controller-sa
  namespace: kube-system
  resourceVersion: "17003"
  uid: 52fbc43a-6225-4197-ad42-7010f963e50f
secrets:
- name: efs-csi-controller-sa-token-gnzzk

---

to add other IAM users access to cluster
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