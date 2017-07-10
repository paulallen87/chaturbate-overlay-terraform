variable "access_key"             {}
variable "secret_key"             {}
variable "region"                 { default = "us-east-1" }
variable "subnet"                 {}
variable "groups"                 { default = [] }

# ==============================================================================
# Providers
# ==============================================================================

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# ==============================================================================
# File Systems
# ==============================================================================

resource "aws_efs_file_system" "default" {
    performance_mode = "generalPurpose"

    tags {
        Name = "Chaturbate Shared Filesystem"
        for = "chaturbate"
    }
}

# ==============================================================================
# Mounts
# ==============================================================================

resource "aws_efs_mount_target" "default" {
  file_system_id  = "${aws_efs_file_system.default.id}"
  subnet_id       = "${var.subnet}"
  security_groups = ["${var.groups}"]
}

# ==============================================================================
# Output
# ==============================================================================

output "ip_address" {
  value = "${aws_efs_mount_target.default.ip_address}"
}