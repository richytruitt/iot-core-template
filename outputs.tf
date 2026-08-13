output "device_certificates" {
  value = module.register_things.device_credentials
  sensitive = true
}

output "root_ca_certificate" {
    value = module.custom_root_ca.root_ca_certificate
    sensitive = true
}