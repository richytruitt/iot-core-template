# AWS IoT Core Custom CA Device Provisioning

Terraform-based infrastructure for securely provisioning devices into **AWS IoT Core** using a **custom Root Certificate Authority (CA)**.

This project allows you to define your devices in a single `devices.json` file. Terraform then:

- Creates a custom Root CA
- Generates a unique private key and X.509 certificate for each device
- Signs each device certificate with the custom Root CA
- Registers the CA and device certificates with AWS IoT Core
- Creates an AWS IoT Thing for each device
- Creates a dedicated least-privilege IoT policy for each device
- Restricts each device to its own MQTT topic namespace
- Produces the certificate and key material required by each device

The result is a device provisioning workflow where **device identity, certificates, AWS IoT authorization policies, and MQTT topic permissions are managed as infrastructure as code**.

---

# Why Use a Custom Root CA?

AWS IoT Core provides mechanisms for creating device certificates using AWS-managed certificate infrastructure. That is convenient for many deployments, but this project takes a different approach by giving the operator control over the **device certificate authority**.

A custom CA provides control over the certificate hierarchy and certificate issuance process while still allowing AWS IoT Core to authenticate devices using X.509 certificates.

## Benefits

### Customer-Controlled Device Identity

The Root CA becomes the trust anchor for the device fleet.

You can create and manage device certificates independently while still using AWS IoT Core as the managed MQTT broker and authentication service.

### Unique Credentials Per Device

Every device receives its own private key and certificate.

For example:

```text
device-01/
    device-01.key
    device-01.crt

device-02/
    device-02.key
    device-02.crt

device-03/
    device-03.key
    device-03.crt
```

If `device-02` is compromised, its certificate can be deactivated or revoked without requiring every other device to be replaced.

### Control Over Certificate Issuance

The Root CA is under your control rather than relying exclusively on AWS's device-certificate generation workflow.

This can be useful when devices need to operate across multiple environments or when the same device identity infrastructure may eventually be used outside AWS IoT Core.

### Reproducible Infrastructure

The device fleet is represented as Terraform configuration.

Instead of manually creating devices in the AWS console, the desired state is represented as code.

---

# `devices.json`

All devices are defined in the `devices.json` file at the root of the repository.

For example:

```json
{
  "devices": [
    {
      "name": "pico-01"
    },
    {
      "name": "pico-02"
    },
    {
      "name": "temperature-sensor-01"
    }
  ]
}
```

The exact attributes supported by this repository are determined by the Terraform configuration.

The important concept is that **adding or removing a device is performed by changing `devices.json` rather than manually creating resources in AWS**.

---

# Prerequisites

Before using this project, you will need:

- An AWS account
- AWS credentials with permissions to create the required IoT, IAM, and certificate resources
- Terraform
- Git
- A terminal

---

# Install Terraform

If Terraform is not already installed, follow the official HashiCorp installation instructions:

https://developer.hashicorp.com/terraform/install

Verify the installation:

```bash
terraform version
```

---

# Configure AWS Credentials

Terraform uses the AWS provider to communicate with your AWS account.

Configure your AWS credentials using your preferred AWS authentication method.

For example, if you use the AWS CLI:

```bash
aws configure
```

Then verify that your credentials work:

```bash
aws sts get-caller-identity
```

The command should return information about the AWS account and identity Terraform will use.

> **Security warning:** Never commit AWS credentials, private keys, or generated device credentials to Git.

---

# Configure Your Devices

Edit:

```text
devices.json
```

and define the devices you want to provision.

For example:

```json
{
  "devices": [
    {
      "name": "pico-01"
    },
    {
      "name": "pico-02"
    }
  ]
}
```

Each device receives a unique cryptographic identity.

The device name also becomes part of its MQTT authorization boundary.

---

# MQTT Topic Security

Each device is restricted to its own MQTT topic namespace:

```text
/devices/<device-name>/*
```

For example, `pico-01` can publish to:

```text
/devices/pico-01/temperature
/devices/pico-01/status
/devices/pico-01/heartbeat
```

But it cannot publish to:

```text
/devices/pico-02/temperature
/devices/temperature-sensor-01/temperature
/devices/another-device/*
```

The AWS IoT policy attached to the device's certificate is responsible for enforcing this authorization boundary.

This means the device name is not merely an organizational convention. It becomes part of the device's **authorization boundary**.

---

# Terraform Workflow

## 1. Initialize Terraform

From the repository root:

```bash
terraform init
```

This downloads the required Terraform providers and initializes the working directory.

## 2. Review the Terraform Plan

Before creating anything, generate a plan:

```bash
terraform plan
```

Terraform will show the resources it intends to create, modify, or destroy.

You should expect the plan to include resources associated with:

- The custom Root CA
- Device certificates
- Device private keys
- AWS IoT Things
- AWS IoT certificates
- AWS IoT policies
- Certificate/policy associations
- Other supporting resources defined by the repository

**Always review the plan before running `terraform apply`.**

## 3. Apply the Configuration

Once you have reviewed the plan:

```bash
terraform apply
```

