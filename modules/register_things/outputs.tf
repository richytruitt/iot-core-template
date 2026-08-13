output "device_credentials" {
  value = {
    for name, device in local.devices_by_name : name => {
      private_key = tls_private_key.device[name].private_key_pem
      certificate = tls_locally_signed_cert.device[name].cert_pem
    }
  }

  sensitive = true
}