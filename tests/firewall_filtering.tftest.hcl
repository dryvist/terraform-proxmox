# Tests for tag-based container filtering locals
#
# Verifies that pipeline_container_ids and notification_container_ids
# correctly include/exclude containers based on their tags.
#
# All runs use mock providers (no real infrastructure needed).
# command = plan is sufficient since locals are evaluated at plan time.

mock_provider "proxmox" {
  mock_data "proxmox_virtual_environment_datastores" {
    defaults = {
      datastores = [
        { id = "local", type = "dir", content_types = ["iso", "vztmpl", "backup"] },
        { id = "local-zfs", type = "zfspool", content_types = ["images", "rootdir"] },
      ]
    }
  }
}
mock_provider "tls" {}
mock_provider "random" {}
mock_provider "local" {}
mock_provider "null" {}

# Override data sources and modules that require real provider connections
override_data {
  target = data.local_file.vm_ssh_public_key
  values = {
    content = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyData test@test"
  }
}

override_module {
  target = module.storage
  outputs = {
    cloud_init_file_id   = null
    datastores_available = {}
    storage_validated    = true
  }
}

override_module {
  target = module.splunk_vm
  outputs = {
    vm_id       = 200
    name        = "splunk-vm"
    ip_address  = null
    mac_address = null
  }
}

override_module {
  target = module.firewall
  outputs = {
    cluster_firewall_enabled            = true
    vm_firewall_enabled                 = true
    container_firewall_enabled          = true
    pipeline_container_firewall_enabled = true
  }
}

override_module {
  target = module.acme_certificates
  outputs = {
    acme_accounts = {}
    dns_plugins   = {}
    certificates  = {}
  }
}

variables {
  network_cidrs = {
    lan_main  = "192.168.0.0/22"
    lan_mgmt  = "192.168.1.0/24"
    dns       = "192.168.2.0/24"
    bmc       = "192.168.8.0/24"
    compute   = "192.168.10.0/24"
    siem      = "192.168.20.0/24"
    pipeline  = "192.168.25.0/24"
    data      = "192.168.30.0/24"
    ai        = "192.168.40.0/24"
    apps      = "192.168.50.0/24"
    media_svc = "192.168.55.0/24"
    homeauto  = "192.168.60.0/24"
    nonprod   = "192.168.90.0/24"
  }
}

# --- pipeline_container_ids tests ---

run "haproxy_tagged_container_in_pipeline_ids" {
  command = plan

  variables {
    containers = {
      "haproxy" = {
        vm_id    = 190
        hostname = "haproxy"
        vlan     = "pipeline"
        tags     = ["terraform", "haproxy", "container"]
      }
    }
  }

  assert {
    condition     = contains(keys(local.pipeline_container_ids), "haproxy")
    error_message = "Container with 'haproxy' tag must be in pipeline_container_ids"
  }

  assert {
    condition     = local.pipeline_container_ids["haproxy"] == 190
    error_message = "pipeline_container_ids['haproxy'] should be vm_id 190"
  }
}

run "cribl_edge_tagged_container_in_pipeline_ids" {
  command = plan

  variables {
    containers = {
      "cribl-edge" = {
        vm_id    = 181
        hostname = "cribl-edge"
        vlan     = "pipeline"
        tags     = ["terraform", "cribl", "edge", "container"]
      }
    }
  }

  assert {
    condition     = contains(keys(local.pipeline_container_ids), "cribl-edge")
    error_message = "Container with 'cribl' + 'edge' tags must be in pipeline_container_ids"
  }

  assert {
    condition     = local.pipeline_container_ids["cribl-edge"] == 181
    error_message = "pipeline_container_ids['cribl-edge'] should be vm_id 181"
  }
}

run "notifications_tagged_container_in_notification_ids" {
  command = plan

  variables {
    containers = {
      "mailpit" = {
        vm_id    = 185
        hostname = "mailpit"
        vlan     = "apps"
        tags     = ["terraform", "notifications", "container"]
      }
    }
  }

  assert {
    condition     = contains(keys(local.notification_container_ids), "mailpit")
    error_message = "Container with 'notifications' tag must be in notification_container_ids"
  }

  assert {
    condition     = local.notification_container_ids["mailpit"] == 185
    error_message = "notification_container_ids['mailpit'] should be vm_id 185"
  }

  assert {
    condition     = !contains(keys(local.pipeline_container_ids), "mailpit")
    error_message = "Container with only 'notifications' tag must NOT be in pipeline_container_ids"
  }
}

