output "control_plane_security_group_id" {
  description = "Security group ID for the EKS control plane"
  value       = aws_security_group.control_plane.id
}

output "node_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.nodes.id
}