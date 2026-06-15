# Docker-in-LXC feature derivation.
#
# A container tagged `docker` runs Docker inside the LXC, which requires the
# `nesting` + `keyctl` features, plus `fuse` for the fuse-overlayfs storage driver
# this homelab uses on ZFS-backed LXCs (the ansible-proxmox-apps registry-mirror
# play sets storage-driver=fuse-overlayfs). Derive all three from the tag so every
# docker guest gets the full set automatically instead of hand-declaring them per
# container — they had drifted (some nesting+keyctl+fuse, some only nesting, some
# none, while live containers carried features applied out-of-band by pct/Ansible).
#
# The tag only ever ADDS: any explicitly-declared feature still applies (logical OR),
# so a non-docker container is unaffected and a docker container that already
# declared the full set sees no change.
locals {
  effective_features = {
    for k, c in var.containers : k => {
      nesting = c.features.nesting || contains(c.tags, "docker")
      keyctl  = c.features.keyctl || contains(c.tags, "docker")
      fuse    = c.features.fuse || contains(c.tags, "docker")
      mount   = c.features.mount
    }
  }
}