Terraform will ask for confirmation before making changes.

Enter:

```text
yes
```

to proceed.

Terraform will then provision all devices defined in `devices.json`.

---

# What Happens During `terraform apply`

For every device defined in `devices.json`, Terraform establishes the device's identity and authorization boundary.

For each device, the provisioning process:

1. Generates a private key.
2. Generates an X.509 certificate.
3. Signs the certificate with the custom Root CA.
4. Registers the certificate with AWS IoT Core.
5. Creates an AWS IoT Thing.
6. Creates a device-specific IoT policy.
7. Associates the certificate and policy with the device.

The resulting device has:

- A private key
- An X.509 client certificate
- An AWS IoT Thing
- A device-specific AWS IoT policy
- A restricted MQTT topic namespace

---

# Authentication vs Authorization

An important part of this architecture is understanding the difference between **authentication** and **authorization**.

## Authentication

Authentication answers:

> "Who is this device?"

The device presents its X.509 certificate during the TLS connection and proves possession of the corresponding private key.

The certificate establishes the device's cryptographic identity.

## Authorization

Authorization answers:

> "What is this device allowed to do?"

Once the device has been authenticated, its AWS IoT policy determines which actions and MQTT topics it can access.

For example:

```text
Device: pico-01

Allowed:
    CONNECT
    PUBLISH /devices/pico-01/*

Not allowed:
    PUBLISH /devices/pico-02/*
    PUBLISH /devices/pico-03/*
    PUBLISH /admin/*
```

Authentication proves **who the device is**.

Authorization determines **what that device can do**.

---

# Zero Trust and Least Privilege

This project follows several principles commonly associated with a **Zero Trust** architecture.

Zero Trust does not simply mean using certificates.

The important principle is:

> **Do not implicitly trust a device because it belongs to the fleet. Verify its identity and explicitly authorize what it is allowed to access.**

Each device is treated as its own security principal.

There is no assumption that because a device belongs to the fleet, it should have access to every resource in the fleet.

Instead, each device receives only the permissions it needs.

---

# Device-Level Least Privilege

Suppose you have three devices:

```text
pico-01
pico-02
pico-03
```

An overly permissive policy might allow all devices to publish to:

```text
/devices/*
```

That creates a large blast radius.

A compromised device could potentially publish to another device's namespace.

This project instead creates device-specific authorization:

```text
pico-01 -> /devices/pico-01/*
pico-02 -> /devices/pico-02/*
pico-03 -> /devices/pico-03/*
```

Therefore, `pico-01` can publish to:

```text
/devices/pico-01/*
```

but cannot publish to:

```text
/devices/pico-02/*
/devices/pico-03/*
```

This is the **principle of least privilege** applied at the individual device level.

---

# Why This Reduces the Blast Radius

Consider a fleet containing 1,000 devices.

If every device shared the same credentials or had a policy allowing access to every device topic, compromising one device could potentially give an attacker access to a significant portion of the fleet.

With this architecture, every device has:

- An independent identity
- Its own certificate
- Its own private key
- Its own AWS IoT policy
- Its own MQTT topic namespace

If one device is compromised, the attacker's access is restricted by that device's policy.

For example, if `pico-02` is compromised, the attacker should not be able to publish as:

```text
/devices/pico-01/*
```

or:

```text
/devices/pico-03/*
```

The compromise therefore has a significantly smaller blast radius.

---

# Custom CA vs AWS-Generated Device Certificates

AWS IoT Core supports device certificates generated through AWS's certificate infrastructure. This is a convenient and valid approach for many deployments.

This project provides an alternative when you want **control over the device certificate hierarchy and certificate issuance process**.

| Capability | AWS-Generated Certificates | Custom CA |
|---|---|---|
| Unique device certificate | Yes | Yes |
| X.509 authentication | Yes | Yes |
| AWS IoT Core support | Yes | Yes |
| Device-specific IoT policy | Yes | Yes |
| Customer-controlled Root CA | No | **Yes** |
| Customer-controlled certificate issuance | Limited | **Yes** |
| Infrastructure as code | Possible | **Built into this project** |
| Independent certificate hierarchy | No | **Yes** |
| Custom certificate lifecycle | AWS workflow | **Customer controlled** |

The important distinction is that a custom CA does **not inherently make X.509 authentication more secure** than using AWS-generated certificates.

Both approaches can provide strong device authentication.

The primary benefits of this project are:

- Control over the certificate hierarchy
- Control over certificate issuance
- Portable device identities
- Reproducible provisioning
- Device-specific authorization
- Infrastructure-as-code management
- Reduced blast radius through least privilege

---

# Adding a Device

1. Add the device to `devices.json`.
2. Run:

```bash
terraform plan
```

3. Review the changes.
4. Apply the changes:

```bash
terraform apply
```

Terraform will provision the new device and its associated AWS IoT resources.

---

# Removing a Device

1. Remove the device from `devices.json`.
2. Run:

```bash
terraform plan
```

3. Carefully review the resources Terraform plans to destroy.
4. Apply the changes:

```bash
terraform apply
```

