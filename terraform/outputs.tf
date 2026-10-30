output "manager_public_ip" {
  description = "Elastic IP of the swarm manager (use in the Jenkinsfile and for the live URL)."
  value       = aws_eip.manager.public_ip
}

output "worker_public_ips" {
  value = aws_instance.worker[*].public_ip
}

output "app_url" {
  description = "Public URL of the nginx load balancer."
  value       = "http://${aws_eip.manager.public_ip}"
}

output "ssh_manager" {
  value = "ssh -i ${var.private_key_path} ubuntu@${aws_eip.manager.public_ip}"
}

output "ami_id" {
  description = "AMI resolved by the data source."
  value       = data.aws_ami.ubuntu.id
}
