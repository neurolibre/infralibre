Grafana data source:
http://prometheus.monitoring.svc.cluster.local:9090

That's it, that's the note.

Also, it is really important that both the NFS server and the binderhub share the exact same security group, otherwise the binderhub will not be able to mount the NFS.

This is really useful to check:

https://prometheus-mcgill.conp.cloud/targets?search=

When BindeHub runs into 500, just start by checking the pod logs from hub and binder.

If they look normal, then go for svc, certs, ingress, etc.

Latest binderhub prod: 0.1.0-0.dev.git.244.h1e88014