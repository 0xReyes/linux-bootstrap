#!/bin/bash
set -euo pipefail

# Constants and Configuration
readonly BACKUP_DIR="/etc/backup-$(date +%Y%m%d-%H%M%S)"
readonly LOG_FILE="/var/log/server-config-$(date +%Y%m%d).log"
readonly CONFIG_DIR="${1:-/tmp/server-config}"

# Initialize logging
exec > >(sudo tee -a "$LOG_FILE") 2>&1
echo "=== Starting configuration $(date) ==="

# Validate configuration directory
validate_config_dir() {
    local required_dirs=(
        "$CONFIG_DIR/etc/ssh"
        "$CONFIG_DIR/etc/fail2ban"
        "$CONFIG_DIR/scripts"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo "ERROR: Missing required directory: $dir"
            exit 1
        fi
    done
}

# Create backup of current configuration
create_backup() {
    echo "Creating backup in $BACKUP_DIR"
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp -a /etc/ssh "$BACKUP_DIR" || {
        echo "ERROR: Failed to backup SSH config"; exit 1
    }
    sudo cp -a /etc/fail2ban "$BACKUP_DIR" || {
        echo "ERROR: Failed to backup Fail2ban config"; exit 1
    }
    sudo netstat -tuln > "$BACKUP_DIR/netstat.txt"
    sudo ps aux > "$BACKUP_DIR/processes.txt"
}

# Rollback function
rollback() {
    echo "!! ERROR: Rolling back changes !!"
    sudo cp -a "$BACKUP_DIR/ssh" /etc/ || echo "Rollback of SSH config failed"
    sudo cp -a "$BACKUP_DIR/fail2ban" /etc/ || echo "Rollback of Fail2ban failed"
    sudo systemctl restart sshd || echo "Failed to restart SSH"
    exit 1
}

# Main configuration function
apply_configuration() {
    echo "Applying SSH configuration..."
    sudo cp "$CONFIG_DIR/etc/ssh/sshd_config" /etc/ssh/sshd_config || {
        echo "ERROR: Failed to copy sshd_config"; exit 1
    }
    
    sudo mkdir -p /etc/ssh/sshd_config.d
    if [[ -d "$CONFIG_DIR/etc/ssh/sshd_config.d" ]]; then
        sudo cp "$CONFIG_DIR/etc/ssh/sshd_config.d/"* /etc/ssh/sshd_config.d/ || {
            echo "WARNING: Failed to copy some sshd_config.d files"
        }
    fi
    
    echo "Validating SSH configuration..."
    sudo sshd -t || {
        echo "ERROR: Invalid SSH configuration"; exit 1
    }
    
    echo "Applying authorized_keys..."
    local USERNAME=$(whoami)
    sudo mkdir -p "/home/$USERNAME/.ssh"
    sudo cp "$CONFIG_DIR/home/$USERNAME/.ssh/authorized_keys" "/home/$USERNAME/.ssh/" || {
        echo "ERROR: Failed to copy authorized_keys"; exit 1
    }
    sudo chmod 700 "/home/$USERNAME/.ssh"
    sudo chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
    sudo chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
    
    echo "Applying Fail2ban configuration..."
    sudo cp "$CONFIG_DIR/etc/fail2ban/jail.local" /etc/fail2ban/jail.local || {
        echo "ERROR: Failed to copy jail.local"; exit 1
    }
    
    echo "Applying common hardening..."
    sudo bash "$CONFIG_DIR/scripts/common-hardening.sh" || {
        echo "ERROR: Hardening script failed"; exit 1
    }
}

# Verification function
verify_configuration() {
    echo "Verifying services..."
    sudo systemctl is-active sshd >/dev/null || {
        echo "ERROR: SSH service not running"; exit 1
    }
    
    sudo systemctl is-active fail2ban >/dev/null || {
        echo "ERROR: Fail2ban service not running"; exit 1
    }
    
    echo "Testing SSH connectivity..."
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no localhost echo "SSH test successful" || {
        echo "ERROR: SSH self-test failed"; exit 1
    }
}

# Main execution flow
trap rollback ERR
validate_config_dir
create_backup
apply_configuration

echo "Restarting services..."
sudo systemctl restart sshd || { echo "ERROR: Failed to restart SSH"; exit 1; }
sudo systemctl restart fail2ban || { echo "ERROR: Failed to restart Fail2ban"; exit 1; }

verify_configuration

echo "=== Configuration completed successfully ==="
echo "Backup available at: $BACKUP_DIR"
echo "Log file: $LOG_FILE"
exit 0