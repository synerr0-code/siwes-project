provider "aws" {
  region = "us-east-1"
  # Hardcoded credentials removed. GitHub Actions will inject them securely via environment variables.
}

# --- VARIABLES ---
variable "app_ami_id" { 
  description = "The AMI ID generated dynamically by Packer" 
  type        = string
}

variable "target_env" { 
  description = "The target environment for the deployment (blue or green)" 
  type        = string
}

# --- VPC & NETWORKING ---
resource "aws_vpc" "siwes" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "siwes_project" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.siwes.id
  tags = { Name = "siwes_igw" }
}

# Public Subnets
resource "aws_subnet" "pub-subnet1a" {
  vpc_id                  = aws_vpc.siwes.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true 
  tags = { Name = "SIWES Public subnet A" }
}

resource "aws_subnet" "pub-subnet_1b" {
  vpc_id                  = aws_vpc.siwes.id
  cidr_block              = "10.0.2.0/24" 
  availability_zone       = "us-east-1b"  
  map_public_ip_on_launch = true 
  tags = { Name = "SIWES Public subnet B" }
}

# Private Subnets
resource "aws_subnet" "priv-subnet_1a" {
  vpc_id            = aws_vpc.siwes.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "SIWES Private subnet A" }
}

resource "aws_subnet" "priv-subnet_1b" {
  vpc_id            = aws_vpc.siwes.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "SIWES Private subnet B" }
}

# NAT Gateway
resource "aws_eip" "eip_for_nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "siwes_nat" {
  allocation_id = aws_eip.eip_for_nat.id
  subnet_id     = aws_subnet.pub-subnet1a.id
  depends_on    = [aws_internet_gateway.igw]
  tags = { Name = "Siwes Nat gateway" }
}

# Route Tables
resource "aws_route_table" "traffic_to_igw" {
  vpc_id = aws_vpc.siwes.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "siwes-public-rt" }
}

resource "aws_route_table_association" "pub_association_1a" {
  subnet_id      = aws_subnet.pub-subnet1a.id
  route_table_id = aws_route_table.traffic_to_igw.id
}

resource "aws_route_table_association" "pub_association_1b" {
  subnet_id      = aws_subnet.pub-subnet_1b.id
  route_table_id = aws_route_table.traffic_to_igw.id
}

resource "aws_route_table" "traffic_to_nat" {
  vpc_id = aws_vpc.siwes.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.siwes_nat.id
  }
  tags = { Name = "siwes-private-rt" }
}

resource "aws_route_table_association" "priv_association_1a" {
  subnet_id      = aws_subnet.priv-subnet_1a.id
  route_table_id = aws_route_table.traffic_to_nat.id
}

resource "aws_route_table_association" "priv_association_1b" {
  subnet_id      = aws_subnet.priv-subnet_1b.id 
  route_table_id = aws_route_table.traffic_to_nat.id
}

# --- SECURITY GROUPS ---
# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "Application_Load_Balancer_Security_Group"
  description = "Allow HTTP/HTTPS inbound and all outbound"
  vpc_id      = aws_vpc.siwes.id
  tags = { Name = "alb_sg" }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# EC2 App Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "EC2_instances_security_group"
  description = "Allow ONLY inbound traffic from ALB"
  vpc_id      = aws_vpc.siwes.id
  tags = { Name = "EC2 security group from alb" }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ec2" {
  security_group_id            = aws_security_group.ec2_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = 80
  to_port                      = 80
  description                  = "Allow traffic from ALB only"
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_ec2_outbound" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- APPLICATION LOAD BALANCER ---
resource "aws_lb" "app_alb" {
  name               = "siwes-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.pub-subnet1a.id, aws_subnet.pub-subnet_1b.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No active environment routing"
      status_code  = "503"
    }
  }
}

resource "aws_lb_target_group" "blue" {
  name                 = "siwes-tg-blue"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_vpc.siwes.id
  deregistration_delay = 60

  health_check { path = "/health" }
}

resource "aws_lb_target_group" "green" {
  name                 = "siwes-tg-green"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_vpc.siwes.id
  deregistration_delay = 60

  health_check { path = "/health" }
}

# --- LAUNCH TEMPLATE & AUTO SCALING GROUPS ---
resource "aws_launch_template" "app" {
  name_prefix   = "siwes-node-"
  image_id      = var.app_ami_id
  instance_type = "t3.micro"
  
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
}

resource "aws_autoscaling_group" "blue" {
  name                = "siwes-asg-blue"
  vpc_zone_identifier = [aws_subnet.priv-subnet_1a.id, aws_subnet.priv-subnet_1b.id]
  target_group_arns   = [aws_lb_target_group.blue.arn]

  desired_capacity = var.target_env == "blue" ? 2 : 0
  min_size         = 0
  max_size         = 4

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_group" "green" {
  name                = "siwes-asg-green"
  vpc_zone_identifier = [aws_subnet.priv-subnet_1a.id, aws_subnet.priv-subnet_1b.id]
  target_group_arns   = [aws_lb_target_group.green.arn]

  desired_capacity = var.target_env == "green" ? 2 : 0
  min_size         = 0
  max_size         = 4

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}