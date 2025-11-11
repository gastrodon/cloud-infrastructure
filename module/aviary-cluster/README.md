# Aviary Cluster

An AWS autoscaling group that automatically bootstraps instances with [Aviary.sh](../../.github/docs/aviary.sh) configuration management. Each instance fetches its inventory from a Git repository and applies configured roles and modules during startup.

Uses the `gastrodon/aviary.sh` fork by default.

## Overview

This module handles the AWS infrastructure (launch template, autoscaling group) and automates instance bootstrap via Aviary.sh. When an instance launches:

1. Aviary.sh is installed
2. The inventory repository is cloned
3. Instance-specific configuration (roles, modules, variables) is written to `/opt/aviary/inventory-repo/hosts/$(hostname)/`
4. `av apply` is executed to configure the instance

## Prerequisites

Before using this module, you must have:

### AWS Infrastructure

- **VPC and Subnets**: Instances will be placed in the subnets you specify via `subnet_ids`
- **Security Groups**: Create security groups with appropriate ingress/egress rules and provide their IDs via `security_groups`
- **IAM Instance Profile**: Create an IAM role and instance profile; attach any policies needed for your Aviary roles/modules (e.g., `AmazonSSMManagedInstanceCore` for Systems Manager). Provide the instance profile name via `instance_profile`
- **EC2 Key Pair**: Create an EC2 key pair for SSH access; provide the key name via `key_name`

### Aviary Setup

- **Inventory Repository**: A Git repository containing your Aviary inventory structure. The repository must have a branch (default: `main`) with your roles and modules. If your inventory lives in a subdirectory of the repo, specify it via `inventory_path`

## Basic Usage

```terraform
module "web_cluster" {
  source = "./module/aviary-cluster"

  name               = "web-servers"
  image_id           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type      = "t3.medium"
  instance_profile   = aws_iam_instance_profile.nodes.name
  key_name           = aws_key_pair.cluster.key_name

  desired_capacity = 3
  min_capacity     = 1
  max_capacity     = 5

  subnet_ids      = ["subnet-abc123", "subnet-def456"]
  security_groups = [aws_security_group.nodes.id]

  inventory_url = "https://github.com/myorg/infrastructure-inventory.git"

  aviary_roles = [
    "base-node",
    "web-server",
  ]
  aviary_modules = [
    "docker",
    "nginx",
  ]
  aviary_variables = {
    environment = "production"
    region      = "us-east-1"
  }
}
```

## Variable Reference

### Naming & Identification

| Variable | Type       | Required | Description                                                                           |
|----------|------------|----------|-------------------------------------------------------------------------------------------|
| `name`   | string     | Yes      | Base name for the autoscaling group and launch template. Used as-is in resource names. |
| `server` | bool       | No       | Reserved for future use. Defaults to `false`.                                          |
| `tags`   | map(string)| No       | Additional tags to attach to instances. Applied at launch. Default: `{}`                |

### AWS Infrastructure (Required)

| Variable          | Type       | Description                                                                                  |
|-------------------|------------|----------------------------------------------------------------------------------------------|
| `image_id`        | string     | AMI ID for instances (e.g., `ami-0c55b159cbfafe1f0` for Amazon Linux 2).                    |
| `instance_type`   | string     | EC2 instance type (e.g., `t3.medium`, `m5.large`).                                         |
| `instance_profile`| string     | IAM instance profile name. Determines what AWS APIs instances can call.                     |
| `key_name`        | string     | EC2 key pair name for SSH access.                                                           |
| `subnet_ids`      | set(string)| Subnets where instances will be placed.                                                     |
| `security_groups` | set(string)| Security group IDs attached to instances. Default: —                                     |

### Scaling

| Variable           | Type   | Required | Description                                   |
|--------------------|--------|----------|-----------------------------------------------|
| `desired_capacity` | number | Yes      | Target number of running instances.           |
| `min_capacity`     | number | Yes      | Minimum instances (autoscaling floor).        |
| `max_capacity`     | number | Yes      | Maximum instances (autoscaling ceiling).      |

### Aviary Configuration (Affects Aviary Behavior)

