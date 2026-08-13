output "device_private_keys" {
  value     = { for k, v in tls_private_key.device : k => v.private_key_pem }
  sensitive = true
}

output "device_certificates" {
  value = { for k, v in tls_locally_signed_cert.device : k => v.cert_pem }
}