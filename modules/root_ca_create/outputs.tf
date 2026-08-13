output "root_ca_certificate" {
  value = tls_self_signed_cert.ca.cert_pem
  sensitive = true
}

output "root_ca_private_key" {
  value     = tls_private_key.ca.private_key_pem
  sensitive = true
}