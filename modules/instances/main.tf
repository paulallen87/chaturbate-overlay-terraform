variable "access_key"             {}
variable "secret_key"             {}
variable "region"                 { default = "us-east-1" }
variable "subnets"                { default = [] }
variable "min"                    { default = 1 }
variable "max"                    { default = 3 }
variable "desired"                { default = 2 }
variable "health_grace_period"    {}
variable "cluster"                {}
variable "profile"                {}
variable "group"                  {}
variable "log_group"              {}
variable "instance_type"          {}
variable "key_name"               {}
variable "network_filesystem"     {}

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
  template = "${file("${path.module}/configs/core-os.yml")}"

  vars {
    aws_region         = "${var.region}"
    ecs_cluster_name   = "${var.cluster}"
    ecs_log_level      = "info"
    ecs_agent_version  = "latest"
    ecs_log_group_name = "${var.log_group}"
    efs_ip_address     = "${var.network_filesystem}"
  }
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
  security_groups             = ["${var.group}",]
  key_name                    = "${var.key_name}"
  image_id                    = "${data.aws_ami.default.id}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${var.profile}"
  user_data                   = "${data.template_file.cloud_config.rendered}"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# Autoscaling Groups
# ==============================================================================

resource "aws_autoscaling_group" "default" {
  name                        = "chaturbate-autoscaling-group"
  vpc_zone_identifier         = ["${var.subnets}"]
  min_size                    = "${var.min}"
  max_size                    = "${var.max}"
  desired_capacity            = "${var.desired}"
  launch_configuration        = "${aws_launch_configuration.default.name}"
  health_check_type           = "ELB"
  health_check_grace_period   = "${var.health_grace_period}"

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  tag {
    key                 = "Name"
    value               = "Chaturbate Instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "for"
    value               = "chaturbate"
    propagate_at_launch = true
  }
}