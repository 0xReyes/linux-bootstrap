ssh $BASTION_USER@$BASTION_IP
sudo ufw status # Should show '22 ALLOW'
sudo fail2ban-client status sshd