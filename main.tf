terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.13.0"
    }
    local = {
      source = "hashicorp/local"
      version = "2.5.3"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


data "aws_vpc" "default_vpc" {
}

# security group for ec2 ##

resource "aws_security_group" "ec2-sg" {
    vpc_id = data.aws_vpc.default_vpc.id

    ingress {
        from_port = "22"
        to_port = "22"
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    ingress {
        from_port = "80"
        to_port = "80"
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    egress {

        from_port = "0"
        to_port = "0"
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }  
  
    tags = {
      Name = "AS-SG"
    }
}


# dynamic inventory for setup ###

resource "local_file" "ansible_inventory" {

    content = templatefile("./inventory.tpl",
       {
        keyFile = "tf-key.pem",
        workerips = aws_instance.workers[*].public_ip
  
    }
  )

    filename = "./hosts"
}

## ansible ec2 worker node setup ##

resource "aws_instance" "workers" {
    
    count = var.worker_count
    ami = "ami-0bbdd8c17ed981ef9"
    instance_type = "t2.micro"
    key_name = "tf-key"
    vpc_security_group_ids = [ aws_security_group.ec2-sg.id ]
    associate_public_ip_address = true
   
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install python3 -y
                EOF
 
    tags = {
        Name = "ansible-woker-${count.index + 1}"
    }

}



resource "aws_instance" "controller" {
    
    ami = "ami-0bbdd8c17ed981ef9"
    instance_type = "t2.micro"
    key_name = "tf-key"
    vpc_security_group_ids = [ aws_security_group.ec2-sg.id ]
    associate_public_ip_address = true

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update
                sudo apt install ansible -y
                sudo mkdir -p /etc/ansible
                echo "[defaults]" | sudo tee /etc/ansible/ansible.cfg
                echo "host_key_checking = False" | sudo tee -a /etc/ansible/ansible.cfg  
                EOF

    depends_on = [ aws_instance.workers ]
 
    tags = {
        Name = "ansible-contoller"
    }

    provisioner "file" {
      source = "./hosts"
      destination = "/home/ubuntu/hosts"
    }

    provisioner "file" {
      source = "./nginx_playbook.yml"
      destination = "/home/ubuntu/nginx_playbook.yml"
    }

    provisioner "file" {
      source = "./tf-key.pem"
      destination = "/home/ubuntu/tf-key.pem"
    }

    provisioner "remote-exec" {
      inline = [
      "chmod 400 /home/ubuntu/tf-key.pem",
      "sudo chown ubuntu:ubuntu /home/ubuntu/hosts"
      ]
    }

  
    connection {
    type        = "ssh"
    user        = "ubuntu" # Or appropriate user for your AMI
    private_key = file("tf-key.pem")
    host        = self.public_ip
   }
      
  }
  
   


