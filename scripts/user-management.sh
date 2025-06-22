# scripts/user-management.sh
sudo useradd -m -s /bin/bash <username>
sudo usermod -aG sudo <username>
sudo mkdir -p /home/<username>/.ssh
sudo cp "$CONFIG_DIR/home/<username>/.ssh/authorized_keys" /home/<username>/.ssh/
sudo chown -R <username>:<username> /home/<username>/.ssh