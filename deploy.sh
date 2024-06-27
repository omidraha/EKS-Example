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

### Required network settings

```bash
VPC_CIDR="10.0.0.0/16"
```

### Required instance type

```bash
IMAGE_ID="ami-0854d447c9bdaed9a"
InstanceType="t2.micro"
DiskSize=20
AMIType="AL2_x86_64"
MinSize=1
MaxSize=1
DesiredSize=1
MAX_PODS="110"
```

### Define variable for resource name

#### Replace KeyName with your key pair name

```bash
KeyName="my-key"
CLUSTER_NAME="my-cluster"
NODE_ROLE_NAME="myAmazonEKSNodeRole"
INSTANCE_PROFILE_NAME="myAmazonEKSNodeInstanceProfile"
NODE_GROUP_NAME="my-node-group"
INSTANCE_NAME_PREFIX="my-instance"
TEMPLATE_NAME="my-eks-node-template"
ROLE_NAME="myAmazonEKSClusterRole"
CACHE_SUBNET_GROUP_NAME="my-cache-subnet-group"
CACHE_CLUSTER_ID="my-cache-cluster"
RDS_SECURITY_GROUP_NAME="my-rds-sg"
RDS_SUBNET_GROUP_NAME="my-rds-subnet-group"
RDS_INSTANCE_ID="my-rds-instance"
RDS_DB_NAME="mydatabase"
RDS_MASTER_USERNAME="username"
RDS_MASTER_PASSWORD="password"
```

### Define Domain Name

#### Replace with your domain name

MAIN_DOMAIN="sub.example.com"
SUBJECT_ALTERNATIVE_NAMES="*.$MAIN_DOMAIN"

### Create a VPC

```bash
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --query 'Vpc.VpcId' --output text)
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
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol -1 --port all --source-group $SG_ID --region $REGION

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

### Get kubeconfig

```bash
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
```

### Get cluster nodes and pods

```bash
 kubectl get nodes -o wide
 kubectl get pods -o wide
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

## Step 9: Create a Launch Template for the EKS Nodes

### Create a launch template for the EKS nodes

### Define required user data variables

```bash
CA_BUNDLE=$(aws eks describe-cluster --query "cluster.certificateAuthority.data" --output text --name $CLUSTER_NAME --region $REGION)
API_SERVER_ENDPOINT=$(aws eks describe-cluster --query "cluster.endpoint" --output text --name $CLUSTER_NAME --region $REGION)
DNS_CLUSTER_IP=$(aws eks describe-cluster --query "cluster.kubernetesNetworkConfig.serviceIpv4Cidr" --output text --name $CLUSTER_NAME --region $REGION | sed 's/0\/.*$/10/')
```

### Check retrieved values

```bash
echo "CA_BUNDLE: $CA_BUNDLE"
echo "API_SERVER_ENDPOINT: $API_SERVER_ENDPOINT"
echo "DNS_CLUSTER_IP: $DNS_CLUSTER_IP"
```
### Define User data script
```bash
USER_DATA=$(cat <<EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -ex
/etc/eks/bootstrap.sh $CLUSTER_NAME \
  --b64-cluster-ca $CA_BUNDLE \
  --apiserver-endpoint $API_SERVER_ENDPOINT \
  --dns-cluster-ip $DNS_CLUSTER_IP \
  --kubelet-extra-args '--max-pods=$MAX_PODS' \
  --use-max-pods false

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
# Install custom packages
yum update -y
yum install -y wget curl vim nmap
# Configure and restart kubelet
systemctl daemon-reload
systemctl restart containerd
systemctl restart kubelet

--==MYBOUNDARY==--
EOF
)
```

### Base64 encode user data
```bash
USER_DATA_BASE64=$(echo "$USER_DATA" | base64 | tr -d '\n')
```
### Create launch template
```bash
LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template --launch-template-name $TEMPLATE_NAME --version-description "EKS Node Template" --launch-template-data '{
  "ImageId": "'$IMAGE_ID'",
  "InstanceType": "'$InstanceType'",
  "KeyName": "'$KeyName'",
  "SecurityGroupIds": ["'$SG_ID'"],
  "UserData": "'$USER_DATA_BASE64'",
  "BlockDeviceMappings": [
    {
      "DeviceName": "/dev/xvda",
      "Ebs": {
        "VolumeSize": '$DiskSize',
        "VolumeType": "gp2"
      }
    }
  ],
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {
          "Key": "Name",
          "Value": "'$TEMPLATE_NAME'"
        }
      ]
    }
  ]
}' --region $REGION --query 'LaunchTemplate.LaunchTemplateId' --output text)
```

