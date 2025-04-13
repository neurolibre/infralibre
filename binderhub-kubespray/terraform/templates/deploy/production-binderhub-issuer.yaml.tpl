apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    email: ${email_contact}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - dns01:
        cloudflare:
          email: ${email_contact}
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token 