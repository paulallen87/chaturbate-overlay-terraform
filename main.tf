variable "access_key"       {}
variable "secret_key"       {}
variable "public_key_path"  {}
variable "region"           { default = "us-east-1" }
variable "cluster"          { default = "chaturbate" }

# ==============================================================================
# Providers
# ==============================================================================

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# ==============================================================================
# Modules
# ==============================================================================

module "security" {
  source                  = "./modules/security"
  access_key              = "${var.access_key}"
  secret_key              = "${var.secret_key}"
  public_key_path         = "${var.public_key_path}"
  region                  = "${var.region}"
  instance_log_group_arn  = "${module.logging.instance_group_arn}"
  container_log_group_arn = "${module.logging.container_group_arn}"
}

module "network" {
  source                  = "./modules/network"
  access_key              = "${var.access_key}"
  secret_key              = "${var.secret_key}"
  region                  = "${var.region}"
  cidr_block              = "100.100.0.0/16"
  az_count                = 3
  subnet_bits             = 8
}

module "filesystem" {
  source                  = "./modules/filesystem"
  access_key              = "${var.access_key}"
  secret_key              = "${var.secret_key}"
  region                  = "${var.region}"
  subnet                  = "${module.network.default_subnet_id}"

  groups = [
    "${module.network.instance_group_id}",
    "${module.network.filesystem_group_id}",
  ]
}

module "instances" {
  source                  = "./modules/instances"
  access_key              = "${var.access_key}"
  secret_key              = "${var.secret_key}"
  region                  = "${var.region}"
  cluster                 = "${var.cluster}"
  profile                 = "${module.security.profile_name}"
  key_name                = "${module.security.key_pair_name}"
  subnets                 = ["${module.network.instance_subnet_ids}"]
  group                   = "${module.network.instance_group_id}"
  log_group               = "${module.logging.instance_group_name}"
  network_filesystem      = "${module.filesystem.ip_address}"
  instance_type           = "t2.micro"
  min                     = 3
  max                     = 6
  desired                 = 4
  health_grace_period     = 300
}

module "loadbalancing" {
  source                  = "./modules/loadbalancing"
  access_key              = "${var.access_key}"
  secret_key              = "${var.secret_key}"
  region                  = "${var.region}"
  vpc_id                  = "${module.network.vpc_id}"
  subnets                 = ["${module.network.instance_subnet_ids}"]
  security_group          = "${module.network.loadbalancer_group_id}"
  protocol                = "HTTP"
  port                    = 80
  health_interval         = 30
  health_timeout          = 5
  healthy_threshold       = 5
  unhealthy_threshold     = 2
}

module "logging" {
  source                  = "./modules/logging"
  access_key              = "${var.access_key}"
  secret_key              = "${var.secret_key}"
  region                  = "${var.region}"
}

module "containers" {
  source                  = "./modules/containers"
  access_key              = "${var.access_key}"
  secret_key              = "${var.secret_key}"
  region                  = "${var.region}"
  cluster                 = "${var.cluster}"
  container_log_group     = "${module.logging.container_group_name}"

  chaturbate {
    loadbalancing_role    = "${module.security.loadbalancer_arn}"
    loadbalancing_group   = "${module.loadbalancing.target_group_arn}"
    image_url             = "paulallen87/chaturbate-overlay-app:latest"
    container_name        = "overlay-app"
    container_port        = 8080
    network_mode          = "bridge"
    certs_volume_path     = "/mnt/efs/chaturbate/certs"
    config_volume_path    = "/mnt/efs/chaturbate/config"
    desired_count         = 1
    cpu                   = 128
    memory                = 256
  }

  jenkins {
    image_url             = "blacklabelops/jenkins:latest"
    container_name        = "jenkins"
    container_port        = 8080
    agent_port            = 50000
    network_mode          = "bridge"
    volume_path           = "/mnt/efs/jenkins"
    desired_count         = 1
    cpu                   = 128
    memory                = 256
  }
}

module "domain" {
  source                  = "./modules/domain"
  access_key              = "${var.access_key}"
  secret_key              = "${var.secret_key}"
  region                  = "${var.region}"
  zone                    = "cb-overlays.com"
  dns_name                = "${module.loadbalancing.dns_name}"
  zone_id                 = "${module.loadbalancing.zone_id}"
  ttl                     = 300
}