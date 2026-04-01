output "grafana_url" {
  description = "Grafana URL (port 3000) on the monitor host"
  value       = "http://${aws_instance.monitor.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL (port 9090) on the monitor host"
  value       = "http://${aws_instance.monitor.public_ip}:9090"
}

output "monitor_public_ip" {
  description = "Public IP of the monitor host"
  value       = aws_instance.monitor.public_ip
}

output "monitor_private_ip" {
  description = "Private IP of the monitor host"
  value       = aws_instance.monitor.private_ip
}

output "target_private_ip" {
  description = "Private IP of the target host"
  value       = aws_instance.target.private_ip
}

output "ssh_monitor_command" {
  description = "SSH command for the monitor host (requires key_name + matching private key)"
  value       = "ssh ubuntu@${aws_instance.monitor.public_ip}"
}

output "ssh_target_via_monitor_command" {
  description = "SSH command to reach the private target through the monitor host (OpenSSH ProxyJump)"
  value       = "ssh -J ubuntu@${aws_instance.monitor.public_ip} ubuntu@${aws_instance.target.private_ip}"
}

output "destroy_hint" {
  description = "Cleanup reminder"
  value       = "When finished: terraform destroy (use the same -var values you used for apply)."
}
