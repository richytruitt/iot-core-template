module "custom_root_ca" {
  source       = "./modules/root_ca_create"
  common_name  = "DevicesRootCA"
  organization = "TEST_ORG"
}

module "register_things" {
  source = "./modules/register_things"
  
  root_ca_certificate = module.custom_root_ca.root_ca_certificate
  root_ca_private_key = module.custom_root_ca.root_ca_private_key
}
