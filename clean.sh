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
