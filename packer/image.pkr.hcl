# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

packer {
  required_plugins {
    amazon = {
      version = "~> 1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }


# source blocks are generated from your builders; a source can be referenced in
# build blocks. A build block runs provisioners and post-processors on a
# source.
source "amazon-ebs" "example" {
  ami_name      = "ssh-demo-ca-${local.timestamp}"
  instance_type = "t2.micro"
  region        = var.region
  source_ami_filter {
    filters = {
      name                = "RHEL-8*-x86_64-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["309956199498"]
  }
  ssh_username = "rhel"
}

# a build block invokes sources and runs provisioning steps on them.

# This is the public key provided by Vault
build {
  sources = ["source.amazon-ebs.example"]

  provisioner "file" {
    source      = "../keys/trusted-user-ca-keys.pem"
    destination = "/etc/ssh/trusted-user-ca-keys.pem"
  }

  provisioner "file" {
    source      = "../keys/tf-packer.pub"
    destination = "/tmp/tf-packer.pub"
  } 
  provisioner "shell" {
    script = "./scripts/setup.sh"
  }
 }
