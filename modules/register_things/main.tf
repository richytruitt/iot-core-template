

resource "tls_private_key" "device" {
  for_each  = local.devices_by_name
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "device" {
  for_each        = local.devices_by_name
  private_key_pem = tls_private_key.device[each.key].private_key_pem

  subject {
    common_name = each.value.name
  }
}

# Sign it with your CA (the same key/cert from before)
resource "tls_locally_signed_cert" "device" {
  for_each = local.devices_by_name

  cert_request_pem   = tls_cert_request.device[each.key].cert_request_pem
  ca_private_key_pem = var.root_ca_private_key
  ca_cert_pem        = var.root_ca_certificate

  validity_period_hours = 8760

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth"
  ]
}

# Register the signed cert with IoT Core
resource "aws_iot_certificate" "device" {
  for_each        = local.devices_by_name
  certificate_pem = tls_locally_signed_cert.device[each.key].cert_pem
  active          = true
}

# Create the Thing
resource "aws_iot_thing" "device" {
  for_each = local.devices_by_name
  name     = each.value.name
}

# Attach cert to Thing
resource "aws_iot_thing_principal_attachment" "device" {
  for_each  = local.devices_by_name
  principal = aws_iot_certificate.device[each.key].arn
  thing     = aws_iot_thing.device[each.key].name
}

# Attach the least-privilege policy from earlier
resource "aws_iot_policy_attachment" "device" {
  for_each = local.devices_by_name

  policy = aws_iot_policy.device_scoped[each.key].name
  target = aws_iot_certificate.device[each.key].arn
}

resource "aws_iot_policy" "device_scoped" {
  for_each = local.devices_by_name
  name     =  "policy-${each.value.name}"
  policy   = data.aws_iam_policy_document.scoped[each.key].json
}