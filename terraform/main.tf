# ---------- AMI: latest Ubuntu 24.04 (looked up, not hard-coded) ----------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ---------- Networking ----------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------- Security group (least privilege) ----------
resource "aws_security_group" "swarm" {
  name        = "${var.project_name}-swarm-sg"
  description = "Swarm nodes: SSH from admin, HTTP from anywhere, swarm ports inside the group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project_name}-swarm-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.swarm.id
  description       = "SSH from admin IP only"
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.swarm.id
  description       = "HTTP to the nginx load balancer"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "swarm_mgmt" {
  security_group_id            = aws_security_group.swarm.id
  description                  = "Swarm cluster management"
  referenced_security_group_id = aws_security_group.swarm.id
  ip_protocol                  = "tcp"
  from_port                    = 2377
  to_port                      = 2377
}

resource "aws_vpc_security_group_ingress_rule" "swarm_gossip_tcp" {
  security_group_id            = aws_security_group.swarm.id
  description                  = "Swarm node discovery (TCP)"
  referenced_security_group_id = aws_security_group.swarm.id
  ip_protocol                  = "tcp"
  from_port                    = 7946
  to_port                      = 7946
}

resource "aws_vpc_security_group_ingress_rule" "swarm_gossip_udp" {
  security_group_id            = aws_security_group.swarm.id
  description                  = "Swarm node discovery (UDP)"
  referenced_security_group_id = aws_security_group.swarm.id
  ip_protocol                  = "udp"
  from_port                    = 7946
  to_port                      = 7946
}

resource "aws_vpc_security_group_ingress_rule" "swarm_overlay" {
  security_group_id            = aws_security_group.swarm.id
  description                  = "Swarm overlay network (VXLAN)"
  referenced_security_group_id = aws_security_group.swarm.id
  ip_protocol                  = "udp"
  from_port                    = 4789
  to_port                      = 4789
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.swarm.id
  description       = "Outbound anywhere (package installs, Docker Hub pulls)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- SSH key pair (public key only; private key stays on your laptop) ----------
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.public_key_path))
}

# ---------- EC2 instances ----------
locals {
  user_data = file("${path.module}/user_data.sh")
}

resource "aws_instance" "manager" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.swarm.id]
  key_name               = aws_key_pair.deployer.key_name
  user_data              = local.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  tags = {
    Name = "${var.project_name}-manager"
    Role = "swarm-manager"
  }
}

resource "aws_instance" "worker" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.swarm.id]
  key_name               = aws_key_pair.deployer.key_name
  user_data              = local.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_name}-worker-${count.index + 1}"
    Role = "swarm-worker"
  }
}

# Stable public address for the manager (Jenkins deploys here; users can browse here).
resource "aws_eip" "manager" {
  instance   = aws_instance.manager.id
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags       = { Name = "${var.project_name}-manager-eip" }
}
