variable "access_key"       {}
variable "secret_key"       {}
variable "public_key_path"  {}

variable "region"             { default = "us-east-1" }
variable "az_count"           { default = 3 }
variable "asg_min"            { default = 1 }
variable "asg_max"            { default = 3 }
variable "asg_desired"        { default = 2 }


# ==============================================================================
# Providers
# ==============================================================================

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# ==============================================================================
# Template Files
# ==============================================================================

data "template_file" "cloud_config" {
  template = "${file("${path.module}/cloud_configs/chaturbate.yml")}"

  vars {
    aws_region         = "${var.region}"
    ecs_cluster_name   = "${aws_ecs_cluster.default.name}"
    ecs_log_level      = "info"
    ecs_agent_version  = "latest"
    ecs_log_group_name = "${aws_cloudwatch_log_group.service.name}"
  }
}

data "template_file" "task_definition" {
  template = "${file("${path.module}/task_definitions/chaturbate.json")}"

  vars {
    image_url        = "paulallen87/chaturbate-overlay-app:latest"
    container_name   = "overlay-app"
    log_group_region = "${var.region}"
    log_group_name   = "${aws_cloudwatch_log_group.instance.name}",
    log_group_prefix = "overlay-app"
  }
}

data "template_file" "instance_profile_policy" {
  template = "${file("${path.module}/policies/chaturbate-instance-policy.json")}"

  vars {
    instance_log_group_arn = "${aws_cloudwatch_log_group.instance.arn}"
    service_log_group_arn = "${aws_cloudwatch_log_group.service.arn}"
  }
}

data "template_file" "service_profile_policy" {
  template = "${file("${path.module}/policies/chaturbate-service-policy.json")}"

  vars {}
}

data "template_file" "instance_policy" {
  template = "${file("${path.module}/policies/assume-policy.json")}"

  vars {
    service = "ec2.amazonaws.com"
  }
}

data "template_file" "service_policy" {
  template = "${file("${path.module}/policies/assume-policy.json")}"

  vars {
    service = "ecs.amazonaws.com"
  }
}

# ==============================================================================
# Availability Zones
# ==============================================================================

data "aws_availability_zones" "available" {}

# ==============================================================================
# IAM Roles
# ==============================================================================

resource "aws_iam_role" "service" {
  name = "chaturbate_service_role"
  assume_role_policy = "${data.template_file.service_policy.rendered}"
}

resource "aws_iam_role" "instance" {
  name = "chaturbate_instance_role"
  assume_role_policy = "${data.template_file.instance_policy.rendered}"
}

# ==============================================================================
# IAM Role Policies
# ==============================================================================

resource "aws_iam_role_policy" "service" {
  name = "chaturbate_service_policy"
  role = "${aws_iam_role.service.name}"
  policy = "${data.template_file.service_profile_policy.rendered}"
}

resource "aws_iam_role_policy" "instance" {
  name   = "chaturbate_instance_policy"
  role   = "${aws_iam_role.instance.name}"
  policy = "${data.template_file.instance_profile_policy.rendered}"
}

# ==============================================================================
# IAM Instance Profiles
# ==============================================================================

resource "aws_iam_instance_profile" "default" {
  name  = "chaturbate"
  role = "${aws_iam_role.instance.name}"
}

# ==============================================================================
# VPCS
# ==============================================================================

resource "aws_vpc" "default" {
  cidr_block            = "100.100.0.0/16"
  enable_dns_support    = true
  enable_dns_hostnames  = true
  tags                  { Name = "Chaturbate" }
}

# ==============================================================================
# Internet Gateways
# ==============================================================================

resource "aws_internet_gateway" "default" {
  vpc_id    = "${aws_vpc.default.id}"
  tags      { Name = "Chaturbate" }
}

# ==============================================================================
# Route Tables
# ==============================================================================

resource "aws_route_table" "default" {
  vpc_id    = "${aws_vpc.default.id}"
  tags      { Name = "Chaturbate" }
}

# ==============================================================================
# Route Table Associations
# ==============================================================================

resource "aws_route_table_association" "default" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.default.*.id, count.index)}"
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
  count                   = "${var.az_count}"
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${cidrsubnet(aws_vpc.default.cidr_block, 8, count.index)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = true
  tags                    { Name = "Chaturbate ${count.index}" }
}

# ==============================================================================
# Security Groups
# ==============================================================================

