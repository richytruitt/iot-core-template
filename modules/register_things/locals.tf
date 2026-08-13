locals {
  devices = jsondecode(file("./devices.json"))

  devices_by_name = {
    for device in local.devices : device.name => device
  }
}