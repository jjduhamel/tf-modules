variable "postgres_version" { default = "9.6.2" }
variable "instance_class" { default = "db.t2.micro" }
variable "storage_type" { default = "gp2" }
variable "storage" { default = 10 }
variable "vpc_id" {}
variable "subnet_ids" {}

variable "db_name" {}
variable "db_username" { default = "postgres" }
variable "db_password" {}

resource "aws_security_group" "postgres" {
  name        = "pgsql_rds_sg"
  description = "Postgres inbound traffic"
  vpc_id      = "${ var.vpc_id }"
  tags { Name = "Postgres RDS" }

  ingress {
    protocol = "tcp"
    from_port = 0
    to_port = 65535
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_db_instance" "postgres" {
  storage_type = "${ var.storage_type }"
  allocated_storage = "${ var.storage }"
  engine = "postgres"
  engine_version = "${ var.postgres_version }"
  instance_class = "${ var.instance_class }"
  name = "${ var.db_name }"
  username = "${ var.db_username }"
  password = "${ var.db_password }"
  vpc_security_group_ids = [ "${ aws_security_group.postgres.id }" ]
  db_subnet_group_name   = "${ aws_db_subnet_group.postgres.id }"
}

resource "aws_db_subnet_group" "postgres" {
  name = "postgres_subnet_group"
  description = "Postgres subnets"
  subnet_ids = [ "${ compact(split(",", var.subnet_ids)) }" ]
}

output "instance_id" { value = "${ aws_db_instance.postgres.id }" }
output "subnet_group_id" { value = "${ aws_db_subnet_group.postgres.id }" }
