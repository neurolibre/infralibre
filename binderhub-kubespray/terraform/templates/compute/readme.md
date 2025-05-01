
As for May 2025, there are no ssd volumes available on Arbutus. Ideally, we want etcd to be on an ssd volume, as this is a performance-critical core component of the kubernetes cluster. Cinder-backed HDD volumes (which are spinning disks) are not ideal, and arbutus has some serious I/O issues.

The following section is what needs to be added to the cloud-init-cluster.yml.tpl file to mount the etcd volume to /var/lib/etcd.

```yaml
  # CREATE VAR/LIB/ETCD DIRECTORY AND ADD TO /etc/fstab (MASTER ONLY)
  #- |
  #-   if [ "$NODE_NAME" = "${cluster_name}-master" ]; then
  #-     mkdir -p /var/lib/etcd
  #-     echo "${etcd_volume_device} /var/lib/etcd ext4 defaults 0 2" | sudo tee -a /etc/fstab
  #-   fi
```

In addition, see /modules/compute/main.tf for the commented out sections that would add the etcd volume to the master node.

Note that the mounting of the etcd volume in its current form was not successful. Requires further investigation, probably has to do with directory permissions, or with the order of operations. When you comment in the sections, and mount a volume, the cluster will not be healthy (restarting calico pods, communication issues between pods, etc.).
