# create a postgresql server
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


# create web_server

resource "aws_instance" "web_server" {
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
    sudo apt-get install -y nginx=1.26.* 
    sudo systemctl enable nginx
    sudo systemctl start nginx
    #installing ssl certificate
    sudo apt-get install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d munai-test.com --non-interactive --agree-tos -m munai-test@munai.com
  EOF
}


# create a mongoDB server 

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