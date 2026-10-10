output "edge1_eip" {
  value = module.edge1.eip
}

output "edge1_wg_pub_parameter" {
  description = "SSM parameter holding edge1's WireGuard public key, written by the box on first boot."
  value       = module.edge1.wg_pub_parameter
}

output "edge1_tunnel_ip" {
  value = module.edge1.tunnel_ip
}
