provider "aws" {
  region     = "us-east-1"
  access_key = "[ACCESS-KEY]"
  secret_key = "[SECRET-KEY]"
}

# 1. Create VPC
resource "aws_vpc" "production-vpc" {
  cidr_block = "10.0.0.0/16"
    tags = {
      Name = "production"
    }
}
# 2. Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.production-vpc.id
}

# 3. Create Custom Route Table
resource "aws_route_table" "production-route-table" {
  vpc_id = aws_vpc.production-vpc.id

  tags = {
    Name = "production-route-table"
  }
}
# 4. Create Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.production-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "production-subnet"
  }
}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.production-route-table.id
}

# 6. Create Security Group to allow ports 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.production-vpc.id

  tags = {
    Name = "allow_tls"
  }

  ingress {
    description = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# 7. Create a network interface with an IP in the subnet that was created in step 4
resource "aws_network_interface" "production-web-server" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.production-web-server.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

# 9. Create Ubuntu server and install/enable Apache2
resource "aws_instance" "web-server-instance" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  #key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.production-web-server.id
  }

  tags = {
    Name = "ubuntu-web-server"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo this was built using terraform > /var/www/html/index.html'
              EOF
}

resource "aws_s3_bucket" "production_bucket" {
  bucket = "my-tf-test-bucket"

  tags = {
    Name        = "My bucket"
    Environment = "Prod"
  }
}
