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
    - Define and create a launch template for the EKS nodes with necessary configurations and user data.

10. **Create Node Group**:
    - Create a node group using the launch template and associate it with the cluster.

11. **Update EKS Cluster Configuration**:
    - Update the kubeconfig file to use the new node group.

12. **Apply AWS-auth ConfigMap**:
    - Apply the AWS-auth ConfigMap to allow nodes to join the cluster.

13. **Verify the Node Group (Optional)**:
    - Verify that the nodes are properly added to the EKS cluster by checking the nodes in your cluster.

14. **Create ACM Certificate**:
   - Request an ACM certificate for the domain and configure DNS validation.

16. **Create Security Group for ElastiCache**:
    - Create a security group for ElastiCache and authorize necessary inbound rules.
    
17. **Create ElastiCache Subnet Group**:
    - Create a cache subnet group for ElastiCache.

18. **Create ElastiCache Cluster**:
    - Create the ElastiCache cluster within the VPC.

19. **Create Security Group for RDS**:
    - Create a security group for RDS and authorize necessary inbound and outbound rules.

20. **Create RDS Subnet Group**:
    - Create a subnet group for RDS.

21. **Create RDS Instance**:
    - Create the RDS instance within the VPC.

22. **Wait for RDS Instance to be Available**:
    - Wait for the RDS instance to become available and get its endpoint.


### Notes

```bash
sudo amazon-linux-extras install epel -y
sudo yum install -y redis
```

### Links

https://docs.aws.amazon.com/code-library/latest/ug/eks_example_eks_CreateNodegroup_section.html

https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html#worker-node-fail

https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html#instances-failed-to-join

https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html

https://docs.aws.amazon.com/cli/latest/reference/eks/create-cluster.html
