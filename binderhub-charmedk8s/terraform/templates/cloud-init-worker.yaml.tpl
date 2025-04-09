#cloud-config
package_update: true
package_upgrade: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common

ssh_authorized_keys:
  ${ssh_authorized_keys}

runcmd:
  # Set up SSH for Juju
  - mkdir -p /home/${admin_user}/.ssh
  - chmod 700 /home/${admin_user}/.ssh
  - touch /home/${admin_user}/.ssh/authorized_keys
  - chmod 600 /home/${admin_user}/.ssh/authorized_keys
  - chown -R ${admin_user}:${admin_user} /home/${admin_user}/.ssh