# Forms the swarm automatically after the instances exist:
#   1. manager:  docker swarm init
#   2. workers:  docker swarm join (token fetched from the manager over SSH)
# Needs `ssh` on the machine running terraform and your private key.

resource "terraform_data" "swarm_init" {
  triggers_replace = [aws_instance.manager.id]

  connection {
    type        = "ssh"
    host        = aws_eip.manager.public_ip
    user        = "ubuntu"
    private_key = file(pathexpand(var.private_key_path))
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait || true",
      "sudo docker swarm init --advertise-addr ${aws_instance.manager.private_ip} || true",
      "sudo docker node ls",
    ]
  }
}

resource "terraform_data" "swarm_join" {
  count            = var.worker_count
  triggers_replace = [aws_instance.worker[count.index].id]
  depends_on       = [terraform_data.swarm_init]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
       command     = "bash ${path.module}/join-worker.sh '${pathexpand(var.private_key_path)}' '${aws_eip.manager.public_ip}' '${aws_instance.worker[count.index].public_ip}' '${aws_instance.manager.private_ip}'"
  }
}
