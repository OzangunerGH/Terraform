# Defining the cloud provider, region and credentials.
provider "aws" {
    region = "us-east-1"
    access_key = "AKIA2WN6MIIUBNROTPFO"
    secret_key = "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"
}

# Creating a Virtual Private Cloud
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
tags = {
    Name = "production"
  }
  }

# Creating a Internet Gateway for the VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "production"
  }
}
# Creating a Route Table for VPC and Adding Default Routes for Traffic
resource "aws_route_table" "prod-route-table" {
 vpc_id= aws_vpc.prod-vpc.id 

route {
  cidr_block = "0.0.0.0/0"
  gateway_id= aws_internet_gateway.gw.id
}
route {
  ipv6_cidr_block = "::/0"
  gateway_id= aws_internet_gateway.gw.id
}
}
# Creating a Subnet for the VPC
   resource "aws_subnet" "subnet-1" {
   vpc_id     = aws_vpc.prod-vpc.id
   cidr_block = "10.0.1.0/24"
   availability_zone = "us-east-1a"
   tags= {
   Name = "production"}
   }
   # Associating route table with the subnet created earlier.
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Creating a Security Group and Adding Inbound and Outbound Rules for Internet,SSH,ICMP access.
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web Inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

 ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

    ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
  ingress {
    description      = "ICMP"
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }


  tags = {
    Name = "allow_web"
  }
}
# Creating a network interface and associating it to security group.
resource "aws_network_interface" "nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}
# Creating an Elastic IP and associating it to network interface created earlier.
resource "aws_eip" "one" {
  network_interface = aws_network_interface.nic.id
  vpc      = true
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

# Creating an EC2 Instance and associating it to network interface and setting up an apache server with user data.
resource "aws_instance" "web-server-instance" {
  ami = "ami-0dfcb1ef8550277af"
  instance_type= "t2.micro"
  availability_zone = "us-east-1a"
  key_name= "main-key"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.nic.id
    }
    user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install php8.0 mariadb10.5
    sudo yum install -y httpd
    sudo systemctl start httpd
    sudo bash -c 'echo your very first web server >/var/www/html/index.html'
    EOF
    tags = {Name = "web-server"
    }
    }
    