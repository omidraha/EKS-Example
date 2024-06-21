### ReadMe.md

## Purpose

This script automates the creation of an Amazon EKS cluster that is distributed across three availability zones. 

The cluster is designed to be accessible for internet downloads while not being directly accessible from the internet.

## Steps Overview

1. **Create VPC and Subnets**:
   - Define the region and availability zones.
   - Create a VPC and private subnets in three availability zones.
   - Create a public subnet for the NAT Gateway.

2. **Create and Attach Internet Gateway**:
   - Create an Internet Gateway.
   - Attach the Internet Gateway to the VPC.

3. **Create NAT Gateway**:
   - Allocate an Elastic IP.
   - Create a NAT Gateway in the public subnet.

4. **Create Route Tables and Routes**:
   - Create a private route table and associate it with the private subnets.
   - Create a public route table and associate it with the public subnet.

5. **Create IAM Role for EKS**:
   - Create an IAM role with a trust relationship for EKS.
   - Attach the AmazonEKSClusterPolicy managed policy.

6. **Create Security Group for EKS**:
   - Create a security group and authorize necessary inbound and outbound rules.

7. **Create EKS Cluster**:
   - Create the EKS cluster with the defined subnets and security group.

8. **Create IAM Role for EKS Nodes**:
   - Create an IAM role for the EKS nodes with necessary policies.
   - Create an instance profile and add the role to it.

9. **Create Launch Template for EKS Nodes**:
   - Create a launch template specifying the AMI, instance type, key pair, and security group.

10. **Create Node Group**:
    - Create a node group using the launch template and associate it with the cluster.

11. **Update EKS Cluster Configuration**:
    - Update the kubeconfig file to use the new node group.

12. **Apply AWS-auth ConfigMap**:
    - Apply the AWS-auth ConfigMap to allow nodes to join the cluster.

13. **Verify the Node Group (Optional)**:
    - Verify that the nodes are properly added to the EKS cluster by checking the nodes in your cluster.