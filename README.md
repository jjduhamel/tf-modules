# Terraform Modules

This repository contains Terraform modules for various tasks.

## Credstash

Credstash provides a secure and reliable way to manage secrets.

*Usage:*

```hcl
module "credstash" {
  source = "github.com/jjduhamel/tf-modules//credstash"
}
```

## OpenVPN

This module sets up an OpenVPN server based on Debian.

*Usage:*

```hcl
module "openvpn" {
  source = "github.com/jjduhamel/tf-modules//openvpn"
  ami_id = "${ var.debian_ami }"
  keypair = "${ var.keypair }"
  instance_profile = "${ aws_iam_instance_profile.openvpn.id }"
  region = "${ var.region }"
  vpc_id = "${ module.vpc.vpc_id }"
  subnet_id = "${ module.vpc.public_subnet }"

  remote_exec = "${ join(",", list(
    "credstash -r ${ var.region } get VPN_CA_CERT | sudo tee /etc/openvpn/ca.crt > /dev/null",
    "credstash -r ${ var.region } get VPN_SERVER_CERT | sudo tee /etc/openvpn/server.crt > /dev/null",
    "credstash -r ${ var.region } get VPN_SERVER_KEY | sudo tee /etc/openvpn/server.key > /dev/null"
  ))}"
}
```