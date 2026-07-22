output "server_id" {
  value = hcloud_server.mc.id
}

output "public_ip" {
  value = hcloud_server.mc.ipv4_address
}

output "server_address" {
  value = hcloud_server.mc.ipv4_address
}