| Variable               | Type       | Description                                                                                                                      |
|------------------------|------------|----------------------------------------------------------------------------------------------------------------------------------|
| `inventory_url`        | string     | **Required.** Git URL of your Aviary inventory repository (e.g., `https://github.com/myorg/infra-inventory.git`). Cloned on each instance. |
| `inventory_branch`     | string     | Git branch to checkout from `inventory_url`. Default: `main`. Used at instance startup.                                         |
| `inventory_path`       | string     | Subdirectory path within the inventory repo where Aviary inventory lives. If repo layout is `infra/aviary/`, set this to `infra/aviary`. Default: repository root. |
| `aviary_install_url`   | string     | **Affects Aviary behavior:** Custom URL to Aviary install script. Overrides default from `aviary_ref`. Allows private/modified fork. |
| `aviary_ref`           | string     | **Affects Aviary behavior:** Version/ref of Aviary.sh to install. Format: `tags/v1.5.1` or `main`. Default: `tags/v1.5.1`.     |
| `aviary_config`        | map(string)| **Affects Aviary behavior:** Map of configuration values written to `/var/lib/aviary/config`. Default: —                   |
| `aviary_roles`         | set(string)| **Affects Aviary behavior:** Aviary roles to apply (e.g., `["base-node", "monitoring-agent"]`). Default: —               |
| `aviary_modules`       | set(string)| **Affects Aviary behavior:** Aviary modules to apply (e.g., `["docker", "prometheus"]`). Default: —                      |
| `aviary_variables`     | map(any)   | **Affects Aviary behavior:** Instance-specific variables for Aviary. Written to `hosts/$(hostname)/variables`. Default: —  |
| `no_cron`              | bool       | **Affects Aviary behavior:** Disable periodic cron job? If `true`, `av apply` only runs once at startup. Default: `false`.    |

### Storage & Instance Options

| Variable                      | Type       | Description                                                                              |
|-------------------------------|------------|-------------------------------------------------------------------------------------------|
| `availability_zones`          | set(string)| Specific AZ IDs to use. If not set, inferred from `subnet_ids`.                         |
| `volume_size`                 | number     | Root volume size in GB. Default: `30`.                                                   |
| `instance_use_spot`           | bool       | Launch spot instances instead of on-demand? Default: `false`. Reduces cost but can be interrupted. |
| `instance_allocation_strategy`| string     | Spot allocation strategy when `instance_use_spot = true`. Default: `capacity-optimized`. |

### Advanced

| Variable       | Type       | Description                                                                                                |
|----------------|------------|------------------------------------------------------------------------------------------------------------|
| `user_data`    | string     | Additional shell commands to run **after** Aviary bootstrap completes. Default: —                    |
| `target_groups`| set(string)| ALB/NLB target group ARNs to register instances with. Default: —                                       |

## Outputs

| Output     | Description                                                                                      |
|------------|--------------------------------------------------------------------------------------------------|
| `asg_name` | Name of the created autoscaling group. Useful for referencing in other Terraform or AWS CLI. |

## Advanced Examples

### Cluster with Custom Inventory Path

If your Git repository has Aviary inventory in a `clusters/prod/` subdirectory:

```terraform
module "prod_cluster" {
  source = "./module/aviary-cluster"

  name               = "prod-workers"
  image_id           = "ami-0c55b159cbfafe1f0"
  instance_type      = "t3.large"
  instance_profile   = aws_iam_instance_profile.nodes.name
  key_name           = aws_key_pair.cluster.key_name

  desired_capacity = 5
  min_capacity     = 2
  max_capacity     = 10

  subnet_ids      = data.aws_subnets.private.ids
  security_groups = [aws_security_group.workers.id]

  inventory_url    = "https://github.com/myorg/infrastructure.git"
  inventory_path   = "clusters/prod"  # Aviary looks in clusters/prod/hosts/
  inventory_branch = "production"

  aviary_roles = [
    "base-node",
    "worker-pool-a",
  ]
  aviary_modules = [
    "container-runtime",
    "monitoring",
  ]
  aviary_variables = {
    pool        = "a"
    environment = "production"
    region      = "us-east-1"
  }

  no_cron = false  # Keep cron enabled for drift correction
}
```

