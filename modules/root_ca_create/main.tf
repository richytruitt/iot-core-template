resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 87600

  subject {
    common_name  = var.common_name
    organization = var.organization
  }

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}

resource "tls_private_key" "verification" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "verification" {
  private_key_pem = tls_private_key.verification.private_key_pem

  subject {
    common_name = data.aws_iot_registration_code.this.registration_code
  }
}

resource "tls_locally_signed_cert" "verification" {
  cert_request_pem   = tls_cert_request.verification.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 24
  allowed_uses          = ["digital_signature", "key_encipherment"]
}

resource "aws_iot_ca_certificate" "fleet_root" {
  active                       = true
  ca_certificate_pem           = tls_self_signed_cert.ca.cert_pem
  verification_certificate_pem = tls_locally_signed_cert.verification.cert_pem
  allow_auto_registration      = true
}