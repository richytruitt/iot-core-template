

resource "tls_private_key" "device" {
  for_each  = toset(var.device_names)
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Per-device CSR
resource "tls_cert_request" "device" {
  for_each        = toset(var.device_names)
  private_key_pem = tls_private_key.device[each.key].private_key_pem

  subject {
    common_name = each.value
  }
}

# Sign it with your CA (the same key/cert from before)
resource "tls_locally_signed_cert" "device" {
  for_each              = toset(var.device_names)
  cert_request_pem      = tls_cert_request.device[each.key].cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760 # 1 year — this is what you'll rotate later

  allowed_uses = ["digital_signature", "key_encipherment", "client_auth"]
}

# Register the signed cert with IoT Core
resource "aws_iot_certificate" "device" {
  for_each        = toset(var.device_names)
  certificate_pem = tls_locally_signed_cert.device[each.key].cert_pem
  active          = true
}

# Create the Thing
resource "aws_iot_thing" "device" {
  for_each = toset(var.device_names)
  name     = each.value
}

# Attach cert to Thing
resource "aws_iot_thing_principal_attachment" "device" {
  for_each  = toset(var.device_names)
  principal = aws_iot_certificate.device[each.key].arn
  thing     = aws_iot_thing.device[each.key].name
}

# Attach the least-privilege policy from earlier
resource "aws_iot_policy_attachment" "device" {
  for_each  = toset(var.device_names)
  principal = aws_iot_certificate.device[each.key].arn
  policy    = aws_iot_policy.device_scoped[each.key].name
}