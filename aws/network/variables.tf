variable "default_vpc_internet_gateway_id" {
  description = "ID of the internet gateway attached to the default VPC"
  default     = "igw-17dc216d"
}

variable "default_vpc_route_table_id" {
  description = "Route table attached to the default VPC"
  default     = "rtb-e345509d"
}

variable "default_vpc_subnet_ids" {
  description = "IDs of the subnets in the default VPC"
  default = [
    "subnet-081a6229", # us-east-1a
    "subnet-c09c9e8d", # us-east-1b
    "subnet-56621d09", # us-east-1c
    "subnet-3f532159", # us-east-1d
    "subnet-4124a270", # us-east-1e
    "subnet-ed0b3fe3", # us-east-1f
  ]
}

variable "defualt_vpc_id" {
  description = "ID of the account's default VPC"
  default     = "vpc-3736b94a"
}