run "database_tagged_container_in_neither_set" {
  command = plan

  variables {
    containers = {
      "postgres" = {
        vm_id    = 170
        hostname = "postgres"
        vlan     = "data"
        tags     = ["terraform", "database", "container"]
      }
    }
  }

  assert {
    condition     = !contains(keys(local.pipeline_container_ids), "postgres")
    error_message = "Container with 'database' tag must NOT be in pipeline_container_ids"
  }

  assert {
    condition     = !contains(keys(local.notification_container_ids), "postgres")
    error_message = "Container with 'database' tag must NOT be in notification_container_ids"
  }
}

run "empty_containers_both_sets_empty" {
  command = plan

  variables {
    containers = {}
  }

  assert {
    condition     = length(local.pipeline_container_ids) == 0
    error_message = "pipeline_container_ids should be empty when containers is empty"
  }

  assert {
    condition     = length(local.notification_container_ids) == 0
    error_message = "notification_container_ids should be empty when containers is empty"
  }
}

run "cribl_without_edge_not_in_pipeline_ids" {
  command = plan

  variables {
    containers = {
      "cribl-stream" = {
        vm_id    = 171
        hostname = "cribl-stream"
        vlan     = "pipeline"
        tags     = ["terraform", "cribl", "stream", "container"]
      }
    }
  }

  assert {
    condition     = !contains(keys(local.pipeline_container_ids), "cribl-stream")
    error_message = "Container with 'cribl' but NOT 'edge' tag must NOT be in pipeline_container_ids"
  }
}

# --- cribl_stream_container_ids tests ---

run "cribl_stream_tagged_container_in_cribl_stream_ids" {
  command = plan

  variables {
    containers = {
      "cribl-stream" = {
        vm_id    = 171
        hostname = "cribl-stream"
        vlan     = "pipeline"
        tags     = ["terraform", "cribl", "stream", "pipeline", "container"]
      }
    }
  }

  assert {
    condition     = contains(keys(local.cribl_stream_container_ids), "cribl-stream")
    error_message = "Container with 'cribl' + 'stream' tags must be in cribl_stream_container_ids"
  }

  assert {
    condition     = local.cribl_stream_container_ids["cribl-stream"] == 171
    error_message = "cribl_stream_container_ids['cribl-stream'] should be vm_id 171"
  }

  assert {
    condition     = !contains(keys(local.pipeline_container_ids), "cribl-stream")
    error_message = "Cribl Stream must NOT be in pipeline_container_ids (it doesn't receive external traffic)"
  }
}

run "cribl_edge_not_in_cribl_stream_ids" {
  command = plan

  variables {
    containers = {
      "cribl-edge-01" = {
        vm_id    = 180
        hostname = "cribl-edge-01"
        vlan     = "pipeline"
        tags     = ["terraform", "cribl", "edge", "pipeline", "container"]
      }
    }
  }

  assert {
    condition     = !contains(keys(local.cribl_stream_container_ids), "cribl-edge-01")
    error_message = "Container with 'cribl' + 'edge' tags must NOT be in cribl_stream_container_ids"
  }

  assert {
    condition     = contains(keys(local.pipeline_container_ids), "cribl-edge-01")
    error_message = "Container with 'cribl' + 'edge' tags must be in pipeline_container_ids"
  }
}

# --- minio_container_ids tests ---

run "minio_tagged_container_in_minio_ids" {
  command = plan

  variables {
    containers = {
      "minio" = {
        vm_id    = 107
        hostname = "minio"
        vlan     = "apps"
        tags     = ["terraform", "container", "minio", "storage", "infrastructure"]
      }
    }
  }

  assert {
    condition     = contains(keys(local.minio_container_ids), "minio")
    error_message = "Container with 'minio' tag must be in minio_container_ids"
  }

  assert {
    condition     = local.minio_container_ids["minio"] == 107
    error_message = "minio_container_ids['minio'] should be vm_id 107"
  }

  assert {
    condition     = !contains(keys(local.pipeline_container_ids), "minio")
    error_message = "Container with 'minio' tag must NOT be in pipeline_container_ids"
  }

  assert {
    condition     = !contains(keys(local.notification_container_ids), "minio")
    error_message = "Container with 'minio' tag must NOT be in notification_container_ids"
  }
}

