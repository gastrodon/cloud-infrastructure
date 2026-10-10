# The only public records: everything under the domain lands on edge1's EIP.

resource "porkbun_dns_record" "apex" {
  domain    = var.domain
  subdomain = ""
  type      = "A"
  content   = module.edge1.eip
  ttl       = 600
}

resource "porkbun_dns_record" "wildcard" {
  domain    = var.domain
  subdomain = "*"
  type      = "A"
  content   = module.edge1.eip
  ttl       = 600
}

resource "porkbun_dns_record" "caa" {
  for_each  = toset(var.caa_issuers)
  domain    = var.domain
  subdomain = ""
  type      = "CAA"
  content   = "0 issue \"${each.value}\""
  ttl       = 600
}
