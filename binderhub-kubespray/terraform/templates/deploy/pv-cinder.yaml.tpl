apiVersion: v1
kind: PersistentVolume
metadata:
  name: hub-db-dir
  labels:
    type: cinder
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  volumeMode: Filesystem
  storageClassName: ""
  # NOTE: The cinder CSI driver is enabled in openstack.yml.tpl
  # The Kubernetes cluster provisioned with Kubespray uses the cinder CSI driver
  # for OpenStack integration, leveraging the native cloud provider capabilities.
  csi:
    driver: cinder.csi.openstack.org
    volumeHandle: ${cinder_db_volume_id}
    fsType: ext4
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists