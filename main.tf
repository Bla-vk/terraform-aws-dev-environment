module "network" {
  source = "./modules/network"
}

module "compute" {
  source            = "./modules/compute"
  subnet_id         = module.network.public_subnet_id
  security_group_id = module.network.security_group_id
  host_os           = var.host_os
}
