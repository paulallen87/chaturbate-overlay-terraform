variable "access_key"             {}
variable "secret_key"             {}
variable "region"                 { default = "us-east-1" }
variable "az_count"               {}
variable "cidr_block"             {}
variable "subnet_bits"            { default = 8 }

# ==============================================================================
# Providers
# ==============================================================================

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# ==============================================================================
# Availability Zones
# ==============================================================================

data "aws_availability_zones" "available" {}

# ==============================================================================
# VPCS
# ==============================================================================

resource "aws_vpc" "default" {
  cidr_block            = "${var.cidr_block}"
  enable_dns_support    = true
  enable_dns_hostnames  = true

  tags {
    Name  = "Chaturbate VPC"
    for   = "chaturbate"
  }
}

# ==============================================================================
# Internet Gateways
# ==============================================================================

resource "aws_internet_gateway" "default" {
  vpc_id    = "${aws_vpc.default.id}"

  tags {
    Name  = "Chaturbate Gateway"
    for   = "chaturbate"
  }
}

# ==============================================================================
# Route Tables
# ==============================================================================

resource "aws_route_table" "default" {
  vpc_id    = "${aws_vpc.default.id}"

  tags {
    Name  = "Chaturbate Route Table"
    for   = "chaturbate"
  }
}

# ==============================================================================
# Route Table Associations
# ==============================================================================

resource "aws_route_table_association" "default" {
  subnet_id      = "${aws_subnet.default.id}"
  route_table_id = "${aws_route_table.default.id}"
}

resource "aws_route_table_association" "instance" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.instance.*.id, count.index)}"
  route_table_id = "${aws_route_table.default.id}"
}

# ==============================================================================
# Routes
# ==============================================================================

resource "aws_route" "default" {
  route_table_id         = "${aws_route_table.default.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# ==============================================================================
# Subnets
# ==============================================================================

resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${cidrsubnet(aws_vpc.default.cidr_block, var.subnet_bits, 1)}"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = true

  tags {
    Name  = "Chaturbate Default Subnet"
    for   = "chaturbate"
  }
}

resource "aws_subnet" "instance" {
  count                   = "${var.az_count}"
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${cidrsubnet(aws_vpc.default.cidr_block, var.subnet_bits, 100 + count.index)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = true

  tags {
    Name  = "Chaturbate Instance Subnet ${count.index}"
    for   = "chaturbate"
  }
}

# ==============================================================================
# Network ACLs
# ==============================================================================

resource "aws_network_acl" "default" {
  vpc_id = "${aws_vpc.default.id}"

  ingress {
    protocol   = "udp"
    rule_no    = 1
    action     = "allow"
    cidr_block = "${aws_subnet.default.cidr_block}"
    from_port  = 2049
    to_port    = 2049
  }

  egress {
    protocol   = "tcp"
    rule_no    = 2
    action     = "allow"
    cidr_block = "${aws_subnet.default.cidr_block}"
    from_port  = 2049
    to_port    = 2049
  }

  tags {
    Name  = "Chaturbate Network ACL"
    for   = "chaturbate"
  }
}

# ==============================================================================
# Security Groups
# ==============================================================================

resource "aws_security_group" "loadbalancer" {
  name        = "chaturbate-alb-security-group"
  description = "Chaturbate Loadbalancer Security Group"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name  = "Chaturbate Loadbalancer Security Group"
    for   = "chaturbate"
  }

  depends_on = ["aws_internet_gateway.default"]
  
}

resource "aws_security_group" "instances" {
  name        = "chaturbate-instances-security-group"
  description = "Chaturbate Instances Security Group"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.instance.*.cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name  = "Chaturbate Instances Security Group"
    for   = "chaturbate"
  }
}

resource "aws_security_group" "filesystem" {
  name        = "chaturbate-instances-filesystem-group"
  description = "Chaturbate Instances Filesystem Group"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.instance.*.cidr_block}"]
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "udp"
    cidr_blocks = ["${aws_subnet.instance.*.cidr_block}"]
  }

  tags {
    Name  = "Chaturbate Instances Filesystem Group"
    for   = "chaturbate"
  }
}

# ==============================================================================
# Output
# ==============================================================================

output "vpc_id" {
  value = "${aws_vpc.default.id}"
}

output "default_subnet_id" {
  value = "${aws_subnet.default.id}"
}

output "instance_subnet_ids" {
  value = ["${aws_subnet.instance.*.id}"]
}

output "loadbalancer_group_id" {
  value = "${aws_security_group.loadbalancer.id}"
}

output "instance_group_id" {
  value = "${aws_security_group.instances.id}"
}

output "filesystem_group_id" {
  value = "${aws_security_group.filesystem.id}"
}