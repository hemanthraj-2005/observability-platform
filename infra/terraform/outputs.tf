output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.observability.id
}

output "public_ip" {
  description = "Public IP address of the observability host."
  value       = aws_instance.observability.public_ip
}

output "ssh_command" {
  description = "Example SSH command."
  value       = "ssh ubuntu@${aws_instance.observability.public_ip}"
}

output "grafana_url" {
  description = "Grafana URL."
  value       = "http://${aws_instance.observability.public_ip}:3005"
}

output "prometheus_url" {
  description = "Prometheus URL."
  value       = "http://${aws_instance.observability.public_ip}:9090"
}

output "flask_app_url" {
  description = "Flask application URL."
  value       = "http://${aws_instance.observability.public_ip}:5001"
}
