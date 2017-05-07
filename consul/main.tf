variable "ami_id" { default = "ami-fde96b9d" }
variable "ami_user" { default = "admin" }
variable "keypair" { default="" }
variable "iam_roles" { default="" }
variable "remote_exec" { default="" }
variable "region" { default="us-east-1" }
variable "vpc_id" {}
variable "subnet_id" {}

resource "aws_security_group" "consul" {
  name = "consul"
  vpc_id = "${ var.vpc_id }"
  description = "Consul by Hashicorp"
  tags { Name = "consul" }

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "tcp"
    from_port = 8300
    to_port = 8300
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_iam_instance_profile" "consul" {
  name = "consul"
  roles = [ "${ split(",", var.iam_roles) }" ]
}

resource "aws_instance" "consul" {
  ami = "${ var.ami_id }"
  instance_type = "t2.micro"
  key_name = "${ var.keypair }"
  iam_instance_profile = "${ aws_iam_instance_profile.consul.id }"
  subnet_id = "${ var.subnet_id }"
  vpc_security_group_ids = [ "${ aws_security_group.consul.id }" ]
  tags { Name = "Consul" }

  connection {
    type = "ssh"
    user = "${ var.ami_user }"
    private_key = "${ file("~/.ssh/id_rsa") }"
  }

  provisioner "file" {
    source = "${ path.module }/fs"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "sudo apt-get update && sudo apt-get install -y nginx",
      "sudo chmod 755 /usr/local/bin",
      "sudo cp -vr /tmp/bin /usr/local/bin",
      "sudo cp -vr /tmp/src /usr/local/src",
      "sudo cp -vr /tmp/etc /etc",
			"sudo mkdir -vp /var/lib/consul",
			"sudo chown :daemon /var/lib/consul",
			"sudo systemctl daemon-reload",
			"sudo systemctl enable consul-server",
			"sudo systemctl start consul-server",
			"sudo systemctl enable nginx",
			"sudo systemctl start nginx",
      "set +x"
    ]
  }
}

output "ip_address" { value = "${ aws_instance.consul.private_ip }" }
