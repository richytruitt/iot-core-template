variable "device_names" {
  default = ["pico-01", "pico-02", "pico-03"]
}

variable "root_ca_certificate" {
  type = string
}

variable "root_ca_private_key" {
  type      = string
  sensitive = true
}
