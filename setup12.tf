# Reference existing Route 53 Hosted Zone
data "aws_route53_zone" "main" {
#resource "aws_route53_zone" "main" {  # uncomment if this is not already existing to create it
  name = "practice.link"
}

# Configures a provider alias required for certificates used with ALB.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Requests anSSL certificate for the domain using DNS validation.
resource "aws_acm_certificate" "cert" {
  provider          = aws.us_east_1
  domain_name       = "ak.practice.link"
  validation_method = "DNS"

  tags = {
    Name = "AppCert"
  }
}

# DNS Validation Record
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => dvo
  }
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  zone_id = data.aws_route53_zone.main.zone_id
  records = [each.value.resource_record_value]
  ttl     = 300
}

# validates ACM Certificate.
resource "aws_acm_certificate_validation" "cert_validation" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# creates HTTPS Listener for ALB
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# creates Route 53 Alias Record pointing to ALB
resource "aws_route53_record" "app_alias" {
  #zone_id = aws_route53_zone.main.zone_id
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "ak.practice.link"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}
