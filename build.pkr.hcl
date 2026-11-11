packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "ami_name" {
  type = string
}

source "amazon-ebs" "ubuntu" {
  ami_name      = var.ami_name
  instance_type = "t2.micro"
  region        = "us-east-1"
  ssh_username  = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
      "sudo apt-get update -y",
      "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -",
      "sudo apt-get install -y nodejs",
      "sudo npm install -g pm2",
      "sudo mkdir -p /var/www/app",
      "sudo chown ubuntu:ubuntu /var/www/app"
    ]
  }

  provisioner "file" {
    source      = "./"
    destination = "/var/www/app"
  }

  provisioner "shell" {
    inline = [
      "cd /var/www/app",
      "npm install express",
      "pm2 start server.js --name siwes-node-app",
      "pm2 save",
      "sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu"
    ]
  }

  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}