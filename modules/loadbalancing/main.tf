variable "access_key"             {}
variable "secret_key"             {}
variable "region"                 { default = "us-east-1" }
variable "subnets"                { default = [] }
variable "vpc_id"                 {}
variable "security_group"         {}
variable "protocol"               {}
variable "port"                   {}
variable "health_interval"        {}
variable "health_timeout"         {}
variable "healthy_threshold"      {}
variable "unhealthy_threshold"    {}

# ==============================================================================
# Providers
# ==============================================================================

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# ==============================================================================
# Load Balancers
# ==============================================================================

resource "aws_alb" "default" {
  name            = "chaturbate-loadbalancer"
  subnets         = ["${var.subnets}"]
  security_groups = ["${var.security_group}"]

  tags {
    for   = "chaturbate"
  }
}

# ==============================================================================
# Load Balancer Target Groups
# ==============================================================================

resource "aws_alb_target_group" "default" {
  name     = "chaturbate-target-group"
  protocol = "${var.protocol}"
  port     = "${var.port}"
  vpc_id   = "${var.vpc_id}"

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  health_check {
    interval            = "${var.health_interval}"
    path                = "/"
    protocol            = "${var.protocol}"
    timeout             = "${var.health_timeout}"
    healthy_threshold   = "${var.healthy_threshold}"
    unhealthy_threshold = "${var.unhealthy_threshold}"
    matcher             = "200-299"
  }

  tags {
    for   = "chaturbate"
  }
}

# ==============================================================================
# Load Balancer Listeners
# ==============================================================================

resource "aws_alb_listener" "default" {
  load_balancer_arn = "${aws_alb.default.arn}"
  port              = "${var.port}"
  protocol          = "${var.protocol}"

  default_action {
    target_group_arn = "${aws_alb_target_group.default.arn}"
    type             = "forward"
  }
}

# ==============================================================================
# Output
# ==============================================================================

output "target_group_arn" {
  value = "${aws_alb_target_group.default.arn}"

  depends_on = ["aws_alb_listener.default"]
}

output "dns_name" {
  value = "${aws_alb.default.dns_name}"
}

output "zone_id" {
  value = "${aws_alb.default.zone_id}"
}
