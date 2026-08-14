resource "terraform_data" "credential_directories" {
  for_each = local.devices_by_name

  provisioner "local-exec" {
    command = "mkdir -p '${path.root}/credentials/${each.value.name}'"
  }
}

resource "local_sensitive_file" "device_private_key" {
  for_each = local.devices_by_name

  filename = "${path.root}/credentials/${each.value.name}/device.key"
  content  = tls_private_key.device[each.key].private_key_pem

  depends_on = [
    terraform_data.credential_directories
  ]
}

resource "local_sensitive_file" "device_certificate" {
  for_each = local.devices_by_name

  filename = "${path.root}/credentials/${each.value.name}/device.crt"
  content  = tls_locally_signed_cert.device[each.key].cert_pem

  depends_on = [
    terraform_data.credential_directories
  ]
}

resource "terraform_data" "device_certificate_der" {
  for_each = local.devices_by_name

  triggers_replace = {
    cert_pem = tls_locally_signed_cert.device[each.key].cert_pem
  }

  provisioner "local-exec" {
    command = "openssl x509 -in '${local_sensitive_file.device_certificate[each.key].filename}' -outform DER -out '${path.root}/credentials/${each.value.name}/device.der'"
  }

  depends_on = [local_sensitive_file.device_certificate]
}

resource "terraform_data" "device_key_der" {
  for_each = local.devices_by_name

  triggers_replace = {
    key_pem = tls_private_key.device[each.key].private_key_pem
  }

  provisioner "local-exec" {
    command = "openssl pkcs8 -topk8 -inform PEM -outform DER -nocrypt -in '${local_sensitive_file.device_private_key[each.key].filename}' -out '${path.root}/credentials/${each.value.name}/device-pkcs8.der'"
  }

  depends_on = [local_sensitive_file.device_private_key]
}

resource "local_sensitive_file" "amazon_root_ca_der" {
  for_each = local.devices_by_name

  filename = "${path.root}/credentials/${each.value.name}/AmazonRootCA1.der"

  content_base64 = filebase64(
    "${path.root}/certificates/AmazonRootCA1.der"
  )

  depends_on = [
    terraform_data.credential_directories
  ]
}

resource "local_sensitive_file" "amazon_root_ca_pem" {
  for_each = local.devices_by_name

  filename = "${path.root}/credentials/${each.value.name}/AmazonRootCA1.pem"

  content_base64 = filebase64(
    "${path.root}/certificates/AmazonRootCA1.pem"
  )

  depends_on = [
    terraform_data.credential_directories
  ]
}