```bash
echo "Launch Template ID: $LAUNCH_TEMPLATE_ID"
```



## Step 10: Create Node Group
```bash
NODE_GROUP_ID=$(aws eks create-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NODE_GROUP_NAME \
  --node-role $NODE_ROLE_ARN \
  --subnets $PRIVATE_SUBNET_ID_1 $PRIVATE_SUBNET_ID_2 $PRIVATE_SUBNET_ID_3 \
  --scaling-config minSize=$MinSize,maxSize=$MaxSize,desiredSize=$DesiredSize \
  --launch-template id=$LAUNCH_TEMPLATE_ID,version=1 \
  --region $REGION \
  --query 'nodegroup.nodegroupArn' \
  --output text)
```

```bash
echo "Node Group ID: $NODE_GROUP_ID"
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

## Step 11: Update the EKS Cluster Configuration

### Update the EKS cluster configuration to use the new node group

```bash
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
```

## Step 12: Apply the AWS-auth ConfigMap to allow nodes to join the cluster

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

## Step 13: (Optional) Verify the Node Group

You can verify that the nodes are properly added to your EKS cluster by checking the nodes in your cluster:

```bash
kubectl get nodes
```

## Step 14: Create certificate

```bash
# Request the ACM Certificate and retrieve the Domain Validation Options
CERTIFICATE_ARN=$(aws acm request-certificate \
    --domain-name "$MAIN_DOMAIN" \
    --validation-method DNS \
    --subject-alternative-names "$SUBJECT_ALTERNATIVE_NAMES" \
    --query 'CertificateArn' --output text  --region $REGION)

echo "Requested certificate ARN: $CERTIFICATE_ARN"

# Retrieve the Domain Validation Options
VALIDATION_OPTIONS=$(aws acm describe-certificate --certificate-arn $CERTIFICATE_ARN \
    --query 'Certificate.DomainValidationOptions' --output json  --region $REGION)

# Extract Resource Record Name and Value
RESOURCE_RECORD_NAME=$(echo $VALIDATION_OPTIONS | jq -r '.[0].ResourceRecord.Name')
RESOURCE_RECORD_VALUE=$(echo $VALIDATION_OPTIONS | jq -r '.[0].ResourceRecord.Value')
RESOURCE_RECORD_TYPE=$(echo $VALIDATION_OPTIONS | jq -r '.[0].ResourceRecord.Type')


echo "Resource Record Type: $RESOURCE_RECORD_TYPE"
echo "Resource Record Name: $RESOURCE_RECORD_NAME"
echo "Resource Record Value: $RESOURCE_RECORD_VALUE"


echo "DNS validation record created. Waiting for validation..."

# Wait for domain validation to complete
while true; do
    STATUS=$(aws acm describe-certificate --certificate-arn $CERTIFICATE_ARN \
        --query 'Certificate.Status' --output text  --region $REGION)
    if [ "$STATUS" == "ISSUED" ]; then
        echo "Certificate issued successfully!"
        break
    else
        echo "Waiting for certificate to be issued. Current status: $STATUS"
        sleep 30
    fi
done
```

## Step 15: Create Security Group for ElastiCache

### Create a security group for ElastiCache

```bash
ECacheSecurityGroupName="my-elasti-cache-sg"
CACHE_SG_ID=$(aws ec2 create-security-group --group-name $ECacheSecurityGroupName --description "Security group for ElastiCache cluster" --vpc-id $VPC_ID --region $REGION --query 'GroupId' --output text)
aws ec2 create-tags --resources $CACHE_SG_ID --tags Key=Name,Value=my-elastic-cache-sg --region $REGION
```

### Authorize inbound rules for the ElastiCache security group to allow access from the EKS nodes

```bash
aws ec2 authorize-security-group-ingress --group-id $CACHE_SG_ID --protocol tcp --port 6379 --source-group $SG_ID --region $REGION
```

## Step 16: Create Cache Subnet Group

### Create a cache subnet group for ElastiCache

```bash
CACHE_SUBNET_GROUP_ID=$(aws elasticache create-cache-subnet-group \
  --cache-subnet-group-name $CACHE_SUBNET_GROUP_NAME \
  --cache-subnet-group-description "Subnet group for ElastiCache" \
  --subnet-ids $PRIVATE_SUBNET_ID_1 $PRIVATE_SUBNET_ID_2 $PRIVATE_SUBNET_ID_3 \
  --region $REGION \
  --query 'CacheSubnetGroup.CacheSubnetGroupName' --output text)
