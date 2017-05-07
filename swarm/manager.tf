variable "manager_count" { default=1 }

resource "aws_security_group" "swarm_manager" {
  name = "swarm_manager"
  vpc_id = "${ var.vpc_id }"
  description = "Security group for Docker Swarm manager"

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
    from_port = 4000
    to_port = 4000
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "udp"
    from_port = 4789 
    to_port = 4789
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "udp"
    from_port = 7946
    to_port = 7946
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol = "tcp"
    from_port = 7946
    to_port = 7946
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags {
    Name = "swarm_manager"
  }
}

data "template_file" "swarm_manager" {
  count = "${ var.manager_count }"
  template = "${ file("${ path.module }/cloud-config.manager.yaml") }"
  vars {
    IP_ADDRESS = "${ format("10.0.2.%03d", 100+count.index) }"
  }
}

resource "aws_instance" "swarm_manager" {
  count = "${ var.manager_count }"
  ami = "${ var.ami_id }"
  instance_type = "t2.micro"
  key_name = "${ var.keypair }"

  subnet_id = "${ var.subnet_id }"
  vpc_security_group_ids = [
    "${ aws_security_group.swarm_manager.id }"
  ]
  private_ip = "${ format("10.0.2.%03d", 100+count.index) }"

  tags {
    Name = "Swarm Manager" 
  }

  user_data = "${ element(data.template_file.swarm_manager.*.rendered, count.index) }"
}

output "ip_address" { value = "${ aws_instance.swarm_manager.private_ip }" }
output "managers" { value = [ "${ aws_instance.swarm_manager.*.private_ip }" ] }