resource "aws_security_group" "loadbalancer" {
  name        = "chaturbate-elb-security-group"
  description = "Chaturbate Loadbalancer Security Group"
  vpc_id      = "${aws_vpc.default.id}"
  depends_on  = ["aws_internet_gateway.default"]
  tags        { Name = "Chaturbate ELB" }

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
}

resource "aws_security_group" "instances" {
  name        = "chaturbate-instances-security-group"
  description = "Chaturbate Instances Security Group"
  vpc_id      = "${aws_vpc.default.id}"
  tags        { Name = "Chaturbate Instances" }

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
    cidr_blocks = ["${aws_vpc.default.cidr_block}"]
  }

  ingress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.default.cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# Autoscaling Groups
# ==============================================================================

resource "aws_autoscaling_group" "default" {
  name                 = "chaturbate-autoscaling-group"
  vpc_zone_identifier  = ["${aws_subnet.default.*.id}"]
  min_size             = "${var.asg_min}"
  max_size             = "${var.asg_max}"
  desired_capacity     = "${var.asg_desired}"
  launch_configuration = "${aws_launch_configuration.default.name}"

  tag {
    key                 = "Name"
    value               = "Chaturbate"
    propagate_at_launch = false
  }
}

# ==============================================================================
# Load Balancers
# ==============================================================================

resource "aws_alb" "default" {
  name            = "chaturbate-loadbalancer"
  subnets         = ["${aws_subnet.default.*.id}"]
  security_groups = ["${aws_security_group.loadbalancer.id}"]
}

# ==============================================================================
# Load Balancer Target Groups
# ==============================================================================

resource "aws_alb_target_group" "default" {
  name     = "chaturbate-alb-target-group"
  protocol = "HTTP"
  port     = 80
  vpc_id   = "${aws_vpc.default.id}"
}

# ==============================================================================
# Load Balancer Listeners
# ==============================================================================

resource "aws_alb_listener" "default" {
  load_balancer_arn = "${aws_alb.default.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.default.arn}"
    type             = "forward"
  }
}

# ==============================================================================
# Key Pairs
# ==============================================================================

resource "aws_key_pair" "default" {
  key_name   = "chaturbate"
  public_key = "${file(var.public_key_path)}"
}

# ==============================================================================
# AMIS
# ==============================================================================

data "aws_ami" "default" {
  most_recent = true

  filter {
    name   = "description"
    values = ["CoreOS stable *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["595879546273"] # CoreOS
}

# ==============================================================================
# Launch Configurations
# ==============================================================================

resource "aws_launch_configuration" "default" {
  security_groups             = ["${aws_security_group.instances.id}",]
  key_name                    = "${aws_key_pair.default.key_name}"
  image_id                    = "${data.aws_ami.default.id}"
  instance_type               = "t2.micro"
  iam_instance_profile        = "${aws_iam_instance_profile.default.name}"
  user_data                   = "${data.template_file.cloud_config.rendered}"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# Log Groups
# ==============================================================================

resource "aws_cloudwatch_log_group" "instance" {
  name = "chaturbate/instance"
  tags { Name = "Chaturbate Instance"}
}

resource "aws_cloudwatch_log_group" "service" {
  name = "chaturbate/service"
  tags { Name = "Chaturbate Service"}
}

# ==============================================================================
# Clusters
# ==============================================================================

resource "aws_ecs_cluster" "default" {
  name = "chaturbate"
}

# ==============================================================================
# Task Definitions
# ==============================================================================

resource "aws_ecs_task_definition" "default" {
  family                = "overlay_app"
  network_mode          = "bridge"
  container_definitions = "${data.template_file.task_definition.rendered}"

  volume {
    name = "certs"
    host_path = "/ecs/certs"
  }

  volume {
    name = "config"
    host_path = "/ecs/configs"
  }
}

# ==============================================================================
# Services
# ==============================================================================

resource "aws_ecs_service" "default" {
  name            = "chaturbate_overlay_app"
  cluster         = "${aws_ecs_cluster.default.id}"
  task_definition = "${aws_ecs_task_definition.default.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.service.arn}"
  depends_on      = [
    "aws_iam_role_policy.service",
    "aws_alb_listener.default",
  ]

  load_balancer {
    target_group_arn = "${aws_alb_target_group.default.arn}"
    container_name   = "overlay-app"
    container_port   = "8080"
  }
}