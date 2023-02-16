locals {
  target_groups_defaults = {
    cookie_duration                  = 86400
    deregistration_delay             = 300
    health_check_interval            = 10
    health_check_healthy_threshold   = 3
    health_check_path                = "/"
    health_check_port                = "traffic-port"
    health_check_timeout             = 5
    health_check_unhealthy_threshold = 3
    health_check_matcher             = "200-299,400"
    stickiness_enabled               = true
    target_type                      = "instance"
    slow_start                       = 0
  }
}

locals {
  instance_id = aws_instance.default[0].id
}


data "aws_route53_zone" "this" {
  name         = var.dns_zone_name
  private_zone = false
}

module "label_alb" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  attributes = ["loadbalancer"]
  context    = module.this.context
}


resource "aws_security_group" "public_load_balancer" {
  vpc_id = module.vpc[0].vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = module.label_alb.tags
}

resource "aws_lb" "application" {
  # aws lb names are limited to 32 chars
  name               = substr(module.label_alb.id, 0, min(length(module.label_alb.id), 32))
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.public_load_balancer.id]
  subnets = [
    module.dynamic_subnet[0].public_subnet_ids[0],
    module.dummy_subnet[0].public_subnet_ids[0]
  ]
  idle_timeout                     = "60"
  enable_cross_zone_load_balancing = false
  enable_deletion_protection       = false # var.is_prod_like
  enable_http2                     = true
  ip_address_type                  = "ipv4"

  access_logs {
    enabled = true
    bucket  = aws_s3_bucket.log_bucket.id
    prefix  = module.label_alb.id
  }

  timeouts {
    create = "30m"
    delete = "30m"
    update = "30m"
  }

  tags = module.label_alb.tags
  depends_on = [
    aws_s3_bucket_policy.alb_log_bucket
  ]
}

resource "aws_lb" "network" {
  # aws lb names are limited to 32 chars
  name               = substr(module.label_alb.id, 0, min(length(module.label_alb.id), 32))
  load_balancer_type = "network"
  internal           = false
  subnets = [
    module.dynamic_subnet[0].public_subnet_ids[0],
    module.dummy_subnet[0].public_subnet_ids[0]
  ]
  idle_timeout                     = "60"
  enable_cross_zone_load_balancing = false
  enable_deletion_protection       = var.stage == "prod"
  ip_address_type                  = "ipv4"

  timeouts {
    create = "30m"
    delete = "30m"
    update = "30m"
  }

  tags = module.label_alb.tags
}

resource "aws_lb_target_group" "ipfs_swarm" {
  name                 = "ipfs-swarm"
  vpc_id               = module.vpc[0].vpc_id
  port                 = "4001"
  protocol             = "TCP"
  deregistration_delay = local.target_groups_defaults["deregistration_delay"]
  target_type          = local.target_groups_defaults["target_type"]
  slow_start           = local.target_groups_defaults["slow_start"]

  health_check {
    protocol            = "TCP"
    interval            = local.target_groups_defaults["health_check_interval"]
    port                = local.target_groups_defaults["health_check_port"]
    healthy_threshold   = local.target_groups_defaults["health_check_healthy_threshold"]
    unhealthy_threshold = local.target_groups_defaults["health_check_unhealthy_threshold"]
    timeout             = local.target_groups_defaults["health_check_timeout"]
  }

  depends_on = [aws_lb.network]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    module.label_alb.tags,
    {
      "Name" = format("%s%s%s", module.label_alb.id, module.this.delimiter, "ipfs_swarm")
    },
  )
}

resource "aws_lb_target_group" "ipfs_api" {
  name                 = "ipfs-api"
  vpc_id               = module.vpc[0].vpc_id
  port                 = "5001"
  protocol             = "HTTP"
  deregistration_delay = local.target_groups_defaults["deregistration_delay"]
  target_type          = local.target_groups_defaults["target_type"]
  slow_start           = local.target_groups_defaults["slow_start"]

  health_check {
    protocol            = "HTTP"
    interval            = local.target_groups_defaults["health_check_interval"]
    port                = local.target_groups_defaults["health_check_port"]
    healthy_threshold   = local.target_groups_defaults["health_check_healthy_threshold"]
    unhealthy_threshold = local.target_groups_defaults["health_check_unhealthy_threshold"]
    timeout             = local.target_groups_defaults["health_check_timeout"]
    matcher             = local.target_groups_defaults["health_check_matcher"]
  }

  depends_on = [aws_lb.application]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    module.label_alb.tags,
    {
      "Name" = format("%s%s%s", module.label_alb.id, module.this.delimiter, "ipfs_api")
    },
  )
}
resource "aws_lb_target_group" "ipfs_pinning" {
  name                 = "ipfs-pinning"
  vpc_id               = module.vpc[0].vpc_id
  port                 = "9097"
  protocol             = "HTTP"
  deregistration_delay = local.target_groups_defaults["deregistration_delay"]
  target_type          = local.target_groups_defaults["target_type"]
  slow_start           = local.target_groups_defaults["slow_start"]

  health_check {
    protocol            = "HTTP"
    path                = "/pins"
    interval            = local.target_groups_defaults["health_check_interval"]
    port                = local.target_groups_defaults["health_check_port"]
    healthy_threshold   = local.target_groups_defaults["health_check_healthy_threshold"]
    unhealthy_threshold = local.target_groups_defaults["health_check_unhealthy_threshold"]
    timeout             = local.target_groups_defaults["health_check_timeout"]
    matcher             = local.target_groups_defaults["health_check_matcher"]
  }

  depends_on = [aws_lb.application]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    module.label_alb.tags,
    {
      "Name" = format("%s%s%s", module.label_alb.id, module.this.delimiter, "ipfs_pinning")
    },
  )
}

