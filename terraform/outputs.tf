output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "vm_external_ip" {
  description = "External IP address of the OpenClaw VM"
  value       = google_compute_address.openclaw.address
}

output "gateway_url" {
  description = "URL to access the OpenClaw Gateway"
  value       = "http://${google_compute_address.openclaw.address}:18789"
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "gcloud compute ssh openclaw-vm --project=${var.project_id} --zone=${var.zone}"
}

output "vm_name" {
  description = "Name of the Compute Engine VM"
  value       = google_compute_instance.openclaw.name
}

output "service_account_email" {
  description = "Email of the VM service account"
  value       = google_service_account.openclaw.email
}
