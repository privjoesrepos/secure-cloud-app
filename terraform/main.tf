provider "aws" {
  region = "us-east-1"
}

# Generate a random suffix for our resource names
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# ==========================================
# NETWORKING LAYER
# ==========================================

# Create a custom VPC (isolated network in AWS)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "secure-app-vpc-${random_string.suffix.id}"
  }
}

# Create Public Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = { Name = "secure-app-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = { Name = "secure-app-public-b" }
}

# Create Private Subnet (For EC2 instance)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a" # Keep in one AZ to save free tier hours

  tags = { Name = "secure-app-private" }
}

# Create Isolated Subnet (For RDS - no internet access at all)
resource "aws_subnet" "isolated" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = { Name = "secure-app-isolated" }
}

resource "aws_subnet" "isolated_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.13.0/24" # the 13 to avoid overlapping with 3.0
  availability_zone = "us-east-1b"

  tags = { Name = "secure-app-isolated-b" }
}

# Internet Gateway (Allows VPC to talk to the outside world)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "secure-app-igw" }
}

# Route Table (Tells the public subnets to use the Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"   # All internet traffic
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "secure-app-public-rt" }
}

# Associate the public subnets with the public route table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ==========================================
# SECURITY GROUPS
# ==========================================

# ALB Security Group - Allows internet traffic to reach the Load Balancer
resource "aws_security_group" "alb" {
  name        = "secure-app-alb-sg"
  description = "Allows HTTP traffic from the internet"
  vpc_id      = aws_vpc.main.id

  # INBOUND RULE: Allow anyone on port 80 (HTTP)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # the whole internet
  }

  # OUTBOUND RULE: Allow the ALB to talk to things inside the VPC
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # all traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "secure-app-alb-sg" }
}

# EC2 Security Group (The app server) ONLY allows traffic from the ALB. Completely hidden from the internet.
resource "aws_security_group" "ec2" {
  name        = "secure-app-ec2-sg"
  description = "Allows traffic only from the ALB"
  vpc_id      = aws_vpc.main.id

  # INBOUND RULE: Only allow traffic on port 8080 IF it comes from the ALB SG
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # OUTBOUND RULE: Allow EC2 to talk to the database
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "secure-app-ec2-sg" }
}

# RDS Security Group (The database) ONLY allows traffic from the EC2 server. Maximum isolation.
resource "aws_security_group" "rds" {
  name        = "secure-app-rds-sg"
  description = "Allows traffic only from the EC2 instance"
  vpc_id      = aws_vpc.main.id

  # INBOUND RULE: Only allow traffic on port 3306 IF it comes from the EC2 SG
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # No INBOUND internet. No OUTBOUND internet. Completely locked down.
  tags = { Name = "secure-app-rds-sg" }
}

# ==========================================
# DATA LAYER (RDS MySQL)
# ==========================================

# Generate a secure, random password for the database
resource "random_password" "db_password" {
  length  = 16
  special = false # Avoid special chars that can break bash strings later
}

# Create the RDS Subnet Group, RDS requires a specific "Subnet Group" to know where it should live
resource "aws_db_subnet_group" "main" {
  name       = "secure-app-db-subnet-group"
  subnet_ids = [aws_subnet.isolated.id, aws_subnet.isolated_b.id]

  tags = { Name = "secure-app-db-subnet-group" }
}

# Create the RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "secure-app-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  
  # Credentials (Using the random password generated above)
  username = "dbadmin"
  password = random_password.db_password.result
  
  # Storage
  allocated_storage     = 20
  max_allocated_storage = 20   # Hard cap to prevent accidental charges
  storage_encrypted     = true # Free tier supports encryption

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # No internet access

  # Settings
  backup_retention_period = 0
  skip_final_snapshot = true # No backups for portfolio project (saves money/time)
  
  tags = { Name = "secure-app-mysql" }
}

# ==========================================
# CONTAINER REGISTRY (ECR)
# ==========================================

# Create the Elastic Container Registry
resource "aws_ecr_repository" "app" {
  name                 = "secure-app-repo"
  image_tag_mutability = "MUTABLE" # Allows us to overwrite the "latest" tag

  image_scanning_configuration {
    scan_on_push = true # AWS automatically scan for vulnerabilities
  }

  tags = { Name = "secure-app-ecr" }
}

# ECR Lifecycle Policy (Keep it clean and free)
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images immediately"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ==========================================
# COMPUTE LAYER (EC2)
# ==========================================

# IAM Role for the EC2 instance - This allows the instance to talk to AWS services securely (no passwords needed)
resource "aws_iam_role" "ec2_role" {
  name = "secure-app-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach the SSM (Systems Manager) policy - This is what allows GitHub Actions to run commands on the instance WITHOUT SSH!
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach ECR read-only policy - Allows the instance to pull the Docker image from ECR
resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Create the Instance Profile (Wraps the role so EC2 can use it)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "secure-app-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Create the EC2 Instance
resource "aws_instance" "app" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = "t3.micro" # Free Tier eligible!
  
  # Put it in public_a so it can download Docker via the Internet Gateway (FREE)
  subnet_id            = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  
  # Attach the IAM profile
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # This script runs once when the server boots for the very first time
  user_data = <<-EOF
              #!/bin/bash
              # Install Docker
              dnf update -y
              dnf install docker -y
              systemctl start docker
              systemctl enable docker
              # Add the default ec2-user to the docker group so it can run docker commands
              usermod -aG docker ec2-user
              EOF

  tags = {
    Name = "secure-app-ec2"
  }
}

# ==========================================
# LOAD BALANCER (ALB)
# ==========================================

# Create the Target Group - This tells the ALB WHERE to send traffic (to EC2 instance on port 8080)
resource "aws_lb_target_group" "app" {
  name     = "secure-app-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # The type of health check the ALB uses to verify the EC2 app is alive
  health_check {
    path                = "/health"
    interval            = 30 # Check every 30 seconds
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200" # Expect a 200 OK status code
  }
}

# Attach the EC2 instance to the Target Group
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 8080
}

# Create the Application Load Balancer itself
resource "aws_lb" "app" {
  name               = "secure-app-alb"
  internal           = false # Internal=false means it faces the internet
  load_balancer_type = "application"

  # The ALB MUST live in the public subnets to receive internet traffic
  subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups = [aws_security_group.alb.id]

  tags = { Name = "secure-app-alb" }
}

# Create the Listener - This tells the ALB to listen on port 80 and forward traffic to the Target Group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}