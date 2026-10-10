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

resource "porkbun_dns_record" "lab_wildcard" {
  domain    = var.domain
  subdomain = "*.lab"
  type      = "A"
  content   = module.edge1.eip
  ttl       = 600
}

resource "porkbun_dns_record" "edge1" {
  domain    = var.domain
  subdomain = "edge1"
  type      = "A"
  content   = module.edge1.eip
  ttl       = 600
}

# Receive-only mail for *@lab (EVA-590/605): :25 passes through the edge to home Stalwart.
resource "porkbun_dns_record" "lab_mx" {
  domain    = var.domain
  subdomain = "lab"
  type      = "MX"
  content   = "edge1.${var.domain}"
  prio      = 10
  ttl       = 600
}

resource "porkbun_dns_record" "lab_spf" {
  domain    = var.domain
  subdomain = "lab"
  type      = "TXT"
  content   = "v=spf1 -all"
  ttl       = 600
}

# *.lab makes lab an empty non-terminal, so the apex wildcard no longer answers for it.
resource "porkbun_dns_record" "lab" {
  domain    = var.domain
  subdomain = "lab"
  type      = "A"
  content   = module.edge1.eip
  ttl       = 600
}
