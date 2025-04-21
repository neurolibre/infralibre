#cloud-config
packages:
  - git
  - fail2ban
  - unattended-upgrades
  - apt-listchanges
  - htop
  - iotop
  - tcpdump
  - software-properties-common
  - python3.10
  - python3.10-venv
  - python3.10-dev
  - python3-pip
  - libcephfs2 
  - python3-cephfs 
  - ceph-common 
  - python3-ceph-argparse

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
      net.netfilter.nf_conntrack_max = 524288
      # More aggressive dirty page flushing
      # Arbutus I/O is choking often and 
      # percentage approach is not ideal as we attach
      # large RAM to the nodes. Use bytes instead.
      # 100MB & 300MB
      vm.dirty_background_bytes = 104857600    # 100 MB
      vm.dirty_bytes = 314572800   # 300 MB
      # TCP SYN flood protection
      net.ipv4.tcp_syncookies = 1
      net.ipv4.tcp_synack_retries = 2  
      # Reduce TIME_WAIT footprint
      net.ipv4.tcp_fin_timeout = 15
      net.ipv4.tcp_tw_reuse = 1
  - path: /etc/ceph/ceph.conf
    content: |
      [global]
      admin socket = /var/run/ceph/$cluster-$name-$pid.asok
      client reconnect stale = true
      debug client = 0/2
      fuse big writes = true
      mon host = 10.30.202.3:6789,10.30.203.3:6789,10.30.201.3:6789
      [client]
      quota = true
  - path: /etc/ceph/ceph.keyring
    content: |  
      [client.MyCephFS-RW]
        key = armut

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
  # Set Python 3.10 as default python3
  - update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
  - update-alternatives --set python3 /usr/bin/python3.10
  # Create symlink for python command
  - ln -sf /usr/bin/python3 /usr/bin/python
  - mkdir -p /cephfs

ssh_authorized_keys:
  ${ssh_authorized_keys}

mounts:
  - [:/volumes/_nogroup/9fabfbb1-5869-414b-81e5-4401e443487c, /cephfs/, ceph, name=MyCephFS-RW, 0,2]

timezone: "America/Montreal"
output: { all: "| tee -a /var/log/cloud-init-output.log" }
