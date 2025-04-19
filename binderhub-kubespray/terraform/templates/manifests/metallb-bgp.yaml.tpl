apiVersion: metallb.io/v1beta1
kind: BGPPeer
metadata:
  name: peer-with-calico-node
  namespace: metallb-system
spec:
  peerAddress: ${bgp_peer_address}
  peerPort: 179
  peerASN: 64512
  myASN: 64512
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: public-ips
  namespace: metallb-system
spec:
  addresses:
  - ${load_balancer_ip}/32
  autoAssign: false
---
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: public-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - public-ips