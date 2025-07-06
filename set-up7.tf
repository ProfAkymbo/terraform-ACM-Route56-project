# Security Group
resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow HTTP from ALB"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AKPrivateSG"
  }
}

# Launch Template for Auto Scaling Group
resource "aws_launch_template" "web_lt" {
  name_prefix   = "web-template-"
  image_id      = "ami-05ffe3c48a9991133" # Replace with a valid AMI ID in your region
  instance_type = "t3.micro"
  key_name = "AKtest"

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # This script is for Amazon Linux 2 or Amazon Linux 2023.
              # Update the system packages
              sudo yum update -y
              # Install Apache HTTP Server (httpd)
              sudo yum install -y httpd
              # Start the Apache service
              sudo systemctl start httpd
              # Enable Apache to start automatically on boot
              sudo systemctl enable httpd
              EOF
  )

  network_interfaces {
    associate_public_ip_address = false
    #subnet_id                   = aws_subnet.private_subnet.id
    security_groups             = [aws_security_group.private_sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "AKPrivateWebInstance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity     = 2
  max_size             = 2
  min_size             = 2
  vpc_zone_identifier  = [aws_subnet.private_subnet.id]
  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  tag {
    key                 = "Name"
    value               = "AKWebASGInstance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow inbound HTTP"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AKALBSG"
  }
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [aws_subnet.public_subnet.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "AKAppLB"
  }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-target-group"
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200"
  }

  tags = {
    Name = "AKWebTG"
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  lb_target_group_arn    = aws_lb_target_group.web_tg.arn
}

# Output the Load Balancer DNS name
output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
  description = "The DNS name of the Application Load Balancer"
}
