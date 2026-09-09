resource "aws_vpc" "app_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.site_prefix}_prod_vpc"
  }
}

resource "aws_subnet" "app_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.aws_availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.site_prefix}_prod_subnet"
  }
}

resource "aws_subnet" "app_subnet_secondary" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.subnet_cidr_secondary
  availability_zone       = var.aws_availability_zone_secondary
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.site_prefix}_prod_subnet_secondary"
  }
}

resource "aws_internet_gateway" "app_gateway" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "${var.site_prefix}_prod_gateway"
  }
}

resource "aws_subnet" "app_private_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.subnet_private_cidr
  availability_zone       = var.aws_availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.site_prefix}_prod_private_subnet"
  }
}

resource "aws_subnet" "app_private_subnet_secondary" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.subnet_private_cidr_secondary
  availability_zone       = var.aws_availability_zone_secondary
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.site_prefix}_prod_private_subnet_secondary"
  }
}

resource "aws_eip" "nat" {
  vpc = true

  tags = {
    Name = "${var.site_prefix}_prod_nat_eip"
  }
}

resource "aws_nat_gateway" "app_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.app_subnet.id

  depends_on = [aws_internet_gateway.app_gateway]

  tags = {
    Name = "${var.site_prefix}_prod_nat"
  }
}

resource "aws_route_table" "app_route_table" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_gateway.id
  }

  tags = {
    Name = "${var.site_prefix}_prod_route_table"
  }
}

resource "aws_route_table" "app_private_route_table" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app_nat.id
  }

  tags = {
    Name = "${var.site_prefix}_prod_private_route_table"
  }
}

resource "aws_route_table_association" "app_rta" {
  subnet_id      = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.app_route_table.id
}

resource "aws_route_table_association" "app_rta_secondary" {
  subnet_id      = aws_subnet.app_subnet_secondary.id
  route_table_id = aws_route_table.app_route_table.id
}

resource "aws_route_table_association" "app_private_rta" {
  subnet_id      = aws_subnet.app_private_subnet.id
  route_table_id = aws_route_table.app_private_route_table.id
}

resource "aws_route_table_association" "app_private_rta_secondary" {
  subnet_id      = aws_subnet.app_private_subnet_secondary.id
  route_table_id = aws_route_table.app_private_route_table.id
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.app_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.app_route_table.id, aws_route_table.app_private_route_table.id]

  tags = {
    Name = "${var.site_prefix}_prod_s3_gateway_endpoint"
  }
}
