variable "node_count" { default=2 }

resource "aws_security_group" "swarm_node" {
  name = "swarm_node"
  vpc_id = "${ var.vpc_id }"
  description = "Security group for Docker Swarm node"

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
    Name = "swarm_node"
  }
}

data "template_file" "swarm_node" {
  count = "${ var.node_count }"
  template = "${ file("${ path.module }/cloud-config.node.yaml") }"
  vars {
    IP_ADDRESS = "${ format("10.0.2.%03d", 200+count.index) }"
  }
}

resource "aws_instance" "swarm_node" {
  count = "${ var.node_count }"
  ami = "${ var.ami_id }"
  instance_type = "t2.micro"
  key_name = "${ var.keypair }"

  subnet_id = "${ var.subnet_id }"
  vpc_security_group_ids = [
    "${ aws_security_group.swarm_node.id }"
  ]
  private_ip = "${ format("10.0.2.%03d", 200+count.index) }"

  tags {
    Name = "Swarm Node"
  }

  user_data = "${ element(data.template_file.swarm_node.*.rendered, count.index) }"
}

output "nodes" { value = [ "${ aws_instance.swarm_node.*.private_ip }" ] }
