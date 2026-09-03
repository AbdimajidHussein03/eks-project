resource "aws_security_group" "control_plane" {
  name        = "${var.cluster_name}-control-plane-sg"
  description = "Additional security group for EKS control plane communication"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.cluster_name}-control-plane-sg"
    Project     = "eks-project"
    Environment = "prod"
    Terraform   = "true"
  }
}

resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.cluster_name}-node-sg"
    Project     = "eks-project"
    Environment = "prod"
    Terraform   = "true"
  }
}

# Worker nodes -> Kubernetes API server
resource "aws_vpc_security_group_ingress_rule" "control_plane_from_nodes_443" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.nodes.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  description = "Allow worker nodes to reach Kubernetes API server"
}
# Wroker nodes to kubernetes API server is for the worker nodes to communicate with the Kubernetes API server  
# running in the EKS control plane. This is essential for the worker nodes to receive instructions from the control plane
#such as scheduling pods and reporting their status. 
# The API server listens on port 443, which is the standard port for HTTPS traffic, 
#ensuring secure communication between the worker nodes and the control plane.


# EKS control plane -> kubelet
resource "aws_vpc_security_group_ingress_rule" "nodes_from_control_plane_10250" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.control_plane.id

  from_port   = 10250
  to_port     = 10250
  ip_protocol = "tcp"

  description = "Allow EKS control plane to reach kubelet"
}

#This ingress rule allows the EKS control plane to communicate with the kubelet on the worker nodes. 
# The kubelet is responsible for managing the lifecycle of containers on each node, and the control plane needs to be able to reach it for tasks such as scheduling pods and monitoring node health.
#The kubelet runs on port 10250, and this rule ensures that the control plane can reach it for management and monitoring purposes. 

# Worker nodes -> control plane API
# This egress rule allows the worker nodes to initiate outbound connections to the EKS control plane's API server.
# The control plane's API server is responsible for managing the Kubernetes cluster
#The worker nodes need to communicate with it to receive instructions and report their status.
resource "aws_vpc_security_group_egress_rule" "nodes_to_control_plane_443" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.control_plane.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  description = "Allow worker nodes to reach Kubernetes API server"
}


# Control plane -> worker kubelet
# This egress rule allows the EKS control plane to initiate outbound connections to the kubelet running on the worker nodes.
# The kubelet is responsible for managing the lifecycle of containers on each node
#The control plane needs to be able to reach it for tasks such as scheduling pods and monitoring node health.

resource "aws_vpc_security_group_egress_rule" "control_plane_to_nodes_10250" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.nodes.id

  from_port   = 10250
  to_port     = 10250
  ip_protocol = "tcp"

  description = "Allow EKS control plane to reach kubelet"
}

# Node-to-node communication
# This ingress rule allows worker nodes to communicate with each other within the same security group.
# This is important for certain Kubernetes features that require inter-node communication, such as pod-to-pod networking and service discovery. 
# By allowing all traffic between nodes, it ensures that they can communicate freely for these purposes.

resource "aws_vpc_security_group_ingress_rule" "nodes_from_nodes" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.nodes.id

  ip_protocol = "-1"

  description = "Allow communication between EKS worker nodes"
}

# Nodes need outbound access for ECR, EKS APIs, package repositories, etc.
# Traffic leaves private subnets through the NAT Gateway.
# This egress rule allows the worker nodes to initiate outbound connections to the internet for various purposes
# such as pulling container images from Amazon ECR, accessing EKS APIs, and downloading packages from external repositories.

resource "aws_vpc_security_group_egress_rule" "nodes_outbound" {
  security_group_id = aws_security_group.nodes.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Allow worker node outbound traffic through NAT Gateway"
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_control_plane_8443" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.control_plane.id

  ip_protocol = "tcp"
  from_port   = 8443
  to_port     = 8443

  description = "Allow EKS control plane to reach NGINX admission webhook"
}
