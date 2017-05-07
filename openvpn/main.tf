variable "ami_id" { default = "ami-fde96b9d" }
variable "ami_user" { default = "admin" }
variable "keypair" { default="" }
variable "iam_roles" { default="" }
variable "remote_exec" { default="" }
variable "region" { default="us-east-1" }
variable "vpc_id" {}
variable "subnet_id" {}

resource "aws_security_group" "openvpn" {
  name = "openvpn"
  vpc_id = "${ var.vpc_id }"
  description = "OpenVPN (UDP)"
  tags { Name = "openvpn" }

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "udp"
    from_port = 1194
    to_port = 1194
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_iam_instance_profile" "openvpn" {
  name = "openvpn"
  roles = [ "${ compact(split(",", var.iam_roles)) }" ]
}

resource "aws_instance" "openvpn" {
  ami = "${ var.ami_id }"
  instance_type = "t2.micro"
  key_name = "${ var.keypair }"
  iam_instance_profile = "${ aws_iam_instance_profile.openvpn.id }"
  subnet_id = "${ var.subnet_id }"
  vpc_security_group_ids = [ "${ aws_security_group.openvpn.id }" ]
  tags { Name = "OpenVPN" }

  connection {
    type = "ssh"
    user = "${ var.ami_user }"
    private_key = "${ file("~/.ssh/id_rsa") }"
    host = "${ aws_instance.openvpn.public_ip }"
  }

  provisioner "file" {
    source = "${ path.module }/etc"
    destination = "/tmp/etc"
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "sudo cp -vr /tmp/etc/. /etc && rm -rf /tmp/etc",
      "sudo apt-get update",
      "sudo touch /etc/openvpn/ca.crt",
      "sudo touch /etc/openvpn/server.crt",
      "sudo touch /etc/openvpn/server.key",
      "sudo openssl dhparam -out /etc/openvpn/dh2048.pem 2048",
      "sudo sed -i 's/#net.ipv4.ip_forward.*=.*1/net.ipv4.ip_forward=1/' /etc/sysctl.conf",
      "sudo sysctl -p",
      "sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE",
      "sudo iptables-save > /etc/iptables/rules.v4",
      "echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections",
      "echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections",
      "sudo apt-get install -y openvpn iptables-persistent",
    ]
  }

  provisioner "remote-exec" {
    inline = [ "${ compact(split(",", var.remote_exec)) }" ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl enable openvpn@local",
      "sudo systemctl start openvpn@local",
      "set +x"
    ]
  }
}

resource "aws_eip" "openvpn" {
  instance = "${ aws_instance.openvpn.id }"
}

output "ip_address" { value = "${ aws_eip.openvpn.public_ip }" }
output "instance_profile" { value = "${ aws_iam_instance_profile.openvpn.id }" }
output "security_group" { value = "aws_security_group.openvpn.id" }
