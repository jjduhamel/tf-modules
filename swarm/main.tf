variable "ami_id" { default="ami-8cf36aec" }
variable "ami_user" { default="rancher" }
variable "iam_roles" { default="" }
variable "instance_type" { default="t2.micro" }
variable "keypair" {}
variable "user_data" { default = "" }
variable "vpc_id" {}
variable "subnet_id" {}

variable "manager_count" { default=1 }
variable "manager_token" { default="" }
variable "worker_count" { default=0 }
variable "worker_token" { default="" }

resource "aws_security_group" "swarm" {
  name = "swarm"
  vpc_id = "${ var.vpc_id }"
  description = "Security group for Docker Swarm Manager"
  tags { Name = "Docker Swarm" }

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "tcp"
    from_port = 2375
    to_port = 2375
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "tcp"
    from_port = 2377
    to_port = 2377
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "tcp"
    from_port = 7946
    to_port = 7946
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "udp"
    from_port = 7946
    to_port = 7946
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "udp"
    from_port = 4789
    to_port = 4789
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_iam_instance_profile" "swarm" {
  name = "swarm"
  roles = [ "${ compact(split(",", var.iam_roles)) }" ]
}

resource "aws_instance" "swarm_manager" {
  //count = "${ var.manager_count }"
  ami = "${ var.ami_id }"
  key_name = "${ var.keypair }"
  instance_type = "${ var.instance_type }"
  iam_instance_profile = "${ aws_iam_instance_profile.swarm.id }"
  user_data = "${ var.user_data }"
  subnet_id = "${ var.subnet_id }"
  vpc_security_group_ids = [ "${ aws_security_group.swarm.id }" ]
  tags { Name = "Swarm Manager" }

  connection {
    type = "ssh"
    user = "${ var.ami_user }"
    private_key = "${ file("~/.ssh/id_rsa") }"
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "sleep 10",
      "sudo ros config set rancher.docker.extra_args [\"-H=tcp://0.0.0.0:2375\",\"-H=unix:///var/run/docker.sock\"]",
      "sudo system-docker restart docker",
      "sleep 30",
			"docker swarm init --advertise-addr eth0:2377",
      "docker swarm join-token manager",
      "set +x"
    ]
  }
}

resource "aws_instance" "swarm_worker" {
  count = "${ var.worker_count }"
  ami = "${ var.ami_id }"
  key_name = "${ var.keypair }"
  instance_type = "${ var.instance_type }"
  iam_instance_profile = "${ aws_iam_instance_profile.swarm.id }"
  user_data = "${ var.user_data }"
  subnet_id = "${ var.subnet_id }"
  vpc_security_group_ids = [ "${ aws_security_group.swarm.id }" ]
  tags { Name = "Swarm Worker" }

  connection {
    type = "ssh"
    user = "${ var.ami_user }"
    private_key = "${ file("~/.ssh/id_rsa") }"
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "sleep 30",
			"docker swarm join --token ${ var.worker_token } ${ aws_instance.swarm_manager.private_ip }:2377",
      "set +x"
    ]
  }
}

output "managers" { value = [ "${ aws_instance.swarm_manager.*.private_ip }" ] }
output "workers" { value = [ "${ aws_instance.swarm_worker.*.private_ip }" ] }
