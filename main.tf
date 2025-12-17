provider "aws" {
  region = "eu-west-2" # Specify your desired AWS region
}


# 1.Creating a vpc
resource "aws_vpc" "oluwatech_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "oluwatech_vpc"
  }
}

# 2.Creating an internet gateway (allows vpc to communicate with internet)
resource "aws_internet_gateway" "oluwatech_gateway" {
  vpc_id = aws_vpc.oluwatech_vpc.id

  tags = {
    Name = "oluwatech_gateway"
  }
}

# 3.Creating the route table
resource "aws_route_table" "oluwatech_route_table" {
  vpc_id = aws_vpc.oluwatech_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.oluwatech_gateway.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.oluwatech_gateway.id

  }
  tags = {
    Name = "oluwatech_route_table"
  }
}


# 4.Creating the public & private subnets
resource "aws_subnet" "oluwatech_subnet" {
  vpc_id            = aws_vpc.oluwatech_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "eu-west-2a"
  depends_on        = [aws_internet_gateway.oluwatech_gateway]
  tags = {
    Name = "oluwatech_subnet"
  }
}

# resource "aws_subnet" "oluwatech_private_subnet" {
#   vpc_id            = aws_vpc.oluwatech_vpc.id
#   cidr_block        = "10.0.0.0/24"
#   availability_zone = "eu-west-2a"
#   depends_on        = [aws_internet_gateway.oluwatech_gateway]
#   tags = {
#     Name = "oluwatech_private_subnet"
#   }
# }

# 5.Associate Public Subnet with Route table
resource "aws_route_table_association" "oluwatech_to_subnet" {
  subnet_id      = aws_subnet.oluwatech_subnet.id
  route_table_id = aws_route_table.oluwatech_route_table.id
}

# 6.Create Security Groups (Allow ports 22,80,443)
resource "aws_security_group" "oluwatech_security_group" {
  name        = "oluwatech_security_group"
  description = "Allow SHH, HTTP  & HTTPS inbound traffic"
  vpc_id      = aws_vpc.oluwatech_vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    description = "SSH from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "oluwatech_security_group"
  }
}

# 7.Assign ENI (Elastic Network Interface) with IP
resource "aws_network_interface" "oluwatech_elatic_network_interface" {
  subnet_id       = aws_subnet.oluwatech_subnet.id
  private_ips     = ["10.0.0.10"]
  security_groups = [aws_security_group.oluwatech_security_group.id]
}

# 8.Assign Elastic IP to ENI 
resource "aws_eip" "oluwatech_elastic_ip" {
  network_interface         = aws_network_interface.oluwatech_elatic_network_interface.id
  associate_with_private_ip = "10.0.0.10"
  depends_on                = [aws_internet_gateway.oluwatech_gateway, aws_instance.oluwatech_Instance_A]

  tags = {
    Name = "oluwatech_elastic_ip"
  }
}

# 9. Create IAM Role to access S3
resource "aws_iam_role" "oluwatech_EC2-S3" {
  name = "oluwatech_EC2-S3"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = "oluwatech_EC2-S3"
  }
}

// IAM Profile
resource "aws_iam_instance_profile" "oluwatech_EC2-S3_Profile" {
  name = "oluwatech_EC2-S3_Profile"
  role = aws_iam_role.oluwatech_EC2-S3.name
}

// IAM Policy
resource "aws_iam_role_policy" "oluwatech_EC2-S3_Policy" {
  name = "test_policy"
  role = aws_iam_role.oluwatech_EC2-S3.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

}

# 10. Create Linux Server and install/enable Apache2
resource "aws_instance" "oluwatech_Instance_A" {
  ami                  = "ami-099400d52583dd8c4"
  instance_type        = "t2.micro"
  availability_zone    = "eu-west-2a"
  key_name             = "oluwatech"
  iam_instance_profile = aws_iam_instance_profile.oluwatech_EC2-S3_Profile.name

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.oluwatech_elatic_network_interface.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd.x86_64
    sudo systemctl start httpd.service
    sudo systemctl enable httpd.service
    sudo aws s3 sync s3://awsbucketbeta00/website /var/www/html 
  EOF

  tags = {
    Name = "oluwatech_1.0"
  }
}

# 11. Enable VPC Enpoint

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.oluwatech_vpc.id
  service_name = "com.amazonaws.eu-west-2.s3"

  tags = {
    Name = "test"
  }

}