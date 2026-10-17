output "dev_ip" {
  value = module.compute.public_ip
}

output "nat_public_ip" {
  value = module.network.nat_public_ip
}