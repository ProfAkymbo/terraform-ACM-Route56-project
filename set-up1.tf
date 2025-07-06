# Configure the AWS Provider
provider "aws" {
  region = "us-east-1" 
}

# Define a variable for the AWS region
variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

# Create a Virtual Private Cloud (VPC)
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16" 
  enable_dns_hostnames = true # Enables DNS hostnames for instances in the VPC
  enable_dns_support   = true # Enables DNS resolution for the VPC

  tags = {
    Name = "AkTerraformVPC"
  }
}

# Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id # Attach the IGW to the VPC created above

  tags = {
    Name = "AkTerraformIGW"
  }
}

# Create a Route Table for the Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  # Route for internet access (0.0.0.0/0) through the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "AkTerraformPublicRouteTable"
  }
}

# Create a Public Subnet1
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24" 
  availability_zone       = "${var.aws_region}a" # Use the first AZ in the chosen region
  map_public_ip_on_launch = true # Automatically assign public IPs to instances launched in this subnet

  tags = {
    Name = "AkTerraformPublicSubnet"
  }
}

# Associate the Public Subnet with the Public Route Table for internet access
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create a Public Subnet2
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "AkTerraformPublicSubnet2"
  }
}

# Associate the Public Subnet2 with the Public Route Table for internet access
resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# 4. Create a Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24" # Another /24 subnet within the VPC's /16 CIDR
  availability_zone = "${var.aws_region}a" # Use the second AZ in the chosen region

  tags = {
    Name = "AKTerraformPrivateSubnet"
  }
}

# Create a Route Table for the Private Subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "AKTerraformPrivateRouteTable"
  }
}

# create Elastic IP
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "AK-EIP"
  }
}

# create Nat GW
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "AkTerraformNGw"
  }

  depends_on = [aws_internet_gateway.main_igw]
}



# Associate the Private Subnet with the Private Route Table
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

#Update private route table to send outbound traffic through the NAT Gateway
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

# Output the IDs of the created resources for easy reference
output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.main_vpc.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  description = "The ID of the private subnet"
  value       = aws_subnet.private_subnet.id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main_igw.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.nat_gw.id
}

output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = aws_route_table.public_route_table.id
}

output "private_route_table_id" {
  description = "The ID of the private route table"
  value       = aws_route_table.private_route_table.id
}
