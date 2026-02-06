source "amazon-ebs" "base" {
  ami_name      = "linklab-base-{{timestamp}}"
  instance_type = "t3.micro"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      virtualization-type = "hvm"
    }
    owners      = ["amazon"]
    most_recent = true
  }
  ssh_username = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.base"]
  provisioner "ansible" {
    playbook_file = "../ansible/base-setup.yml"
  }
}
