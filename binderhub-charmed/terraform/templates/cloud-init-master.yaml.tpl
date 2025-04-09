#cloud-config
package_update: true
package_upgrade: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common
  - python3-pip
  - python3-setuptools

ssh_authorized_keys:
${ssh_authorized_keys}

runcmd:
  # Install Juju
  - snap install juju --channel=${juju_version} --classic
  # Set up SSH keys for worker nodes
  - mkdir -p /home/${admin_user}/.ssh
  - chmod 700 /home/${admin_user}/.ssh
  - touch /home/${admin_user}/.ssh/config
  - echo "Host 10.*.*.*" >> /home/${admin_user}/.ssh/config
  - echo "  StrictHostKeyChecking no" >> /home/${admin_user}/.ssh/config
  - echo "  UserKnownHostsFile /dev/null" >> /home/${admin_user}/.ssh/config
  - chmod 600 /home/${admin_user}/.ssh/config
  - chown -R ${admin_user}:${admin_user} /home/${admin_user}/.ssh