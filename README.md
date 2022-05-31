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
- replace efs line 52 with IAM role on EKS worker nodes

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
# this work with a warning
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.0"
# so try this (no errors)
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
kubectl apply -f .\storageClass.yml
kubectl get sc
aws efs describe-file-systems --query "FileSystems[*].FileSystemId"
# in persistentVolume.yml, replace volumeHandle with actual efs id, possibly with sed -i "s/efs_id/$FILE_SYSTEM_ID/g" efs-pvc.yaml
kubectl apply -f .\persistentVolume.yml
# make sure it says bound
kubectl get pvc

sc -> pvc -> pod