> **Important:** Removing a device from Terraform configuration and decommissioning a device are related but separate operational concerns. Make sure the device certificate is appropriately deactivated/revoked and the physical device is no longer trusted or deployed.

---

# Protect Your CA and Private Keys

The Root CA private key is the most sensitive credential in this system.

Anyone who obtains the Root CA private key may be able to create certificates that chain back to your trusted CA.

Therefore:

- **Never commit the Root CA private key to Git.**
- **Never commit device private keys to Git.**
- Protect Terraform state.
- Use an encrypted Terraform backend for production deployments.
- Restrict access to the machine or CI/CD system performing certificate generation.
- Consider using a dedicated CA management process for production environments.
- Plan for certificate rotation.
- Plan for certificate revocation.
- Separate development and production certificate authorities.

Terraform state should be treated as sensitive infrastructure data because generated credentials or sensitive values may be represented in state depending on the implementation.

---

# Production Considerations

This repository is intended to make device provisioning repeatable and secure, but a production deployment should also consider:

- Root CA private-key protection
- Certificate expiration
- Certificate rotation
- Certificate revocation
- Device decommissioning
- Secure private-key storage on the device
- Terraform state security
- AWS IAM permissions used to run Terraform
- Backup and recovery of the CA
- Separation of development and production CAs
- Separation of development and production AWS accounts
- Monitoring and auditing of device connections
- Secure distribution of device certificates and private keys

For larger fleets, AWS also provides additional device provisioning mechanisms such as Just-in-Time Registration and Fleet Provisioning.

---

# Security Model Summary

Each device receives:

- A unique cryptographic identity
- A unique X.509 certificate
- A unique private key
- A dedicated AWS IoT policy
- Access only to its own MQTT topic namespace

The security model consists of two primary controls:

1. **X.509 authentication** verifies the identity of the device.
2. **Device-specific IoT policies** enforce what that authenticated device is allowed to do.

This creates a **device-by-device identity and authorization model** based on X.509 authentication and least-privilege IoT policies.

---

# End-to-End Workflow

The complete workflow is:

1. Define devices in `devices.json`.
2. Run `terraform init`.
3. Run `terraform plan`.
4. Review the Terraform plan.
5. Run `terraform apply`.
6. Terraform generates the required device credentials.
7. Terraform creates the AWS IoT resources.
8. Each device receives its own X.509 identity.
9. Each device is assigned a least-privilege AWS IoT policy.
10. Each device is restricted to `/devices/<device-name>/*`.

Once provisioning is complete, the device can use its generated certificate and private key to establish an mTLS connection to AWS IoT Core.

---

## Generated Device Credentials

After running:

```bash
terraform apply
```

Terraform will create a `credentials/` directory in the root of the repository, with a subdirectory for each device defined in `devices.json`:

```
credentials/
├── pico-01/
│   ├── device.key
│   ├── device.crt
│   ├── device-pkcs8.key
│   ├── AmazonRootCA1.pem
│   └── AmazonRootCA1.der
├── pico-02/
│   ├── device.key
│   ├── device.crt
│   ├── device-pkcs8.key
│   ├── AmazonRootCA1.pem
│   └── AmazonRootCA1.der
└── pico-03/
    ├── device.key
    ├── device.crt
    ├── device-pkcs8.key
    ├── AmazonRootCA1.pem
    └── AmazonRootCA1.der
```

### Device Credentials

Each device directory contains the files required for that device to establish a mutually authenticated TLS (mTLS) connection to AWS IoT Core:

| File | Description |
|---|---|
| `device.key` | Device's unique RSA private key — proves the device's identity |
| `device-pkcs8.key` | Device's private key, converted to PKCS#8 format |
| `device.crt` | Device certificate, signed by the custom root CA |
| `AmazonRootCA1.pem` | Amazon Root CA certificate (PEM) — lets the device verify it's actually connecting to AWS IoT, not an impersonator |
| `AmazonRootCA1.der` | Amazon Root CA certificate (DER) |

Copy the appropriate device's credential files to the device. For example, `pico-01` should use the files located in:

```
credentials/pico-01/
```

Each device's private key and certificate are unique to that device and must not be shared between devices.

### Security

The files in `credentials/` contain private keys. **Do not commit the `credentials/` directory to source control or upload the private keys to a public repository.**

# Useful AWS Documentation

- [AWS IoT Core X.509 Client Certificates](https://docs.aws.amazon.com/iot/latest/developerguide/x509-client-certs.html)
- [AWS IoT Core Security Best Practices](https://docs.aws.amazon.com/iot/latest/developerguide/security-best-practices.html)
- [AWS IoT Policies](https://docs.aws.amazon.com/iot/latest/developerguide/iot-policies.html)
- [AWS IoT Device Certificates](https://docs.aws.amazon.com/iot/latest/developerguide/device-certs-create.html)
- [AWS IoT Device Provisioning](https://docs.aws.amazon.com/iot/latest/developerguide/iot-provision.html)
- [Terraform Installation](https://developer.hashicorp.com/terraform/install)
