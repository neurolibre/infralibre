apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-production
  namespace: binderhub
spec:
  acme:
    # Email address for Let's Encrypt notifications
    email: ${email_contact}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource used to store the account's private key
      name: letsencrypt-production
    solvers:
    - dns01:
        cloudflare:
          email: ${email_contact}
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token 