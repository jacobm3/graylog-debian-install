packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "packer-ubuntu-{{timestamp}}"
  instance_type = "t3.medium"
  region        = "us-east-1"
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = 42
  }
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

build {
  name = "packer-ubuntu"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]
  provisioner "shell" {
      execute_command = "{{.Vars}} sudo -S -E sh -eux '{{.Path}}'" # This runs the scripts with sudo
      scripts = [
          "aws-wait-cloud-init.sh",
          "setup.sh"
      ]
    }
}

