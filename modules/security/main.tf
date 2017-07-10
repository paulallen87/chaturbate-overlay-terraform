variable "access_key"               {}
variable "secret_key"               {}
variable "region"                   { default = "us-east-1" }
variable "public_key_path"          {}
variable "instance_log_group_arn"   {}
variable "container_log_group_arn"  {}

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

data "template_file" "instance_profile_policy" {
  template = "${file("${path.module}/policies/instance-policy.json")}"

  vars {
    instance_log_group_arn = "${var.instance_log_group_arn}"
    container_log_group_arn = "${var.container_log_group_arn}"
  }
}

data "template_file" "instance_policy" {
  template = "${file("${path.module}/policies/assume-policy.json")}"

  vars {
    service = "ec2.amazonaws.com"
  }
}

data "template_file" "loadbalancer_profile_policy" {
  template = "${file("${path.module}/policies/loadbalancer-policy.json")}"

  vars {}
}

data "template_file" "loadbalancer_policy" {
  template = "${file("${path.module}/policies/assume-policy.json")}"

  vars {
    service = "ecs.amazonaws.com"
  }
}

# ==============================================================================
# IAM Roles
# ==============================================================================

resource "aws_iam_role" "instance" {
  name = "chaturbate_instance_role"
  assume_role_policy = "${data.template_file.instance_policy.rendered}"
}

resource "aws_iam_role" "loadbalancer" {
  name = "chaturbate_loadbalancer_role"
  assume_role_policy = "${data.template_file.loadbalancer_policy.rendered}"
}

# ==============================================================================
# IAM Role Policies
# ==============================================================================

resource "aws_iam_role_policy" "instance" {
  name   = "chaturbate_instance_policy"
  role   = "${aws_iam_role.instance.name}"
  policy = "${data.template_file.instance_profile_policy.rendered}"
}

resource "aws_iam_role_policy" "loadbalancer" {
  name = "chaturbate_loadbalancer_policy"
  role = "${aws_iam_role.loadbalancer.name}"
  policy = "${data.template_file.loadbalancer_profile_policy.rendered}"
}

# ==============================================================================
# IAM Instance Profiles
# ==============================================================================

resource "aws_iam_instance_profile" "default" {
  name  = "chaturbate"
  role = "${aws_iam_role.instance.name}"
}

# ==============================================================================
# Key Pairs
# ==============================================================================

resource "aws_key_pair" "default" {
  key_name   = "chaturbate"
  public_key = "${file(var.public_key_path)}"
}

# ==============================================================================
# Output
# ==============================================================================

output "profile_name" {
  value = "${aws_iam_instance_profile.default.name}"
}

output "loadbalancer_arn" {
  value = "${aws_iam_role.loadbalancer.arn}"
}

output "key_pair_name" {
  value = "${aws_key_pair.default.key_name}"
}