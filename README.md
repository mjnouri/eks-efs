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

    steps:
1. on wsl, aws cli v2 and auth using mark, tf, kubectl, eksctl, helm
2. spin up tf
3*. create OIDC provider
4. aws iam create-policy --policy-name EFSCSIControllerIAMPolicy --policy-document file://iam-policy.json
5*. eksctl create iamserviceaccount --cluster=eks1 --region us-east-1 --namespace=kube-system --name=efs-csi-controller-sa --override-existing-serviceaccounts --attach-policy-arn=arn:aws:iam::765981046280:policy/EFSCSIControllerIAMPolicy --approve
6. helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver
7. helm repo update
8*. helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver --namespace kube-system --set image.repository=602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/aws-efs-csi-driver --set controller.serviceAccount.create=false --set controller.serviceAccount.name=efs-csi-controller-sa
# or install efs CSI driver with kustomize
kubectl kustomize "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.2" > driver.yaml
vim driver.yaml # delete the service account created in step 1.
kubectl apply -f driver.yaml
9*. copy efs id and place in storageClass.yml
10. k apply -f storageClass.yml
11. k apply -f persistentVolumeClaim.yml
12. k get pvc efs-claim - make sure pvc is in bound state (this requires oidc and its thumbprint)
13. k apply -f deployment.yml
14. watch kubectl get all

    cleanup:
1. terraform destroy -auto-approve
2. delete iam policy EFSCSIControllerIAMPolicy
2. delete oidc
3. delete cloudformation from eksctl

    automation:
3. oidc provider needs thumbprint. how do you get thumbprint via tf? python?
5. this makes an iam role with trusted entity policy, and k8s serviceaccount
8. deploy all this helm with vanilla k8s yml
9. get tf output of efs id, place in storageClass.yml (refer to previous project on how this is done)

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