### Spot Instance Cluster with Aviary Config

Using spot instances to reduce costs, with custom Aviary configuration:

```terraform
module "spot_cluster" {
  source = "./module/aviary-cluster"

  name               = "spot-workers"
  image_id           = "ami-0c55b159cbfafe1f0"
  instance_type      = "t3.medium"
  instance_profile   = aws_iam_instance_profile.nodes.name
  key_name           = aws_key_pair.cluster.key_name

  desired_capacity = 2
  min_capacity     = 0
  max_capacity     = 4

  subnet_ids      = data.aws_subnets.public.ids
  security_groups = [aws_security_group.web.id]

  inventory_url = "https://github.com/myorg/fleet-inventory.git"

  # Use spot instances
  instance_use_spot          = true
  instance_allocation_strategy = "capacity-optimized"
  volume_size                = 50

  aviary_roles = ["base-node", "web-app"]
  aviary_modules = ["docker", "nodejs"]

  # Aviary configuration affecting behavior
  aviary_config = {
    server   = "false"
    loglevel = "info"
  }

  aviary_variables = {
    app_env = "staging"
    port    = "8080"
  }

  no_cron = true  # One-time bootstrap only

  tags = {
    Environment = "staging"
    CostCenter  = "eng-ops"
  }
}
```

### Registering with Load Balancer

Automatically register instances with an ALB target group:

```terraform
module "api_cluster" {
  source = "./module/aviary-cluster"

  name               = "api-servers"
  image_id           = "ami-0c55b159cbfafe1f0"
  instance_type      = "t3.medium"
  instance_profile   = aws_iam_instance_profile.nodes.name
  key_name           = aws_key_pair.cluster.key_name

  desired_capacity = 3
  min_capacity     = 1
  max_capacity     = 6

  subnet_ids      = data.aws_subnets.private.ids
  security_groups = [aws_security_group.api.id]

  inventory_url = "https://github.com/myorg/services-inventory.git"

  aviary_roles    = ["base-node", "api-service"]
  aviary_modules  = ["container-runtime", "api-server"]

  # Register with load balancer
  target_groups = [aws_lb_target_group.api.arn]

  aviary_variables = {
    service = "api"
    port    = "8000"
  }
}
```

## Bootstrap Flow

When an instance starts, the user data script performs these steps in order:

1. **Install Aviary.sh** from `aviary_install_url` (or default based on `aviary_ref`)
2. **Clone inventory repository** from `inventory_url` into `/opt/aviary/inventory-repo`, checking out `inventory_branch`
3. **Write Aviary configuration** entries from `aviary_config` to `/var/lib/aviary/config`
4. **Create instance inventory directory** at `hosts/$(hostname)/` (within the path specified by `inventory_path`)
5. **Write instance variables** to `hosts/$(hostname)/variables` from `aviary_variables`
6. **Write roles** to `hosts/$(hostname)/roles` from `aviary_roles`
7. **Write modules** to `hosts/$(hostname)/modules` from `aviary_modules`
8. **Run `av apply`** to apply all roles and modules
9. **Execute additional user data** if `user_data` is provided

See [Aviary.sh documentation](../../.github/docs/aviary.sh) for details on how roles and modules work.

## Troubleshooting

### Instances failing to bootstrap

1. **SSH into an instance** and check `/var/log/cloud-init-output.log` for errors
2. **Verify git access**: Ensure the instance profile has permissions to clone the inventory repository (private repo? Check credentials)
3. **Check Aviary logs**: `cat /var/log/aviary.log` or `journalctl -u aviary` if using the cron setup
4. **Test inventory structure**: Verify roles and modules directories exist in your inventory repository at the path specified by `inventory_path`

### Cron not running after bootstrap

- Ensure `no_cron = false` (the default). If set to `true`, Aviary only runs once at startup
- Check that `/var/spool/cron/crontabs/root` exists and contains the Aviary entry
- Verify the cron daemon is running: `systemctl status crond`

### Aviary version mismatch

- Explicitly set `aviary_ref` to the version you need, e.g., `aviary_ref = "tags/v1.4.0"`
- Or provide a custom install script via `aviary_install_url`
