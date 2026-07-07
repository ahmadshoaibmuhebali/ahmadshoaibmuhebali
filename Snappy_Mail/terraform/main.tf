# ==========================================
# EXISTING LAB NETWORK LOOKUPS
# ==========================================
data "aws_vpc" "default" {
  id = "vpc-0d89e2f9a58287f88"
}

# ONLY look up the existing subnets that are physically located in the stable zones
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  # This explicitly skips us-east-1e and ensures t3.medium can launch smoothly
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
}

# ==========================================
# SECURITY GROUPS
# ==========================================
resource "aws_security_group" "ec2_sg" {
  name        = "stalwart-ec2-sg"
  description = "Allow mail traffic and SSH inside default VPC"
  vpc_id      = data.aws_vpc.default.id

  # Mail and HTTP web management ports
  dynamic "ingress" {
    for_each = [25, 465, 587, 443, 143, 993, 80, 8080]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # SSH Access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all internal traffic between Swarm nodes for mesh overlay networking
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "stalwart-ec2-sg" }
}

# ==========================================
# EC2 INSTANCES (3x Cluster Nodes)
# ==========================================
resource "aws_instance" "swarm_nodes" {
  count         = 3
  ami           = "ami-091138d0f0d41ff90" # Ubuntu 24.04 LTS us-east-1
  instance_type = "t3.medium"

  # Cycles placements strictly through your safe, filtered subnets list
  subnet_id              = element(data.aws_subnets.default.ids, count.index)
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - apt-transport-https
      - ca-certificates
      - curl
      - gnupg
      - lsb-release
    runcmd:
      - install -m 0755 -d /etc/apt/keyrings
      - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      - chmod a+r /etc/apt/keyrings/docker.asc
      - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
      - apt-get update -y
      - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      - systemctl enable docker
      - systemctl start docker
      - usermod -aG docker ubuntu
  EOF

  tags = {
    Name = "swarm-node-${count.index}"
    Role = count.index == 0 ? "manager" : "worker"
  }
}

# ==========================================
# STATIC ELASTIC IP FOR MANAGER
# ==========================================
resource "aws_eip" "manager_eip" {
  instance = aws_instance.swarm_nodes[0].id
  domain   = "vpc"
  tags     = { Name = "stalwart-manager-eip" }
}

# ==========================================
# OUTPUTS
# ==========================================
output "manager_public_ip" {
  description = "Static public IP of the manager node"
  value       = aws_eip.manager_eip.public_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = [aws_instance.swarm_nodes[1].public_ip, aws_instance.swarm_nodes[2].public_ip]
}

output "ec2_private_ips" {
  description = "Private internal IPs for Swarm Cluster setup"
  value       = aws_instance.swarm_nodes[*].private_ip
}