# --- infisical_container_ids tests ---

run "infisical_tagged_container_in_infisical_ids" {
  command = plan

  variables {
    containers = {
      "infisical" = {
        vm_id    = 108
        hostname = "infisical"
        vlan     = "apps"
        tags     = ["terraform", "container", "infisical", "secrets", "docker"]
      }
    }
  }

  assert {
    condition     = contains(keys(local.infisical_container_ids), "infisical")
    error_message = "Container with 'infisical' tag must be in infisical_container_ids"
  }

  assert {
    condition     = local.infisical_container_ids["infisical"] == 108
    error_message = "infisical_container_ids['infisical'] should be vm_id 108"
  }

  assert {
    condition     = !contains(keys(local.pipeline_container_ids), "infisical")
    error_message = "Container with 'infisical' tag must NOT be in pipeline_container_ids"
  }

  assert {
    condition     = !contains(keys(local.minio_container_ids), "infisical")
    error_message = "Container with 'infisical' tag must NOT be in minio_container_ids"
  }

  assert {
    condition     = !contains(keys(local.notification_container_ids), "infisical")
    error_message = "Container with 'infisical' tag must NOT be in notification_container_ids"
  }
}

run "pipeline_and_stream_containers_mutually_exclusive" {
  command = plan

  variables {
    containers = {
      "haproxy" = {
        vm_id    = 175
        hostname = "haproxy"
        vlan     = "pipeline"
        tags     = ["terraform", "haproxy", "pipeline", "container"]
      }
      "cribl-edge-01" = {
        vm_id    = 180
        hostname = "cribl-edge-01"
        vlan     = "pipeline"
        tags     = ["terraform", "cribl", "edge", "pipeline", "container"]
      }
      "cribl-stream" = {
        vm_id    = 171
        hostname = "cribl-stream"
        vlan     = "pipeline"
        tags     = ["terraform", "cribl", "stream", "pipeline", "container"]
      }
    }
  }

  assert {
    condition     = length(local.pipeline_container_ids) == 2
    error_message = "pipeline_container_ids should contain haproxy + cribl-edge-01 (2 total)"
  }

  assert {
    condition     = length(local.cribl_stream_container_ids) == 1
    error_message = "cribl_stream_container_ids should contain only cribl-stream (1 total)"
  }

  assert {
    condition     = length(setintersection(keys(local.pipeline_container_ids), keys(local.cribl_stream_container_ids))) == 0
    error_message = "pipeline_container_ids and cribl_stream_container_ids must be mutually exclusive"
  }
}

# --- idrac_kvm_container_ids tests ---

run "idrac_tagged_container_in_idrac_kvm_container_ids" {
  command = plan

  variables {
    containers = {
      "idrac-kvm" = {
        vm_id    = 251
        hostname = "idrac-kvm"
        vlan     = "apps"
        tags     = ["terraform", "container", "idrac", "oob", "management", "docker"]
      }
    }
  }

  assert {
    condition     = contains(keys(local.idrac_kvm_container_ids), "idrac-kvm")
    error_message = "container with 'idrac' tag must be in idrac_kvm_container_ids"
  }

  assert {
    condition     = local.idrac_kvm_container_ids["idrac-kvm"] == 251
    error_message = "idrac_kvm_container_ids['idrac-kvm'] should be vm_id 251"
  }
}

run "non_idrac_container_not_in_idrac_kvm_container_ids" {
  command = plan

  variables {
    containers = {
      "mailpit" = {
        vm_id    = 110
        hostname = "mailpit"
        vlan     = "apps"
        tags     = ["terraform", "container", "notifications", "docker"]
      }
    }
  }

  assert {
    condition     = !contains(keys(local.idrac_kvm_container_ids), "mailpit")
    error_message = "container without 'idrac' tag must NOT be in idrac_kvm_container_ids"
  }

  assert {
    condition     = length(local.idrac_kvm_container_ids) == 0
    error_message = "idrac_kvm_container_ids should be empty when no containers have the 'idrac' tag"
  }
}
