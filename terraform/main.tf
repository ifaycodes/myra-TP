terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.0"
        }
    }
}

provider "aws" {
    region = var.region
}

module "myra_vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "6.6.1"

    name = "myra_vpc"
    cidr = "10.10.0.0/16"

    azs = [var.zone1, var.zone2]

    public_subnets   = ["10.10.1.0/24", "10.10.2.0/24"]
    private_subnets  = ["10.10.3.0/24", "10.10.4.0/24"]
    database_subnets = ["10.10.5.0/24", "10.10.6.0/24"]

    create_database_subnet_group       = true
    create_database_subnet_route_table = true

    enable_nat_gateway     = true
    single_nat_gateway     = true

    enable_dns_hostnames   = true
    enable_dns_support     = true
    
    tags = {
        Project     = "Myra Fintech"
        Environment = "development"
        }
}