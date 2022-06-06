# provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# aws provider
provider "aws" {
  region = var.region
}

# Variables list
variable "region" {
  default = "ap-southeast-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_1_cidr" {
  default = "10.0.1.0/24"
}

variable "ec2_instance_type" {
  default = "t2.micro"
}

variable "aws_amazon_ami_id" {
  default = "ami-0bd6906508e74f692"
}
# End of Variables list 

# create vpc for vulnerable application
resource "aws_vpc" "vulnerable-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    "Name" = "vulnerable-vpc"
  }
}

# create subnet
resource "aws_subnet" "subnet-1" {
  vpc_id                  = aws_vpc.vulnerable-vpc.id
  cidr_block              = var.subnet_1_cidr
  map_public_ip_on_launch = true

  tags = {
    "Name" = "subnet-1"
  }
}

# create route table
resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.vulnerable-vpc.id

  tags = {
    "Name" = "public-route-table"
  }
}

# associate subnet with Route Table
resource "aws_route_table_association" "public-subnet-1-association" {
  route_table_id = aws_route_table.public-route-table.id
  subnet_id      = aws_subnet.subnet-1.id
}

# create internet gateway
resource "aws_internet_gateway" "vpc-igw" {
  vpc_id = aws_vpc.vulnerable-vpc.id
  tags = {
    "Name" = "VPC-IGW"
  }
}

# internet gateway route
resource "aws_route" "vpc-igw-route" {
  route_table_id         = aws_route_table.public-route-table.id
  gateway_id             = aws_internet_gateway.vpc-igw.id
  destination_cidr_block = "0.0.0.0/0"
}

# aws key pair for ssh into ec2 instance
resource "aws_key_pair" "ssh_key" {
  key_name   = "secondary-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCxoiXHiI1ANMR455jJwCzWVoMiI+8ofU25FB+nPYfHK5uPh5m3pe9CS13XZPl8VzWTuntCHXkzTpbKRGJinoXaHzmGp662CK/w2Yvp/BNc1B5hcEdwTM/MO+rsFkIGzEmapqeMgs5rs85keJrlY903MMjh4Ub6GeUIjhjFDpDmP+rCUk/BDu2+ql03Pfji9quVUSgZMa95JPEQAgdUZXsf5cCvA+7bnuF64vFEJESPRWpbD/ms2r+PIaHQgQIYDuT7q2vqVqdkrKki5NnDlMmy8zpdM/mRiSzDTyoIURBfHxFjRwMBqDjXLOncQJ7xUld1IEY3xJj3HhIziQHftlG5"
}

# create security group to allow all ports and all protocols
resource "aws_security_group" "ec2-open-sg" {
  name   = "ec2-open-sg"
  vpc_id = aws_vpc.vulnerable-vpc.id

  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "SG-IN"
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = -1
    security_groups  = []
    self             = false
    to_port          = 0
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "SG-OUT"
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = -1
    self             = false
    security_groups  = []
    to_port          = 0
  }]

}

# create a network interface with an ip in the subnet that was created above
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.ec2-open-sg.id]

}
# assign an elastic IP to the network interface created 
resource "aws_eip" "eip-1" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.vpc-igw]
}

# create amazon linux server and run docker for jndi
# fields below should be used if network_interface is removed
# subnet_id       = aws_subnet.subnet-1.id
# security_groups = [aws_security_group.ec2-open-sg.id]
resource "aws_instance" "jndiexploit-server" {
  ami           = var.aws_amazon_ami_id
  instance_type = var.ec2_instance_type
  key_name      = aws_key_pair.ssh_key.key_name
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo yum install docker -y
              sudo systemctl start docker.service
              MY_IP=$(curl ipconfig.io)
              sudo docker run --name jndi -p 8888:8888 -p 1389:1389 -e IP=$MY_IP raphaelkw/jndiexploit
              EOF

}

# output public ip address for jndi server
output "jndi-publicip" {
  value = aws_instance.jndiexploit-server.public_ip
}

# create amazon linux server and run docker for log4shellapp
resource "aws_instance" "log4shellapp" {
  ami             = var.aws_amazon_ami_id
  instance_type   = var.ec2_instance_type
  key_name        = aws_key_pair.ssh_key.key_name
  subnet_id       = aws_subnet.subnet-1.id
  security_groups = [aws_security_group.ec2-open-sg.id]
  user_data       = <<-EOF
              #!/bin/bash
              sudo yum install docker -y
              sudo systemctl start docker.service
              sudo docker run --name log4shellapp -p 8080:8080 raphaelkw/log4shellapp
              EOF
}

# output public ip address for log4shell app
output "log4shellapp-publicip" {
  value = aws_instance.log4shellapp.public_ip
}
















