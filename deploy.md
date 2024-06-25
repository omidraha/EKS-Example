## Step 1: Create VPC and Subnets

### Replace with your region

```bash
REGION="us-east-2"
```

### Replace with your zone

```bash
ZONE_A="us-east-2a"
ZONE_B="us-east-2b"
ZONE_C="us-east-2c"
```

### Required instance type

```bash
InstanceType="t2.micro"
DiskSize=20
AMIType="AL2_x86_64"
MinSize=1
MaxSize=2
DesiredSize=2
```

### Replace with your key pair name

```bash
KeyName="my-key"
CLUSTER_NAME="my-cluster"
NODE_ROLE_NAME="myAmazonEKSNodeRole"
INSTANCE_PROFILE_NAME="myAmazonEKSNodeInstanceProfile"
NODE_GROUP_NAME="my-node-group"
INSTANCE_NAME_PREFIX="my-instance"
```

### Set resource names

ROLE_NAME="myAmazonEKSClusterRole"

### Create a VPC

```bash
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $REGION --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=my-vpc --region $REGION
```

### Create Private Subnets in Three Availability Zones

```bash
PRIVATE_SUBNET_ID_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --region $REGION --availability-zone $ZONE_A --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PRIVATE_SUBNET_ID_1 --tags Key=Name,Value=my-private-subnet-1 --region $REGION

PRIVATE_SUBNET_ID_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --region $REGION --availability-zone $ZONE_B --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PRIVATE_SUBNET_ID_2 --tags Key=Name,Value=my-private-subnet-2 --region $REGION

PRIVATE_SUBNET_ID_3=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --region $REGION --availability-zone $ZONE_C --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PRIVATE_SUBNET_ID_3 --tags Key=Name,Value=my-private-subnet-3 --region $REGION
```

### Create a Public Subnet for the NAT Gateway

```bash
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24  --region $REGION --availability-zone $ZONE_A --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PUBLIC_SUBNET_ID --tags Key=Name,Value=my-public-subnet --region $REGION
```

## Step 2: Create and Attach Internet Gateway

### Create the Internet Gateway

```bash
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=my-internet-gateway --region $REGION
```

### Attach the Internet Gateway to the VPC

```bash
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION
```

## Step 3: Create NAT Gateway

### Allocate an Elastic IP for the NAT Gateway

```bash
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --region $REGION --query 'AllocationId' --output text)
aws ec2 create-tags --resources $EIP_ALLOC_ID --tags Key=Name,Value=my-eip --region $REGION
```

### Create the NAT Gateway in the Public Subnet

```bash
NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_ID --allocation-id $EIP_ALLOC_ID --region $REGION --query 'NatGateway.NatGatewayId' --output text)
aws ec2 create-tags --resources $NAT_GW_ID --tags Key=Name,Value=my-nat-gateway --region $REGION
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID --region $REGION
```

## Step 4: Create Route Tables and Routes

### Create a Private Route Table

```bash
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $PRIVATE_ROUTE_TABLE_ID --tags Key=Name,Value=my-private-route-table --region $REGION
```

### Create a Route to the NAT Gateway

```bash
aws ec2 create-route --route-table-id $PRIVATE_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID --region $REGION
```

### Associate the Private Route Table with the Private Subnets

```bash
aws ec2 associate-route-table --route-table-id $PRIVATE_ROUTE_TABLE_ID --subnet-id $PRIVATE_SUBNET_ID_1 --region $REGION
aws ec2 associate-route-table --route-table-id $PRIVATE_ROUTE_TABLE_ID --subnet-id $PRIVATE_SUBNET_ID_2 --region $REGION
aws ec2 associate-route-table --route-table-id $PRIVATE_ROUTE_TABLE_ID --subnet-id $PRIVATE_SUBNET_ID_3 --region $REGION
```

### Create a Public Route Table

```bash
PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $PUBLIC_ROUTE_TABLE_ID --tags Key=Name,Value=my-public-route-table --region $REGION
```

### Create a Route to the Internet Gateway in the Public Route Table

```bash
aws ec2 create-route --route-table-id $PUBLIC_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
```

### Associate the Public Route Table with the Public Subnet

```bash
aws ec2 associate-route-table --route-table-id $PUBLIC_ROUTE_TABLE_ID --subnet-id $PUBLIC_SUBNET_ID --region $REGION
```

## Step 5: Create IAM Role for EKS

### Create a trust relationship policy document for EKS