resource "aws_lb_target_group" "ipfs_gateway" {
  name                 = "ipfs-gateway"
  vpc_id               = module.vpc[0].vpc_id
  port                 = "8080"
  protocol             = "HTTP"
  deregistration_delay = local.target_groups_defaults["deregistration_delay"]
  target_type          = local.target_groups_defaults["target_type"]
  slow_start           = local.target_groups_defaults["slow_start"]

  health_check {
    protocol            = "HTTP"
    path                = "/ipfs/"
    interval            = local.target_groups_defaults["health_check_interval"]
    port                = local.target_groups_defaults["health_check_port"]
    healthy_threshold   = local.target_groups_defaults["health_check_healthy_threshold"]
    unhealthy_threshold = local.target_groups_defaults["health_check_unhealthy_threshold"]
    timeout             = local.target_groups_defaults["health_check_timeout"]
    matcher             = local.target_groups_defaults["health_check_matcher"]
  }

  depends_on = [aws_lb.application]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    module.label_alb.tags,
    {
      "Name" = format("%s%s%s", module.label_alb.id, module.this.delimiter, "ipfs_gateway")
    },
  )
}

resource "aws_acm_certificate" "ipfs_certificate" {
  domain_name = var.domain_name
  subject_alternative_names = [
    "DNS:pinning.${var.domain_name}",
    "DNS:gateway.${var.domain_name}",
  ]
  validation_method = "DNS"

  tags = module.label_alb.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  provider = aws.dns
  for_each = {
    for dvo in aws_acm_certificate.ipfs_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "ipfs_certificate" {
  certificate_arn         = aws_acm_certificate.ipfs_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

resource "aws_lb_listener" "network_listener" {
  load_balancer_arn = aws_lb.network.arn
  port              = "4001"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.ipfs_swarm.id
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "network_listener" {
  target_group_arn = aws_lb_target_group.ipfs_swarm.arn
  target_id        = local.instance_id
}

resource "aws_lb_listener" "application_listener" {
  load_balancer_arn = aws_lb.application.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.ipfs_certificate.arn
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"

  default_action {
    target_group_arn = aws_lb_target_group.ipfs_api.id
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "ipfs_api" {
  listener_arn = aws_lb_listener.application_listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ipfs_api.arn
  }

  condition {
    host_header {
      values = ["api.${var.domain_name}"]
    }
  }
}

resource "aws_lb_target_group_attachment" "ipfs_api" {
  target_group_arn = aws_lb_target_group.ipfs_api.arn
  target_id        = local.instance_id
}

resource "aws_lb_listener_rule" "ipfs_pinning" {
  listener_arn = aws_lb_listener.application_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ipfs_pinning.arn
  }

  condition {
    host_header {
      values = ["pinning.${var.domain_name}"]
    }
  }
}

resource "aws_lb_target_group_attachment" "ipfs_pinning" {
  target_group_arn = aws_lb_target_group.ipfs_pinning.arn
  target_id        = local.instance_id
}

resource "aws_lb_listener_rule" "ipfs_gateway" {
  listener_arn = aws_lb_listener.application_listener.arn
  priority     = 101

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ipfs_gateway.arn
  }

  condition {
    host_header {
      values = ["gateway.${var.domain_name}"]
    }
  }
}

resource "aws_lb_target_group_attachment" "ipfs_gateway" {
  target_group_arn = aws_lb_target_group.ipfs_gateway.arn
  target_id        = local.instance_id
}

resource "aws_route53_record" "swarm" {
  provider = aws.dns
  name     = "swarm.${var.domain_name}"
  type     = "CNAME"
  records  = [aws_lb.network.dns_name]
  zone_id  = data.aws_route53_zone.this.id
}

resource "aws_route53_record" "cluster" {
  provider = aws.dns
  for_each = [
    var.domain_name,
    "pinning.${var.domain_name}",
    "gateway.${var.domain_name}"
  ]
  name    = each.value
  type    = "CNAME"
  records = [aws_lb.application.dns_name]
  zone_id = data.aws_route53_zone.this.id
}
