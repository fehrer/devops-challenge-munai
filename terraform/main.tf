#create main archive 

terraform {

  required_version = ">1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# create a VPC and Subnet
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "main_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "main-subnet"
  }
}

resource "aws_key_pair" "aws-munai-key" {
  key_name   = "aws-key-munai"
  public_key = file("./aws-key-challenge.pub")

}

# create a postgresql instance and security group 
resource "aws_instance" "postgresql" {

  ami                    = var.ami-instance
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.aws-munai-key.key_name
  vpc_security_group_ids = [aws_security_group.postgresql_sg.id]
  subnet_id              = aws_subnet.main_subnet.id

  tags = {
    Name = "PostgreSQL Server"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y postgresql-17
    sudo systemctl enable posgresql 
    sudo systemctl start postgresql
    # start script for backups
    echo "0 3 * * * postgres pg_dumpall | gzip > /tmp/postgres_backup.sql.gz && aws s3 cp /tmp/postgres_backup.sql.gz s3://postgre-save/backups/" | sudo tee /etc/cron.d/postgres_backup
    EOF
}

resource "aws_security_group" "postgresql_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PostgreSQL SG"
  }
}


# create nginx server and security group 

resource "aws_instance" "nginx" {
  ami                    = var.ami-instance
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.aws-munai-key.key_name
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  subnet_id              = aws_subnet.main_subnet.id

  tags = {
    Name = "Nginx Server"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
    #installing ssl certificate
    sudo apt-get install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d munai-test.com --non-interactive --agree-tos -m munai-test@munai.com
  EOF
}

resource "aws_security_group" "nginx_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public Access HTTP
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public Access HTTPS
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH Access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Nginx SG"
  }
}

# create a mongoDB server and security group 

resource "aws_instance" "mongodb" {
  ami                    = var.ami-instance
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.aws-munai-key.key_name
  vpc_security_group_ids = [aws_security_group.mongodb_sg.id]
  subnet_id              = aws_subnet.main_subnet.id

  tags = {
    Name = "MongoDB Server"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y gnupg

    # add mongo's gpg key and repository 
    wget -qO - https://www.mongodb.org/static/pgp/server-7.1.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.1 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.1.list

    sudo apt-get update
    sudo apt-get install -y mongodb-org

    
    sudo systemctl start mongod
    sudo systemctl enable mongod
    echo "0 3 * * * mongodump --archive=/tmp/mongo_backup.gz --gzip && aws s3 cp /tmp/mongo_backup.gz s3://mongo-save/backups/" | sudo tee /etc/cron.d/mongo_backup

  EOF
}


resource "aws_security_group" "mongodb_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.nginx.private_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MongoDB Security Group"
  }
}



