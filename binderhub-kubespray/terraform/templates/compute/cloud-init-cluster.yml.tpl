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
      mon host = 10.30.201.3:6789,10.30.202.3:6789,10.30.203.3:6789
      [client]
      quota = true
  - path: /etc/ceph/ceph.keyring
    content: |  
      [client.${ceph_rule_name}]
          key = ${ceph_rule_key}

runcmd:
  - NODE_NAME=$(hostname)
  - echo "127.0.0.1 $NODE_NAME" | sudo tee -a /etc/hosts
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
  - mkdir -p /${shared_data_directory}
  # ADD SHARED TO /etc/fstab
  - echo ":/volumes/_nogroup/${ceph_share_hash}    /${shared_data_directory} ceph    name=${ceph_rule_name}    0    2"  | sudo tee -a /etc/fstab
  # FORMAT AND MOUNT ETCD VOLUME CONDITIONALLY (MASTER ONLY)
  - |
    if [ "$NODE_NAME" = "${cluster_name}-master" ]; then
      mkdir -p /var/lib/etcd
      mkfs.ext4 "${etcd_volume_device}"
      echo "${etcd_volume_device} /var/lib/etcd ext4 defaults 0 2" | sudo tee -a /etc/fstab
    fi
  # Mounting volumes is dealt with in compute/main.tf

ssh_authorized_keys:
  ${ssh_authorized_keys}

timezone: "America/Montreal"
output: { all: "| tee -a /var/log/cloud-init-output.log" }