```bash
cat <<EOF > eks-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

### Create the IAM role

```bash
ROLE_ARN=$(aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://eks-trust-policy.json  --region $REGION --query 'Role.Arn' --output text) 
```

### Attach the AmazonEKSClusterPolicy managed policy to the role

```bash
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

## Step 6: Create Security Group for EKS

### Create a security group

```bash
SG_ID=$(aws ec2 create-security-group --group-name my-eks-sg --description "Security group for EKS cluster" --vpc-id $VPC_ID --region $REGION --query 'GroupId' --output text)
aws ec2 create-tags --resources $SG_ID --tags Key=Name,Value=my-eks-sg --region $REGION
```

### Authorize inbound rules for the security group

```bash
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol all --port all --source-group $SG_ID --region $REGION
aws ec2 authorize-security-group-egress --group-id $SG_ID --protocol -1 --port all --cidr 0.0.0.0/0 --region $REGION
```

### Authorize Outbound rules for the security group

```bash
aws ec2 authorize-security-group-egress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-egress --group-id $SG_ID --protocol tcp --port 10250 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-egress --group-id $SG_ID --protocol tcp --port 53 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-egress --group-id $SG_ID --protocol udp --port 53 --cidr 0.0.0.0/0 --region $REGION
```

## Step 7: Create EKS Cluster

### Create the EKS cluster

```bash

CLUSTER_ARN=$(aws eks create-cluster \
  --region $REGION \
  --name $CLUSTER_NAME \
  --kubernetes-version 1.30 \
  --role-arn $ROLE_ARN \
  --resources-vpc-config subnetIds=$PRIVATE_SUBNET_ID_1,$PRIVATE_SUBNET_ID_2,$PRIVATE_SUBNET_ID_3,securityGroupIds=$SG_ID \
  --query 'cluster.arn' \
  --output text)
```

## Step 8: Create an IAM Role for the EKS Nodes

### Create a trust relationship policy document for EKS Nodes

```bash
cat <<EOF > eks-node-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

### Create the IAM role

```bash
NODE_ROLE_ARN=$(aws iam create-role --role-name $NODE_ROLE_NAME --assume-role-policy-document file://eks-node-trust-policy.json --region $REGION --query 'Role.Arn' --output text)
```

### Attach managed policies to the role

```bash
aws iam attach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

### Create the Instance Profile and add the role to it

```bash
INSTANCE_PROFILE_ARN=$(aws iam create-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --query 'InstanceProfile.Arn' --output text)
aws iam add-role-to-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --role-name $NODE_ROLE_NAME
```

## Step 9: Create Node Group

```bash
aws eks create-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NODE_GROUP_NAME \
  --node-role $NODE_ROLE_ARN \
  --subnets $PRIVATE_SUBNET_ID_1 $PRIVATE_SUBNET_ID_2 $PRIVATE_SUBNET_ID_3 \
  --scaling-config minSize=$MinSize,maxSize=$MaxSize,desiredSize=$DesiredSize \
  --instance-types $InstanceType --disk-size $DiskSize --ami-type $AMIType --region $REGION 
```

### Add tag to created instances of node group

```bash
INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=tag:eks:nodegroup-name,Values=$NODE_GROUP_NAME"  --region $REGION   --query "Reservations[*].Instances[*].InstanceId" --output text)
COUNTER=1
for INSTANCE_ID in $INSTANCE_IDS; do
  INSTANCE_NAME="${NODE_GROUP_NAME}-${INSTANCE_NAME_PREFIX}-${COUNTER}"
  echo "Tagging instance $INSTANCE_ID with Name=$INSTANCE_NAME"
  aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=$INSTANCE_NAME --region $REGION
  COUNTER=$((COUNTER+1))
done
```

## Step 10: Update the EKS Cluster Configuration

### Update the EKS cluster configuration to use the new node group

```bash
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
```

## Step 11: Apply the AWS-auth ConfigMap to allow nodes to join the cluster

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: $NODE_ROLE_ARN
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF
```

## Step 12: (Optional) Verify the Node Group

You can verify that the nodes are properly added to your EKS cluster by checking the nodes in your cluster:

```bash
kubectl get nodes
```

## Delete created resources

### Delete node group

```bash
aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODE_GROUP_NAME --region $REGION
aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODE_GROUP_NAME --region $REGION
```

### Delete cluster

```bash
aws eks delete-cluster --name $CLUSTER_NAME --region $REGION
```

### Delete IAM Role Policy

```bash
aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy --region $REGION
aws iam detach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy --region $REGION
aws iam detach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy --region $REGION
aws iam detach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly --region $REGION
aws iam remove-role-from-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --role-name $NODE_ROLE_NAME --region $REGION
aws iam delete-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --region $REGION
aws iam delete-role --role-name $ROLE_NAME --region $REGION
aws iam delete-role --role-name $NODE_ROLE_NAME --region $REGION
```

### Delete launch template

```bash
aws ec2 delete-launch-template --launch-template-id $LAUNCH_TEMPLATE_ID --region $REGION
```

### Delete network interface

```bash
aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SG_ID" --region $REGION --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text

ENIs=$(aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SG_ID" --region $REGION --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text)

for ENI in $ENIs; do
  ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI --region $REGION --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text)
  if [ "$ATTACHMENT_ID" != "null" ]; then
    aws ec2 detach-network-interface --attachment-id $ATTACHMENT_ID --region $REGION
  fi
  aws ec2 delete-network-interface --network-interface-id $ENI --region $REGION
done
```

### Release EIP

```bash
aws ec2 release-address --allocation-id $EIP_ALLOC_ID --region $REGION
```

### Delete NAT Gateway

```bash
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region $REGION
aws ec2 wait nat-gateway-deleted --nat-gateway-id $NAT_GW_ID --region $REGION
```

### Delete Security Group

```bash
aws ec2 delete-security-group --group-id $SG_ID --region $REGION
```

### Delete Internet GateWay

```bash
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION
```

### Delete Subnet

```bash
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_ID_1 --region $REGION
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_ID_2 --region $REGION
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_ID_3 --region $REGION
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_ID --region $REGION
```
### Delete Route table

```bash
aws ec2 delete-route-table --route-table-id $PRIVATE_ROUTE_TABLE_ID --region $REGION
aws ec2 delete-route-table --route-table-id $PUBLIC_ROUTE_TABLE_ID --region $REGION
```
### Delete VPC

```bash
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION
```
