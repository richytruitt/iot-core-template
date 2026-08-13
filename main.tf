module "custom_root_ca" {
  source       = "./modules/root_ca_create"
  common_name  = "DevicesRootCA"
  organization = "TEST_ORG"
}
