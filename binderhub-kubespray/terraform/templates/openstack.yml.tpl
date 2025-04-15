#external_openstack_lbaas_enabled: true
#external_openstack_lbaas_floating_network_id: "${openstack_external_network_id}"
#external_openstack_lbaas_floating_subnet_id: "${openstack_subnet_id}"
#external_openstack_lbaas_method: ROUND_ROBIN
#external_openstack_lbaas_provider: amphora
#external_openstack_lbaas_subnet_id: "${openstack_subnet_id}"
#external_openstack_lbaas_network_id: "${openstack_external_network_id}"
#external_openstack_lbaas_manage_security_groups: false
#external_openstack_lbaas_create_monitor: false
#external_openstack_lbaas_monitor_delay: 5s
#external_openstack_lbaas_monitor_max_retries: 1
#external_openstack_lbaas_monitor_timeout: 3s
#external_openstack_lbaas_internal_lb: false
#external_openstack_network_ipv6_disabled: false
#external_openstack_network_internal_networks: []
#external_openstack_network_public_networks: []
external_openstack_metadata_search_order: "configDrive,metadataService"

openstack_lbaas_enabled: false
external_openstack_auth_url: "${openstack_auth_url}"
external_openstack_username: "${openstack_username}"
external_openstack_password: "${openstack_password}"
external_openstack_region: "${openstack_region}"
external_openstack_tenant_id: "${openstack_project_id}"
external_openstack_tenant_name: "${openstack_project_name}"
external_openstack_domain_name: "${openstack_domain_name}"

cinder_csi_enabled: true
cinder_topology: false

cinder_csi_ignore_volume_az: true