```

```bash
echo "Cache Subnet Group ID: $CACHE_SUBNET_GROUP_ID"
```


## Step 17: Create ElastiCache Cluster

### Create the ElastiCache cluster within the VPC

```bash
CACHE_CLUSTER_STATUS=$(aws elasticache create-cache-cluster \
  --cache-cluster-id $CACHE_CLUSTER_ID \
  --cache-node-type cache.t2.micro \
  --num-cache-nodes 1 \
  --engine redis \
  --cache-subnet-group-name $CACHE_SUBNET_GROUP_NAME \
  --security-group-ids $CACHE_SG_ID \
  --region $REGION \
  --query 'CacheCluster.CacheClusterId' --output text)
```

```bash
echo "Cache Cluster ID: $CACHE_CLUSTER_ID"
```

## Step 18: Create Security Group for RDS

### Create a security group for RDS

```bash

RDS_SG_ID=$(aws ec2 create-security-group --group-name $RDS_SECURITY_GROUP_NAME --description "Security group for RDS instance" --vpc-id $VPC_ID --region $REGION --query 'GroupId' --output text)
aws ec2 create-tags --resources $RDS_SG_ID --tags Key=Name,Value=my-rds-sg --region $REGION
```

### Authorize inbound rules for the RDS security group to allow access from the EKS nodes

```bash
aws ec2 authorize-security-group-ingress --group-id $RDS_SG_ID --protocol tcp --port 5432 --source-group $SG_ID --region $REGION
```
# Authorize outbound rules for the RDS security group

```bash
aws ec2 authorize-security-group-egress --group-id $RDS_SG_ID --protocol -1 --port all --cidr 0.0.0.0/0 --region $REGION
```

## Step 19: Create RDS Subnet Group

### Create a subnet group for RDS

```bash

RDS_SUBNET_GROUP_ID=$(aws rds create-db-subnet-group \
  --db-subnet-group-name $RDS_SUBNET_GROUP_NAME \
  --db-subnet-group-description "Subnet group for RDS" \
  --subnet-ids $PRIVATE_SUBNET_ID_1 $PRIVATE_SUBNET_ID_2 $PRIVATE_SUBNET_ID_3 \
  --region $REGION \
  --query 'DBSubnetGroup.DBSubnetGroupName' --output text)
```

### Output RDS subnet group ID

```bash
echo "RDS Subnet Group ID: $RDS_SUBNET_GROUP_ID"
```

## Step 20: Create RDS Instance

# Create the RDS instance within the VPC
```bash

RDS_INSTANCE_STATUS=$(aws rds create-db-instance \
  --db-instance-identifier $RDS_INSTANCE_ID \
  --db-instance-class "db.t3.micro" \
  --engine postgres \
  --allocated-storage 20 \
  --db-name $RDS_DB_NAME \
  --master-username $RDS_MASTER_USERNAME \
  --master-user-password $RDS_MASTER_PASSWORD \
  --vpc-security-group-ids $RDS_SG_ID \
  --db-subnet-group-name $RDS_SUBNET_GROUP_NAME \
  --engine-version "12.17" \
  --availability-zone $ZONE_A \
  --backup-retention-period 7 \
  --preferred-backup-window "07:00-07:30" --region $REGION \
  --query 'DBInstance.DBInstanceIdentifier' --output text)
```

### Output RDS instance ID

```bash
echo "RDS Instance ID: $RDS_INSTANCE_STATUS"
```

## Step 21: Wait for the RDS Instance to be Available

### Wait for the RDS instance to become available
```bash
aws rds wait db-instance-available --db-instance-identifier $RDS_INSTANCE_ID --region $REGION
```

### Get the endpoint of the RDS instance
```bash
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $RDS_INSTANCE_ID --region $REGION --query 'DBInstances[0].Endpoint.Address' --output text)
```

```bash
echo "RDS Endpoint: $RDS_ENDPOINT"
```
