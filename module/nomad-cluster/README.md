# Nomad Cluster Module

## Overview

The `nomad-cluster` module provisions a complete, production-ready Nomad cluster on AWS. It creates an EC2 autoscaling group with Nomad agents, bootstraps the cluster using the [aviary-cluster](../aviary-cluster) module, and sets up all necessary networking infrastructure including load balancers, security groups, DNS records, and routing for both the Nomad orchestrator and Consul service mesh.

### What It Creates

- **EC2 Autoscaling Groups**: Configurable capacity with spot instance support, running Nomad agents (servers and/or clients)
- **Load Balancers**:
  - Service ingress load balancer with SSL/TLS termination for workload traffic
  - Admin load balancer for Nomad, Consul, and Traefik UI access
- **Networking**:
  - Security groups with cluster-internal communication, SSH access, and egress rules
  - Route53 DNS records for wildcard domain routing and admin service access
  - ACM certificates with DNS validation for HTTPS
- **IAM**: Instance roles with permissions for autoscaling, EC2, S3, ECR, KMS, and IAM operations
- **Load Balancer Target Groups**: Separate targets for Nomad, Consul, Traefik, and reverse proxy services
- **Cluster Configuration**:
  - Consul agent integration with per-cluster tokens
  - Nomad bootstrap configuration via Aviary inventory

## Prerequisites

- AWS account with appropriate permissions
- VPC and subnets already provisioned
- Route53 hosted zone for your domain
- SSH key pair in AWS EC2
- Aviary inventory repository (for cluster configuration)

## Usage

```hcl
module "nomad_cluster" {
  source = "github.com/gastrodon/cloud-infrastructure//module/nomad-cluster"

  name                  = "production"
  domain                = "cluster.example.com"
  route53_zone          = aws_route53_zone.main.zone_id
  vpc_id                = aws_vpc.main.id
  lb_subnet_ids         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  ssh_key_name          = aws_key_pair.deploy.key_name
  aviary_inventory_url  = "https://github.com/your-org/infrastructure"
  aviary_inventory_path = "aviary"

  autoscaling_groups = [
    {
      name               = "servers"
      desired_capacity   = 3
      instance_type      = "t3.medium"
      image_id           = data.aws_ami.ubuntu.image_id
      availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
      server             = true
      datacenter         = "dc1"
      aws_region         = "us-east-1"
      mode               = "nomad-prod-server"
      instance_use_spot  = false
    },
    {
      name               = "clients"
      desired_capacity   = 5
      min_capacity       = 2
      max_capacity       = 10
      instance_type      = "t3.large"
      image_id           = data.aws_ami.ubuntu.image_id
      availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
      server             = false
      datacenter         = "dc1"
      aws_region         = "us-east-1"
      instance_use_spot  = true
    }
  ]
}

output "nomad_url" {
  value = "https://nomad.${module.nomad_cluster.balancer_host}"
}

output "consul_url" {
  value = "https://consul.${module.nomad_cluster.balancer_host}"
}
```

## Variables

| Name                      | Type        | Default              | Required | Description                                                                                              |
|---------------------------|-------------|----------------------|----------|----------------------------------------------------------------------------------------------------------|
| `name`                    | string      | —                    | Yes      | Name of the Nomad cluster. Used as identifier for resources.                                             |
| `domain`                  | string      | —                    | Yes      | FQDN that routes to the cluster (e.g., `cluster.example.com`). Creates wildcard DNS and routing rules.   |
| `route53_zone`            | string      | —                    | Yes      | Route53 hosted zone ID where DNS records will be created.                                                |
| `vpc_id`                  | string      | —                    | Yes      | VPC ID where cluster resources will be deployed.                                                         |
| `lb_subnet_ids`           | set(string) | —                    | Yes      | Subnets for load balancers. **Requires minimum 2 subnets**.                                               |
| `ssh_key_name`            | string      | —                    | Yes      | EC2 key pair name for SSH access to instances.                                                           |
| `aviary_inventory_url`    | string      | —                    | Yes      | URL to the Aviary inventory repository (e.g., GitHub HTTPS URL).                                         |
| `aviary_inventory_path`   | string      | —                    | No       | Path within the inventory repository where Aviary configuration lives. Defaults to repository root.      |
| `aviary_ref`              | string      | —                    | No       | Specific Aviary version to install. When `null`, uses latest.                                            |
| `autoscaling_groups`      | list(any)   | —                    | No       | List of autoscaling group descriptors (see below).                                                       |
| `domain_extra`            | list(string)| —                    | No       | Additional domains that route to the cluster (e.g., alternate domain names).                             |
| `aviary_inventory_branch` | string      | `"main"`             | No       | Git branch to checkout from the inventory repository.                                                    |
| `aviary_roles`            | set(string) | `["nomad-cluster"]`  | No       | Aviary roles to apply to cluster instances.                                                              |

### Autoscaling Group Configuration

Each item in `autoscaling_groups` supports:

