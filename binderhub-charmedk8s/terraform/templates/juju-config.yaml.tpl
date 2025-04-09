clouds:
  openstack:
    type: openstack
    auth-types: [userpass]
    regions:
      ${openstack_region}:
        endpoint: ${openstack_auth_url}

credentials:
  openstack:
    openstack-creds:
      auth-type: userpass
      username: ${openstack_username}
      password: ${openstack_password}
      domain-name: ${openstack_domain_name}
      project-id: ${openstack_project_id}
      region: ${openstack_region}