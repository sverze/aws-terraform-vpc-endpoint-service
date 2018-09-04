# Specify the provider and access details
#provider "aws" {
#  region                       = "${var.aws_region}"
#  profile                      = "${var.aws_profile}"
#}

data "template_file" "user_data" {
  template                     = "${file("${path.module}/user-data.sh")}"
}

data "aws_iam_policy_document" "application_iam_policy_document" {
  statement {
    actions                    = ["sts:AssumeRole"]

    principals {
      type                     = "Service"
      identifiers              = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "application_iam_role" {
  name                         = "application_instance_role"
  path                         = "/system/"
  assume_role_policy           = "${data.aws_iam_policy_document.application_iam_policy_document.json}"
}

resource "aws_iam_instance_profile" "application_iam_instance_profile" {
  name                         = "application_iam_instance_profile"
  role                         = "${aws_iam_role.application_iam_role.name}"
}

resource "aws_instance" "application_instance" {
  instance_type                = "${var.aws_instance_type}"
  ami                          = "${var.aws_ami}"
  key_name                     = "${var.aws_key_name}"
  vpc_security_group_ids       = ["${var.aws_security_group_id}"]
  subnet_id                    = "${var.aws_subnet_id}"
  associate_public_ip_address  = false
  iam_instance_profile         = "${aws_iam_instance_profile.application_iam_instance_profile.name}"
  user_data                    = "${data.template_file.user_data.rendered}"

  tags {
    Name                       = "${var.environment_name}_application"
  }
}


################  VPC Endpoint Services  ################


resource "aws_lb" "application_lb" {
  internal                     = true
  subnets                      = ["${var.aws_subnet_id}"]
  load_balancer_type           = "network"
  enable_deletion_protection   = false

  tags {
    Name                       = "${var.environment_name}_application_lb"
  }
}

resource "aws_lb_target_group" "application_lb_target_group" {
  port                         = 80
  protocol                     = "TCP"
  target_type                  = "instance"
  vpc_id                       = "${var.aws_vpc_id}"

  health_check {
    protocol                   = "HTTP"
    path                       = "/"
    port                       = 80
    healthy_threshold          = 3
    unhealthy_threshold        = 3
    interval                   = 30
  }

  stickiness {
    type                       = "lb_cookie"
    enabled                    = "false"
  }

  tags {
    Name                       = "${var.environment_name}_application_lb_target_group"
  }
}

resource "aws_lb_listener" "application_lb_listener" {
  load_balancer_arn            = "${aws_lb.application_lb.arn}"
  port                         = 80
  protocol                     = "TCP"

  default_action {
    target_group_arn           = "${aws_lb_target_group.application_lb_target_group.arn}"
    type                       = "forward"
  }
}

resource "aws_lb_target_group_attachment" "application_lb_target_group_attachment" {
  target_group_arn             = "${aws_lb_target_group.application_lb_target_group.arn}"
  target_id                    = "${aws_instance.application_instance.id}"
  port                         = 80
}

resource "aws_vpc_endpoint_service" "application_vpc_endpoint_service" {
  acceptance_required          = false
  network_load_balancer_arns   = ["${aws_lb.application_lb.arn}"]
}
