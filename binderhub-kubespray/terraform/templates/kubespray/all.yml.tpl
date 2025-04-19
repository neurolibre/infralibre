---
## Directory where the binaries will be installed
bin_dir: /usr/local/bin


cloud_provider: external
external_cloud_provider: openstack

## Since workers are included in the no_proxy variable by default, docker engine will be restarted on all nodes (all
## pods will restart) when adding or removing workers.  To override this behaviour by only including control plane nodes
## in the no_proxy variable, set below to true:
no_proxy_exclude_workers: false

## Variables for webhook token auth https://kubernetes.io/docs/reference/access-authn-authz/authentication/#webhook-token-authentication
kube_webhook_token_auth: false
kube_webhook_token_auth_url_skip_tls_verify: false

## NTP Settings
# Start the ntpd or chrony service and enable it at system boot.
ntp_enabled: false
ntp_manage_config: false
ntp_servers:
  - "0.pool.ntp.org iburst"
  - "1.pool.ntp.org iburst"
  - "2.pool.ntp.org iburst"
  - "3.pool.ntp.org iburst"

## Used to control no_log attribute
unsafe_show_logs: false

## If enabled it will allow kubespray to attempt setup even if the distribution is not supported. For unsupported distributions this can lead to unexpected failures in some cases.
allow_unsupported_distribution_setup: false