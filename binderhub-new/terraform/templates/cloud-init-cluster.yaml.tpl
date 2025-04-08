#cloud-config
packages:
  - git
  - fail2ban
  - unattended-upgrades
  - apt-listchanges
  - htop
  - iotop
  - tcpdump

package_reboot_if_required: false
manage_resolv_conf: true

write_files:
  - path: /etc/sysctl.d/99-performance.conf
    content: |
      # Increase file descriptors
      fs.file-max = 1000000
      # Optimize network settings
      net.core.somaxconn = 65535
      net.core.netdev_max_backlog = 4096
      net.ipv4.tcp_max_syn_backlog = 4096
      # Optimize for container workloads
      kernel.pid_max = 4194303

runcmd:
  - echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts
  # Configure automatic security updates
  - echo 'Unattended-Upgrade::Automatic-Reboot "false";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades
  # Disable password authentication for SSH
  - sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart sshd
  # Apply sysctl settings
  - sysctl --system
  # Increase ulimits for the system
  - echo "* soft nofile 1000000" >> /etc/security/limits.conf
  - echo "* hard nofile 1000000" >> /etc/security/limits.conf
  - echo "* soft nproc 65535" >> /etc/security/limits.conf
  - echo "* hard nproc 65535" >> /etc/security/limits.conf

ssh_authorized_keys:
  ${ssh_authorized_keys}

disable_ec2_metadata: true
timezone: "America/Montreal"
output: { all: "| tee -a /var/log/cloud-init-output.log" }
