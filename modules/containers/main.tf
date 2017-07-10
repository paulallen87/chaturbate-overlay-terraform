variable "access_key"                 {}
variable "secret_key"                 {}
variable "region"                     { default = "us-east-1" }
variable "cluster"                    { default = "chaturbate" }
variable "container_log_group"        {}

variable "chaturbate" {
  default = {
    loadbalancing_role  = ""
    loadbalancing_group = ""
    image_url           = ""
    container_name      = "app"
    container_port      = "8080"
    desired_count       = 1
    instance_type       = "t2.micro"
    network_mode        = "bridge"
    certs_volume_path   = ""
    config_volume_path  = ""
    cpu                 = 256
    memory              = 512
  }
}

variable "jenkins" {
  default = {
    image_url           = ""
    container_name      = "app"
    container_port      = "8080"
    agent_port          = "50000"
    desired_count       = 1
    instance_type       = "t2.micro"
    network_mode        = "bridge"
    volume_path         = ""
    cpu                 = 256
    memory              = 512
  }
}

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

data "template_file" "chaturbate_task_definition" {
  template = "${file("${path.module}/definitions/chaturbate.json")}"

  vars {
    image_url             = "${var.chaturbate["image_url"]}"
    cpu                   = "${var.chaturbate["cpu"]}"
    memory                = "${var.chaturbate["memory"]}"
    container_name        = "${var.chaturbate["container_name"]}"
    container_port        = "${var.chaturbate["container_port"]}"
    log_group_region      = "${var.region}"
    log_group_name        = "${var.container_log_group}",
    log_group_prefix      = "${var.chaturbate["container_name"]}"
  }
}

data "template_file" "jenkins_task_definition" {
  template = "${file("${path.module}/definitions/jenkins.json")}"

  vars {
    image_url             = "${var.jenkins["image_url"]}"
    cpu                   = "${var.jenkins["cpu"]}"
    memory                = "${var.jenkins["memory"]}"
    container_name        = "${var.jenkins["container_name"]}"
    container_port        = "${var.jenkins["container_port"]}"
    agent_port            = "${var.jenkins["agent_port"]}"
    log_group_region      = "${var.region}"
    log_group_name        = "${var.container_log_group}",
    log_group_prefix      = "${var.jenkins["container_name"]}"
  }
}

# ==============================================================================
# Clusters
# ==============================================================================

resource "aws_ecs_cluster" "default" {
  name = "${var.cluster}"
}

# ==============================================================================
# Task Definitions
# ==============================================================================

resource "aws_ecs_task_definition" "chaturbate" {
  family                = "${var.chaturbate["container_name"]}"
  network_mode          = "${var.chaturbate["network_mode"]}"
  container_definitions = "${data.template_file.chaturbate_task_definition.rendered}"

  volume = [
    {
      name = "certs"
      host_path = "${var.chaturbate["certs_volume_path"]}"
    },
    {
      name = "config"
      host_path = "${var.chaturbate["config_volume_path"]}"
    }
  ]
}

resource "aws_ecs_task_definition" "jenkins" {
  family                = "${var.jenkins["container_name"]}"
  network_mode          = "${var.jenkins["network_mode"]}"
  container_definitions = "${data.template_file.jenkins_task_definition.rendered}"

  volume = [
    {
      name = "jenkins"
      host_path = "${var.jenkins["volume_path"]}"
    }
  ]
}

# ==============================================================================
# Services
# ==============================================================================

resource "aws_ecs_service" "chaturbate" {
  name            = "overlay_app"
  cluster         = "${aws_ecs_cluster.default.id}"
  task_definition = "${aws_ecs_task_definition.chaturbate.arn}"
  desired_count   = "${var.chaturbate["desired_count"]}"
  iam_role        = "${var.chaturbate["loadbalancing_role"]}"

  load_balancer = {
    target_group_arn = "${var.chaturbate["loadbalancing_group"]}"
    container_name   = "${var.chaturbate["container_name"]}"
    container_port   = "${var.chaturbate["container_port"]}"
  }
}

resource "aws_ecs_service" "jenkins" {
  name            = "jenkins"
  cluster         = "${aws_ecs_cluster.default.id}"
  task_definition = "${aws_ecs_task_definition.jenkins.arn}"
  desired_count   = "${var.jenkins["desired_count"]}"
}