variable "access_key"             {}
variable "secret_key"             {}
variable "region"                 { default = "us-east-1" }
variable "zone"                   {}
variable "dns_name"               {}
variable "zone_id"                {}
variable "ttl"                    {}

# ==============================================================================
# Providers
# ==============================================================================

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# ==============================================================================
# Zones
# ==============================================================================

resource "aws_route53_zone" "default" {
  name = "${var.zone}"
}

resource "aws_route53_zone" "dev" {
  name = "dev.${var.zone}"

  tags {
    Environment = "dev"
  }
}

# ==============================================================================
# Records
# ==============================================================================

resource "aws_route53_record" "dev-ns" {
  zone_id = "${aws_route53_zone.default.zone_id}"
  name    = "dev.${var.zone}"
  type    = "NS"
  ttl     = "30"

  records = [
    "${aws_route53_zone.dev.name_servers.0}",
    "${aws_route53_zone.dev.name_servers.1}",
    "${aws_route53_zone.dev.name_servers.2}",
    "${aws_route53_zone.dev.name_servers.3}",
  ]
}

resource "aws_route53_record" "default" {
  zone_id = "${aws_route53_zone.default.zone_id}"
  name = "${var.zone}"
  type = "A"

  alias {
    name = "${var.dns_name}"
    zone_id = "${var.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = "${aws_route53_zone.default.zone_id}"
  name = "www.${var.zone}"
  type = "A"

  alias {
    name = "${var.dns_name}"
    zone_id = "${var.zone_id}"
    evaluate_target_health = true
  }
}