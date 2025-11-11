locals {
  host = "redapt-demo.click"

  autoscaling_groups = [
    {
      name               = "server"
      aws_region         = "us-east-1"
      mode               = "nomad-dev-server"
      datacenter         = "server"
      desired_capacity   = 4
      instance_type      = "t3.small"
      availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
      server             = true
      image_id           = data.aws_ami.ubuntu.image_id
      instance_use_spot  = true
    },
  ]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] // Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


data "aws_route53_zone" "dns" {
  name = "${local.host}."
}

data "aws_key_pair" "id_ed25519" {
  key_name = "id_ed25519"
}

module "dev" {
  source = "github.com/gastrodon/cloud-infrastructure//module/nomad-cluster"

  name                  = "redapt-demo"
  domain                = local.host
  route53_zone          = data.aws_route53_zone.dns.zone_id
  autoscaling_groups    = local.autoscaling_groups
  ssh_key_name          = data.aws_key_pair.id_ed25519.key_name
  vpc_id                = data.aws_vpc.default.id
  lb_subnet_ids         = data.aws_subnets.default.ids
  aviary_inventory_url  = "https://github.com/gastrodon/cloud-infrastructure"
  aviary_inventory_path = "aviary-inventory"
  aviary_roles          = ["nomad-cluster"]
}

resource "null_resource" "nomad_cluster_ready" {
  provisioner "local-exec" {
    command = "until curl -f -k https://nomad.${module.dev.balancer_host}/v1/status/leader > /dev/null 2>&1; do sleep 10; done"
  }

  depends_on = [module.dev]
}

resource "random_uuid" "nomad_token" {
  keepers = {
    cluster = module.dev.balancer_host
  }

  depends_on = [null_resource.nomad_cluster_ready]

  provisioner "local-exec" {
    command = "echo ${self.result} > .secret_NOMAD_TOKEN"
  }
}


output "consul_token" {
  value = module.dev.consul_token
}

output "consul_cluster_url" {
  value = "https://consul.${module.dev.balancer_host}"
}

output "nomad_token" {
  value = module.dev.consul_token
}

output "nomad_cluster_url" {
  value = "https://nomad.${module.dev.balancer_host}"
}
