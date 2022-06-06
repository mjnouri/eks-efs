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

    refresh:
storageClass
presistentVolume
persistentVolumeClaim

    steps to launch infra:
terraform apply
# confirm eks cluster and nodes
k cluster-info
k get nodes
# at this point, check sc, pv, pvc, sa, sa -n kube-system
kubectl get csidrivers.storage.k8s.io -oyaml
# this works
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.3"
aws efs describe-file-systems --query "FileSystems[*].FileSystemId"
# in storageClass.yml, replace fileSystemId with actual efs id, possibly with sed -i "s/efs_id/$FILE_SYSTEM_ID/g" efs-pvc.yaml
kubectl apply -f .\storageClass.yml
kubectl get sc
kubectl get pv
kubectl apply -f persistentVolumeClaim.yml
# make sure it says bound
kubectl apply -f wordpressDeployment.yml

    directions:
on wsl
aws cli v2 and auth using mark, tf, kubectl, eksctl, helm
spin up all tf
create OIDC provider, make with tf
k cluster-info
k get nodes

# if using eksctl, this command can't have eks cluster name with "_" in it. check eks cluster name
eksctl create iamserviceaccount --cluster=eks1 --region us-east-1 --namespace=kube-system --name=efs-csi-controller-sa --override-existing-serviceaccounts --attach-policy-arn=arn:aws:iam::765981046280:policy/EFSCSIControllerIAMPolicy --approve
# this created an IAM role=eksctl-eks1-addon-iamserviceaccount-kube-sys-Role1-13GNKI5VSF2BC
# this also created k8s sa efs-csi-controller-sa in namespace kube-system
investigate: eksctl step that creates role (and its trust entities), serviceaccount -n kube-system, and everything in it's cf stack

# install efs CSI drivers using this way...
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver
helm repo update
# using us-east-1 ecr repo
helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver --namespace kube-system --set image.repository=602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/aws-efs-csi-driver --set controller.serviceAccount.create=false --set controller.serviceAccount.name=efs-csi-controller-sa
# error - only 1 repica is spinning up

# or install efs CSI driver this way
kubectl kustomize "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.2" > driver.yaml
vim driver.yaml # delete the service account created in step 1.
kubectl apply -f driver.yaml

# copy efs id and place in storageClass.yml
k apply -f storageClass.yml
k apply -f persistenVolumeClaim.yml
k apply -f pod.yml
# error using helm method - Events:
  Type     Reason       Age                From               Message
  ----     ------       ----               ----               -------
  Normal   Scheduled    85s                default-scheduler  Successfully assigned default/efs-example to ip-10-0-2-155.ec2.internal
  Warning  FailedMount  12s (x8 over 78s)  kubelet            MountVolume.SetUp failed for volume "pvc-f5d94e11-d7b1-44ff-941e-ceed43f6e711" : rpc error: code = Internal desc = Could not mount "fs-0de7611513f6ba12b:/" at "/var/lib/kubelet/pods/220b92bb-ebb2-4a50-9fb5-15cbd3664309/volumes/kubernetes.io~csi/pvc-f5d94e11-d7b1-44ff-941e-ceed43f6e711/mount": mount failed: exit status 32
Mounting command: mount
Mounting arguments: -t efs -o accesspoint=fsap-092744c2129f9680a,tls fs-0de7611513f6ba12b:/ /var/lib/kubelet/pods/220b92bb-ebb2-4a50-9fb5-15cbd3664309/volumes/kubernetes.io~csi/pvc-f5d94e11-d7b1-44ff-941e-ceed43f6e711/mount
Output: Could not start amazon-efs-mount-watchdog, unrecognized init system "aws-efs-csi-dri"
b'mount.nfs4: access denied by server while mounting 127.0.0.1:/'



automate these steps
1. create IAM OIDC
2. create a role, attach the EFSCSIControllerIAMPolicy policy, add this trust policy
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::765981046280:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/F1B74DD940139CBCD19566DB08A94255"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.us-east-1.amazonaws.com/id/F1B74DD940139CBCD19566DB08A94255:sub": "system:serviceaccount:kube-system:efs-csi-controller-sa",
                    "oidc.eks.us-east-1.amazonaws.com/id/F1B74DD940139CBCD19566DB08A94255:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}