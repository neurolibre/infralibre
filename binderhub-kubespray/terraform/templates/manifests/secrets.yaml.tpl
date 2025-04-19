jupyterhub:
  hub:
    services:
      binder:
        apiToken: "${api_token}"
  proxy:
    secretToken: "${secret_token}"
registry:
  url: ${registry_url}
  username: ${registry_username}
  password: ${registry_password}