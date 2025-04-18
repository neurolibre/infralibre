output "install_script_path" {
    description = "Path to the generated install-binderhub-and-monitoring.sh script."
    value       = local_file.install_binderhub_and_monitoring.filename
}

output "allow_pod_pockets_script_path" {
    description = "Path to the generated allow-pod-pockets.sh script."
    value       = local_file.allow_pod_pockets.filename
}

output "deploy_kubernetes_script_filename" {
    description = "The path to the generated deploy_kubernetes.sh script."
    value       = local_file.deploy_kubernetes.filename
}

output "configure_kubectl_script_filename" {
    description = "The path to the generated configure-kubectl.sh script."
    value       = local_file.configure_kubectl.filename
}