---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: public
    namespace: metallb-system
spec:
    addresses:
    - "${load_balancer_ip}/32"