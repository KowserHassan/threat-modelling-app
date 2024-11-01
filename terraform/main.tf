## VPC Resources
resource "aws_vpc" "threatvpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "tmpublicsubnet1" {
  vpc_id            = aws_vpc.threatvpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "tmpublicsubnet1"
  }
}

resource "aws_subnet" "tmpublicsubnet2" {
  vpc_id            = aws_vpc.threatvpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-2b"

  tags = {
    Name = "tmpublicsubnet2"
  }
  
}

# Security Groups
resource "aws_security_group" "threatappsg" {
  vpc_id = aws_vpc.threatvpc.id

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
  ingress {
    from_port   = 3000
    to_port     = 3000
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
    Name = "threatappsg"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "threatapp_rt" {
  vpc_id = aws_vpc.threatvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.threatgw.id
  }
  tags = {
    Name = "threatapp_rt"
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "public_rt_assoc_subnet1" {
  subnet_id      = aws_subnet.tmpublicsubnet1.id
  route_table_id = aws_route_table.threatapp_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_subnet2" {
  subnet_id      = aws_subnet.tmpublicsubnet2.id
  route_table_id = aws_route_table.threatapp_rt.id
}
resource "aws_internet_gateway" "threatgw" {
  vpc_id = aws_vpc.threatvpc.id

  tags = {
    Name = "threatgw"
  }
}

## ECS Resources
resource "aws_ecs_cluster" "threatecs" {
  name = "threatecs"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Task Definitions
resource "aws_ecs_task_definition" "threatservice" {
  family                   = "service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = data.aws_iam_role.ecs_task_execution_role.arn
  cpu                      = 1024
  memory                   = 3072

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "threatcontainer"
      image     = "183295408140.dkr.ecr.eu-west-2.amazonaws.com/threatappdeployment:latest"
      cpu       = 1024
      memory    = 3072
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
    },
  ])
}


# ECS Service

resource "aws_ecs_service" "threat_app_service" {
  name            = "threatcontainer"
  cluster         = aws_ecs_cluster.threatecs.id
  task_definition = aws_ecs_task_definition.threatservice.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = [aws_subnet.tmpublicsubnet1.id, aws_subnet.tmpublicsubnet2.id]
    security_groups  = [aws_security_group.threatappsg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.threatapptg.arn
    container_name   = "threatcontainer"
    container_port   = 3000
  }

  deployment_controller {
    type = "ECS"
  }

  depends_on = [aws_lb_listener.http_listener, aws_lb_listener.https_listener]
}

# Target Groups
resource "aws_lb_target_group" "threatapptg" {
  name        = "threatapptg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.threatvpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    protocol            = "HTTP"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [aws_lb.threat_app_lb]
}


# ALB Resources
resource "aws_lb" "threat_app_lb" {
  name               = "threat-app-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.tmpublicsubnet1.id, aws_subnet.tmpublicsubnet2.id]
  security_groups    = [aws_security_group.threatappsg.id]

  tags = {
    Name = "threat-app-alb"
  }
}

# # Fetch the ACM certificate after it’s validated and issued
variable "certificate_arn" {
  default = "arn:aws:acm:eu-west-2:183295408140:certificate/ce3791b3-c8a5-445f-8124-ddb8851ddbfb"

}

# HTTP Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.threat_app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

# ALB for HTTPS Listener
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.threat_app_lb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.threatapptg.arn
  }
}

# IAM
data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# Attach the ECS Task Execution Policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}