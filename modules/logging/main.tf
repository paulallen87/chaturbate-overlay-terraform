variable "access_key"             {}
variable "secret_key"             {}
variable "region"                 { default = "us-east-1" }

# ==============================================================================
# Providers
# ==============================================================================

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# ==============================================================================
# Log Groups
# ==============================================================================

resource "aws_cloudwatch_log_group" "container" {
  name = "chaturbate/container"

  tags {
    Name  = "Chaturbate Container Log Group"
    for   = "chaturbate"
  }
}

resource "aws_cloudwatch_log_group" "instance" {
  name = "chaturbate/instance"

  tags {
    Name  = "Chaturbate Instance Log Group"
    for   = "chaturbate"
  }
}

# ==============================================================================
# Output
# ==============================================================================

output "instance_group_name" {
  value = "${aws_cloudwatch_log_group.instance.name}"
}

output "instance_group_arn" {
  value = "${aws_cloudwatch_log_group.instance.arn}"
}

output "container_group_name" {
  value = "${aws_cloudwatch_log_group.container.name}"
}

output "container_group_arn" {
  value = "${aws_cloudwatch_log_group.container.arn}"
}