| Field                 | Type        | Required | Description                                                                                           |
|-----------------------|-------------|----------|-------------------------------------------------------------------------------------------------------|
| `name`                | string      | Yes      | Unique name within the cluster (e.g., `"servers"`, `"clients"`). Prefixed with cluster name.         |
| `desired_capacity`    | number      | Yes      | Target number of instances. Also used for `min_capacity` if not specified.                           |
| `instance_type`       | string      | Yes      | EC2 instance type (e.g., `"t3.medium"`, `"m5.xlarge"`).                                            |
| `image_id`            | string      | Yes      | AMI ID to launch. Typically an Ubuntu LTS image.                                                    |
| `datacenter`          | string      | Yes      | Nomad datacenter name for this group (e.g., `"dc1"`, `"us-east"`).                                 |
| `aws_region`          | string      | Yes      | AWS region where the group is deployed (e.g., `"us-east-1"`).                                       |
| `availability_zones`  | list(string)| No       | Specific AZs for this group. If not specified, all AZs in the region are used.                      |
| `mode`                | string      | No       | Aviary mode/role for Nomad configuration (e.g., `"nomad-prod-server"`, `"nomad-client"`).          |
| `subnet_ids`          | list(string)| No       | Specific subnets for instances. If not specified, uses all subnets in the VPC.                      |
| `min_capacity`        | number      | No       | Minimum instances. Defaults to `desired_capacity`.                                                  |
| `max_capacity`        | number      | No       | Maximum instances. Defaults to `desired_capacity * 2`.                                              |
| `server`              | bool        | No       | If `true`, instance is a Nomad server and added to load balancer targets. Defaults to `false`.      |
| `instance_use_spot`   | bool        | No       | Use spot instances for cost savings. Defaults to `false`.                                           |
| `key_name`            | string      | No       | Override SSH key for this group. Defaults to cluster's `ssh_key_name`.                              |

## Outputs

| Name              | Type   | Description                                                                          |
|-------------------|--------|--------------------------------------------------------------------------------------|
| `cluster_key`     | string | Unique identifier for the cluster. Used internally by Nomad and Consul.               |
| `balancer_arn`    | string | ARN of the service ingress load balancer.                                            |
| `balancer_host`   | string | Domain name routing to the cluster (the `domain` variable).                          |
| `instance_role_id`| string | IAM role ID for cluster instances. Useful for attaching additional policies.         |
| `consul_token`    | string | Generated Consul ACL token for cluster authentication.                               |

## Access and DNS

The module creates three DNS entry patterns:

1. **Wildcard Service Traffic**: `*.{domain}` → Routes via HTTPS to service ingress load balancer
2. **Nomad Admin**: `nomad.{domain}` → HTTPS access to Nomad UI (port 4646)
3. **Consul Admin**: `consul.{domain}` → HTTPS access to Consul UI (port 8500)
4. **Traefik Admin**: `traefik.{domain}` → HTTPS access to Traefik dashboard (port 8080)

All traffic over HTTP is redirected to HTTPS. An ACM certificate is automatically created and validated via DNS.

## Security Considerations

- Instances have broad IAM permissions (`s3:*`, `ec2:*`, `ecr:*`, `iam:*`, etc.). Review the [iam.tf](./iam.tf) file and restrict as needed for your security posture.
- SSH access is allowed from `0.0.0.0/0` (anywhere). Restrict via security group rules if needed.
- All inter-cluster communication is allowed (port 0-65535).
- Load balancer allows HTTP/HTTPS from anywhere.
- Traffic to hardcoded CIDR blocks `172.30.0.0/16` and `172.31.0.0/16` is allowed.

## Load Balancer Configuration

### Service Ingress Load Balancer

Routes workload traffic (nomad jobs, etc.) via HTTPS:

- **Default action**: Forwards to reverse proxy target group (port 80)
- **HTTP traffic**: Redirected to HTTPS with 301 status
- **Health checks**: Target group checks port 8080 `/ping/` endpoint with 200 matcher

### Admin Load Balancer

Provides access to cluster management interfaces:

- **Nomad UI**: Routes `nomad.{domain}` to port 4646, checks `/ui/` path
- **Consul UI**: Routes `consul.{domain}` to port 8500, checks `/ui/` path
- **Traefik**: Routes `traefik.{domain}` to port 8080, checks `/ping/` path

## Integration with Aviary

This module delegates instance configuration to the [aviary-cluster](../aviary-cluster) module. The Aviary inventory is pulled from your specified repository and roles/variables are used to configure:

- Nomad server vs. client mode
- Cluster bootstrap expectations
- Datacenter and region assignments
- Consul token and cluster key settings

Refer to your Aviary inventory structure for available roles and variables.

## Example: Complete Multi-Region Cluster

See [aws/cluster](../../aws/cluster) for a complete working example that:

- Uses default VPC and subnets
- Provisions Ubuntu 24.04 instances
- Creates a 3-node Nomad server cluster
- Configures Route53 for the domain
- Outputs Nomad and Consul URLs

## Troubleshooting

- **Load balancer shows 504 errors**: Verify instances are running and health checks pass (check target group health status in AWS console)
- **DNS not resolving**: Ensure Route53 zone delegation is correct and ACM certificate validation records were created
- **Instances fail to launch**: Check IAM role permissions, security group rules, and AMI availability in the target AZs
- **Nomad cluster won't bootstrap**: Verify `bootstrap_expect` matches desired capacity and instances can communicate (check security groups)
