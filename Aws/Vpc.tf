terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Configure the VPC
resource "aws_vpc" "terraformVPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "terra_VPC"
  }
}

# Public SubNet
resource "aws_subnet" "publicsubnet" {
  vpc_id     = aws_vpc.terraformVPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "publicsubnet"
  }
}
# Private SubNet
resource "aws_subnet" "privatesubnet" {
  vpc_id     = aws_vpc.terraformVPC.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "privatesubnet"
  }
}
# Internet gateway

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.terraformVPC.id

  tags = {
    Name = "IGW-terra"
  }
}
# Public Route Table
resource "aws_route_table" "publicrt" {
  vpc_id = aws_vpc.terraformVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
   tags = {
    Name = "publicRT"
  }
}

# Public Route Table Association
resource "aws_route_table_association" "publicrtassociation" {
  subnet_id      = aws_subnet.publicsubnet.id
  route_table_id = aws_route_table.publicrt.id
}
# Private Route Table
resource "aws_route_table" "privatert" {
  vpc_id = aws_vpc.terraformVPC.id

   tags = {
    Name = "privateRT"
  }
}
# Private Route Table Association
resource "aws_route_table_association" "privatertassociation" {
  subnet_id      = aws_subnet.privatesubnet.id
  route_table_id = aws_route_table.privatert.id
}

#  Public Security Group
resource "aws_security_group" "publicSG" {
 # name        = "allow_tls"
 # description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.terraformVPC.id

  tags = {
    Name = "publicsg"
  }
}
#  Public Security Group inbound and outbound rules
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.publicSG.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.publicSG.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_app" {
  security_group_id = aws_security_group.publicSG.id
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}


resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.publicSG.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


#  Private Security Group
resource "aws_security_group" "privateSG" {
 # name        = "allow_tls"
 # description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.terraformVPC.id

  tags = {
    Name = "privatesg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.privateSG.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.1.0/24"
}

# old method of Securit Group
# resource "aws_security_group" "allow_all" {
#   name        = "allow_all"
#   description = "Allow TLS inbound traffic"
#   vpc_id      = aws_vpc.terraformVPC.id

#   ingress {
#     description      = "TLS from VPC"
#     from_port        = 22
#     to_port          = 8080
#     protocol         = "tcp"
#     cidr_blocks      = ["0.0.0.0/0"]
#   }
#   egress {
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "allow_tcp"
#   }
# }

# Instance 
resource "aws_instance" "Instance-T"{
ami                            = "ami-0de716d6197524dd9"
instance_type                  = "t3.micro"
subnet_id                      = aws_subnet.publicsubnet.id
vpc_security_group_ids         = [aws_security_group.publicSG.id]
key_name                       = "kube"   #key name which you have 
associate_public_ip_address    = true 
 #iam_instance_profile          = "Terraform_role"
}

