# Changelog

## [1.48.0](https://github.com/dryvist/terraform-proxmox/compare/v1.47.2...v1.48.0) (2026-07-03)


### Features

* add AI PR care caller (dep review + release highlights) ([#519](https://github.com/dryvist/terraform-proxmox/issues/519)) ([003eedf](https://github.com/dryvist/terraform-proxmox/commit/003eedf5b235a33d243c2b7eb242feafee7c7466))

## [1.47.2](https://github.com/dryvist/terraform-proxmox/compare/v1.47.1...v1.47.2) (2026-07-02)


### Bug Fixes

* point callers at renamed cc- reusable workflows ([245a592](https://github.com/dryvist/terraform-proxmox/commit/245a59237b0f45f61783317eea0f7db17556b03f))

## [1.47.1](https://github.com/dryvist/terraform-proxmox/compare/v1.47.0...v1.47.1) (2026-07-02)


### Bug Fixes

* **firewall:** honeypot notify security-group name under 18-char cap ([e7d5aae](https://github.com/dryvist/terraform-proxmox/commit/e7d5aaef11a8be8ac5d9acc16b9e808a209df8c9))

## [1.47.0](https://github.com/dryvist/terraform-proxmox/compare/v1.46.3...v1.47.0) (2026-07-01)


### Features

* **honeypots:** network-wide deception fabric with instant phone alerting ([#491](https://github.com/dryvist/terraform-proxmox/issues/491)) ([39a8598](https://github.com/dryvist/terraform-proxmox/commit/39a8598475c0d1e3184dce6a0909075895563bb5))

## [1.46.3](https://github.com/dryvist/terraform-proxmox/compare/v1.46.2...v1.46.3) (2026-06-30)


### Bug Fixes

* **proxmox:** unblock the AI-orchestration tier apply (docker features + firewall group name) ([#508](https://github.com/dryvist/terraform-proxmox/issues/508)) ([f4788e2](https://github.com/dryvist/terraform-proxmox/commit/f4788e2bf892a34c0f8e6a66b58282e9125b77b3))

## [1.46.2](https://github.com/dryvist/terraform-proxmox/compare/v1.46.1...v1.46.2) (2026-06-29)


### Bug Fixes

* **containers:** ignore out-of-band idmap drift to protect media ([#505](https://github.com/dryvist/terraform-proxmox/issues/505)) ([692b23d](https://github.com/dryvist/terraform-proxmox/commit/692b23d20ec548cfc9e7b9e812ff5e65b7b19783))

## [1.46.1](https://github.com/dryvist/terraform-proxmox/compare/v1.46.0...v1.46.1) (2026-06-29)


### Bug Fixes

* **ci:** repair and enable the ci-fix wrapper ([#502](https://github.com/dryvist/terraform-proxmox/issues/502)) ([0ee7e0d](https://github.com/dryvist/terraform-proxmox/commit/0ee7e0dbf4b50d5ff58e76d74b85ef472aa049b5))

## [1.46.0](https://github.com/dryvist/terraform-proxmox/compare/v1.45.0...v1.46.0) (2026-06-27)


### Features

* **ai:** firewall + ports + ingress for AI orchestration stack ([#494](https://github.com/dryvist/terraform-proxmox/issues/494)) ([abbaa0c](https://github.com/dryvist/terraform-proxmox/commit/abbaa0c2606c3d3f246f3d163b15c19ad0aae2ab))

## [1.45.0](https://github.com/dryvist/terraform-proxmox/compare/v1.44.0...v1.45.0) (2026-06-27)


### Features

* **openbao:** on-prem static-key unseal + HA ingress + secret hierarchy ([#496](https://github.com/dryvist/terraform-proxmox/issues/496)) ([a740a84](https://github.com/dryvist/terraform-proxmox/commit/a740a8490c0d3737244ab4ed576d4d25d768c8e0))

## [1.44.0](https://github.com/dryvist/terraform-proxmox/compare/v1.43.1...v1.44.0) (2026-06-24)


### Features

* **inventory:** deployment.json desired-state from a private s3 store (fail-loud) ([#489](https://github.com/dryvist/terraform-proxmox/issues/489)) ([c239c12](https://github.com/dryvist/terraform-proxmox/commit/c239c12d8cef8bef796b7ac6bd1236a4329190b7))


### Bug Fixes

* **firewall:** allow DHCP on the object-storage container ([#490](https://github.com/dryvist/terraform-proxmox/issues/490)) ([dba2519](https://github.com/dryvist/terraform-proxmox/commit/dba25196fc0d1869685ae3e1a2ef4672b4b7bfd1))

## [1.43.1](https://github.com/dryvist/terraform-proxmox/compare/v1.43.0...v1.43.1) (2026-06-22)


### Bug Fixes

* use generic DOPPLER_TOKEN secret, drop vault-specific names ([#482](https://github.com/dryvist/terraform-proxmox/issues/482)) ([cd3a8d0](https://github.com/dryvist/terraform-proxmox/commit/cd3a8d0fd27280b2e36af6469cdc059dc121a1d3))

## [1.43.0](https://github.com/dryvist/terraform-proxmox/compare/v1.42.0...v1.43.0) (2026-06-22)


### Features

* **firewall:** add hermes-agent egress group for the autonomous agent LXC ([#484](https://github.com/dryvist/terraform-proxmox/issues/484)) ([e4485c0](https://github.com/dryvist/terraform-proxmox/commit/e4485c0894fc59a0c57eddb1fd74ebd3c6c5e1c2))

## [1.42.0](https://github.com/dryvist/terraform-proxmox/compare/v1.41.0...v1.42.0) (2026-06-22)


### Features

* **ingress:** front Splunk management API (8089) at splunk-mgmt ([#485](https://github.com/dryvist/terraform-proxmox/issues/485)) ([6ca9145](https://github.com/dryvist/terraform-proxmox/commit/6ca9145c90cd2600d5b1a590762b8fa999d892ff))

## [1.41.0](https://github.com/dryvist/terraform-proxmox/compare/v1.40.1...v1.41.0) (2026-06-21)


### Features

* **ci:** dispatch downstream revalidation on release ([#479](https://github.com/dryvist/terraform-proxmox/issues/479)) ([ee9322d](https://github.com/dryvist/terraform-proxmox/commit/ee9322d2f58e070a714e937ec6e31f45a8088927))

## [1.40.1](https://github.com/dryvist/terraform-proxmox/compare/v1.40.0...v1.40.1) (2026-06-20)


### Bug Fixes

* **docs:** rename netmon metric index to netmon_metrics ([#477](https://github.com/dryvist/terraform-proxmox/issues/477)) ([7ec6a15](https://github.com/dryvist/terraform-proxmox/commit/7ec6a153a44391efeee8c0f8f6e341bb9e57c0a6))

## [1.40.0](https://github.com/dryvist/terraform-proxmox/compare/v1.39.0...v1.40.0) (2026-06-19)


### Features

* **object-storage:** add RustFS LXC alongside MinIO for migration ([#472](https://github.com/dryvist/terraform-proxmox/issues/472)) ([d58116e](https://github.com/dryvist/terraform-proxmox/commit/d58116ef6ef4cc4e358ae38fc347e1f6d2fe998a))

## [1.39.0](https://github.com/dryvist/terraform-proxmox/compare/v1.38.2...v1.39.0) (2026-06-19)


### Features

* **servarr-config:** scheduled tofu-plan drift detection on self-hosted runner ([#471](https://github.com/dryvist/terraform-proxmox/issues/471)) ([50ab314](https://github.com/dryvist/terraform-proxmox/commit/50ab314065fd744ac10405a4cc021ff08ea9b2e8))

## [1.38.2](https://github.com/dryvist/terraform-proxmox/compare/v1.38.1...v1.38.2) (2026-06-17)


### Bug Fixes

* **firewall:** open TCP 9201 on cribl_stream containers for prometheus_rw ([#465](https://github.com/dryvist/terraform-proxmox/issues/465)) ([52bc357](https://github.com/dryvist/terraform-proxmox/commit/52bc3574ced96f99f5be0292656ecbf14dbe12b4))

## [1.38.1](https://github.com/dryvist/terraform-proxmox/compare/v1.38.0...v1.38.1) (2026-06-16)


### Bug Fixes

* **ingress:** drop the dead pi-hole route (no Pi-hole app on that backend) ([#463](https://github.com/dryvist/terraform-proxmox/issues/463)) ([e7e2cfc](https://github.com/dryvist/terraform-proxmox/commit/e7e2cfcd3a9a483d4d235513f1c516282a95c8e9))

## [1.38.0](https://github.com/dryvist/terraform-proxmox/compare/v1.37.0...v1.38.0) (2026-06-15)


### Features

* **storage:** document the appdata dataset for persistent app config ([9b3c1da](https://github.com/dryvist/terraform-proxmox/commit/9b3c1dace8d52318d1a3a359131bc22f7dfd6c01))

## [1.37.0](https://github.com/dryvist/terraform-proxmox/compare/v1.36.0...v1.37.0) (2026-06-15)


### Features

* **object-storage:** add RustFS object-storage LXC alongside MinIO for migration ([#456](https://github.com/dryvist/terraform-proxmox/issues/456)) ([1743a52](https://github.com/dryvist/terraform-proxmox/commit/1743a523f4a232bc33423de80cc0d4d363c38fcf))
* **proxmox-container:** derive Docker-in-LXC features from the docker tag ([#457](https://github.com/dryvist/terraform-proxmox/issues/457)) ([75db4a4](https://github.com/dryvist/terraform-proxmox/commit/75db4a472f68e3900fbb35aa05bb8eaf7bd2a3e6))

## [1.36.0](https://github.com/dryvist/terraform-proxmox/compare/v1.35.1...v1.36.0) (2026-06-14)


### Features

* **inventory:** gate the S3 publish on a precondition, fail before writing garbage ([3f0e2c9](https://github.com/dryvist/terraform-proxmox/commit/3f0e2c976184ff943758a48ce0706cb6241feb56))

## [1.35.1](https://github.com/dryvist/terraform-proxmox/compare/v1.35.0...v1.35.1) (2026-06-14)


### Bug Fixes

* **servarr-config:** align committed config to adopted live state ([#451](https://github.com/dryvist/terraform-proxmox/issues/451)) ([1497d55](https://github.com/dryvist/terraform-proxmox/commit/1497d5594537a7dc9a5481160784f978db316ce4))

## [1.35.0](https://github.com/dryvist/terraform-proxmox/compare/v1.34.1...v1.35.0) (2026-06-14)


### Features

* **servarr-config:** declarative Sonarr/Radarr config via devopsarr ([#448](https://github.com/dryvist/terraform-proxmox/issues/448)) ([d2352a7](https://github.com/dryvist/terraform-proxmox/commit/d2352a753b80da8fb8582b722ab59ff75ec1e84f))

## [1.34.1](https://github.com/dryvist/terraform-proxmox/compare/v1.34.0...v1.34.1) (2026-06-14)


### Bug Fixes

* **locals:** support static-IP exception hosts with positional VMIDs ([a6cceea](https://github.com/dryvist/terraform-proxmox/commit/a6cceeaa09c757ac037e0dd9f5438095e15e9004))

## [1.34.0](https://github.com/dryvist/terraform-proxmox/compare/v1.33.2...v1.34.0) (2026-06-14)


### Features

* **containers:** document unifi-metrics LXC for UniFi telemetry collector ([#440](https://github.com/dryvist/terraform-proxmox/issues/440)) ([ab33469](https://github.com/dryvist/terraform-proxmox/commit/ab334695e8c5146332ed71f2dace95bfbb473ce9))

## [1.33.2](https://github.com/dryvist/terraform-proxmox/compare/v1.33.1...v1.33.2) (2026-06-14)


### Bug Fixes

* **container:** ignore mount_point drift so applies don't replace media LXCs ([#439](https://github.com/dryvist/terraform-proxmox/issues/439)) ([f722f54](https://github.com/dryvist/terraform-proxmox/commit/f722f5434e4e62f7b9097de03fdd785684799a53))

## [1.33.1](https://github.com/dryvist/terraform-proxmox/compare/v1.33.0...v1.33.1) (2026-06-12)


### Bug Fixes

* **ci:** repoint shared reusable workflows to dryvist org ([#436](https://github.com/dryvist/terraform-proxmox/issues/436)) ([272eb26](https://github.com/dryvist/terraform-proxmox/commit/272eb264ef8462095e0e8f2225ec474021759388))

## [1.33.0](https://github.com/dryvist/terraform-proxmox/compare/v1.32.0...v1.33.0) (2026-06-12)


### Features

* **containers:** deterministic MAC + reserved-IP contract for DHCP-first guests ([#430](https://github.com/dryvist/terraform-proxmox/issues/430)) ([9103512](https://github.com/dryvist/terraform-proxmox/commit/91035129dab73e2a01eddfce25a19c694118db8f))
* **firewall:** cribl_s2s port 10300 for remote Edge -&gt; HAProxy -&gt; Stream ([#424](https://github.com/dryvist/terraform-proxmox/issues/424)) ([93bb34f](https://github.com/dryvist/terraform-proxmox/commit/93bb34f3d5962739ee1a06cb90b47e7e5247be63))
* **storage:** document the databases dataset shape in deployment.json.example ([#426](https://github.com/dryvist/terraform-proxmox/issues/426)) ([10472ce](https://github.com/dryvist/terraform-proxmox/commit/10472cec6ae10b4ebe828ab62c401966089efd88))


### Bug Fixes

* **splunk:** deploy natively — drop dead :10.0.2 compose, pre-own /opt/splunk as 41812 ([#425](https://github.com/dryvist/terraform-proxmox/issues/425)) ([4fd485d](https://github.com/dryvist/terraform-proxmox/commit/4fd485d871dc4283c86836ed07420e3a58e261bb))
* **sync:** env-driven sync destination; detect untracked changes; PR-based commit flow ([#428](https://github.com/dryvist/terraform-proxmox/issues/428)) ([f7bcae1](https://github.com/dryvist/terraform-proxmox/commit/f7bcae140054149aa0e94426c3b001100b3a06e6))
* **terragrunt:** wait on held state locks instead of failing (-lock-timeout=10m) ([#431](https://github.com/dryvist/terraform-proxmox/issues/431)) ([3e819ee](https://github.com/dryvist/terraform-proxmox/commit/3e819eef7f214d764f64f543bd5d8a68463f6f33))
* **vm:** ignore cloud-init dns drift to avoid rebuilding the non-removable ide2 drive ([#432](https://github.com/dryvist/terraform-proxmox/issues/432)) ([e888eb7](https://github.com/dryvist/terraform-proxmox/commit/e888eb7b5127ac98c435af710f70fd6c01a0c7df))

## [1.32.0](https://github.com/dryvist/terraform-proxmox/compare/v1.31.0...v1.32.0) (2026-06-11)


### Features

* **vm:** explicit guest DNS servers derived from the DNS containers ([#419](https://github.com/dryvist/terraform-proxmox/issues/419)) ([2979bee](https://github.com/dryvist/terraform-proxmox/commit/2979beef2e3c9be4058c94f00a3e864d52d16521))

## [1.31.0](https://github.com/dryvist/terraform-proxmox/compare/v1.30.2...v1.31.0) (2026-06-11)


### Features

* **pipeline:** single-source syslog port map + standard-frontend firewall + Cribl telemetry egress ([#416](https://github.com/dryvist/terraform-proxmox/issues/416)) ([f9ed855](https://github.com/dryvist/terraform-proxmox/commit/f9ed855eb636107764f09945696d27c8f5ec4f95))

## [1.30.2](https://github.com/dryvist/terraform-proxmox/compare/v1.30.1...v1.30.2) (2026-06-10)


### Bug Fixes

* **ci:** grant actions:read to retrigger-pr-checks caller ([#414](https://github.com/dryvist/terraform-proxmox/issues/414)) ([5e9658d](https://github.com/dryvist/terraform-proxmox/commit/5e9658dbe58a8f2e07bb4985cd5c0901b464e365))

## [1.30.1](https://github.com/dryvist/terraform-proxmox/compare/v1.30.0...v1.30.1) (2026-06-10)


### Bug Fixes

* **firewall:** allow inbound HEC on cribl_edge for netmon probers ([#411](https://github.com/dryvist/terraform-proxmox/issues/411)) ([9f1bf31](https://github.com/dryvist/terraform-proxmox/commit/9f1bf31a7a89761c38c7594f915358378cc6593e))

## [1.30.0](https://github.com/dryvist/terraform-proxmox/compare/v1.29.0...v1.30.0) (2026-06-10)


### Features

* **monitoring:** adopt 6-digit VMID + DHCP/DNS-first addressing ([#409](https://github.com/dryvist/terraform-proxmox/issues/409)) ([c36ef1e](https://github.com/dryvist/terraform-proxmox/commit/c36ef1e52a2f65f72208efac4990779836c42c1c))

## [1.29.0](https://github.com/dryvist/terraform-proxmox/compare/v1.28.0...v1.29.0) (2026-06-09)


### Features

* **inventory:** publish ansible_inventory to S3 (native aws_s3_object) ([#404](https://github.com/dryvist/terraform-proxmox/issues/404)) ([cef048c](https://github.com/dryvist/terraform-proxmox/commit/cef048cc3b1e84a1f2cf7918cf8f21bfb0da3d58))

## [1.28.0](https://github.com/dryvist/terraform-proxmox/compare/v1.27.0...v1.28.0) (2026-06-09)


### Features

* **monitoring:** harden network-quality stack to Prometheus-native ([#403](https://github.com/dryvist/terraform-proxmox/issues/403)) ([a98962f](https://github.com/dryvist/terraform-proxmox/commit/a98962fa6b4f4501f2aff6d0e76dfb083cdd04ab))

## [1.27.0](https://github.com/dryvist/terraform-proxmox/compare/v1.26.0...v1.27.0) (2026-06-09)


### Features

* **monitoring:** add per-WAN network-diagnosis probers and netmon Splunk index ([#401](https://github.com/dryvist/terraform-proxmox/issues/401)) ([6160211](https://github.com/dryvist/terraform-proxmox/commit/6160211ede91ae04778caea6e72ccf5d74b10289))

## [1.26.0](https://github.com/dryvist/terraform-proxmox/compare/v1.25.1...v1.26.0) (2026-06-09)


### Features

* **ingress:** add Proxmox cluster UI apex route (subdomain apex) ([#400](https://github.com/dryvist/terraform-proxmox/issues/400)) ([147be78](https://github.com/dryvist/terraform-proxmox/commit/147be78016f36d6dba5ded079edf45e8dbaddedd))

## [1.25.1](https://github.com/dryvist/terraform-proxmox/compare/v1.25.0...v1.25.1) (2026-06-07)


### Bug Fixes

* **monitoring:** correct SmokePing vm_id from placeholder 150 to 196 ([#396](https://github.com/dryvist/terraform-proxmox/issues/396)) ([8b52848](https://github.com/dryvist/terraform-proxmox/commit/8b528488215bbb9f3008c615a2e0dc176cd0e41d))

## [1.25.0](https://github.com/dryvist/terraform-proxmox/compare/v1.24.2...v1.25.0) (2026-06-07)


### Features

* **monitoring:** add SmokePing + speedtest network-quality LXC ([#394](https://github.com/dryvist/terraform-proxmox/issues/394)) ([713c35a](https://github.com/dryvist/terraform-proxmox/commit/713c35abf57e4742299314a0f9aa0c7c6ebe5ae7))

## [1.24.2](https://github.com/dryvist/terraform-proxmox/compare/v1.24.1...v1.24.2) (2026-06-07)


### Bug Fixes

* **storage:** replace deprecated proxmox_virtual_environment_datastores with proxmox_datastores ([#392](https://github.com/dryvist/terraform-proxmox/issues/392)) ([9aee7bf](https://github.com/dryvist/terraform-proxmox/commit/9aee7bf655b89c099df5d2be613f3e5daf45132d))

## [1.24.1](https://github.com/dryvist/terraform-proxmox/compare/v1.24.0...v1.24.1) (2026-06-06)


### Bug Fixes

* **splunk-vm:** ignore disk drift to unblock apply on live bootdisk ([#390](https://github.com/dryvist/terraform-proxmox/issues/390)) ([a2a5cf3](https://github.com/dryvist/terraform-proxmox/commit/a2a5cf3752eb20debabad76130fad46d1c63664b))

## [1.24.0](https://github.com/dryvist/terraform-proxmox/compare/v1.23.0...v1.24.0) (2026-06-05)


### Features

* **ingress:** expose Ollama API via Traefik ([#387](https://github.com/dryvist/terraform-proxmox/issues/387)) ([f489003](https://github.com/dryvist/terraform-proxmox/commit/f489003e2767a348f7b8bdd9668ab5d15282e5a9))

## [1.23.0](https://github.com/dryvist/terraform-proxmox/compare/v1.22.3...v1.23.0) (2026-06-05)


### Features

* **secrets:** scaffold OpenBao secrets manager IaC (Raft node 1) ([2d27e0e](https://github.com/dryvist/terraform-proxmox/commit/2d27e0ee5eddc73da53f22ee0c870642844e6701))

## [1.22.3](https://github.com/dryvist/terraform-proxmox/compare/v1.22.2...v1.22.3) (2026-06-04)


### Bug Fixes

* **security:** constrain PBS ISO Renovate version regex ([#383](https://github.com/dryvist/terraform-proxmox/issues/383)) ([39aa2e0](https://github.com/dryvist/terraform-proxmox/commit/39aa2e0f2c1e5f946bc37b42594080d9cffafe84))

## [1.22.2](https://github.com/dryvist/terraform-proxmox/compare/v1.22.1...v1.22.2) (2026-06-04)


### Bug Fixes

* **storage:** bump PBS ISO to 4.2-1, track via Renovate ([#381](https://github.com/dryvist/terraform-proxmox/issues/381)) ([e0c17bc](https://github.com/dryvist/terraform-proxmox/commit/e0c17bc4c5a73383f9b0d90f95dede4a7add17f5))

## [1.22.1](https://github.com/dryvist/terraform-proxmox/compare/v1.22.0...v1.22.1) (2026-06-04)


### Bug Fixes

* **dev:** point nix-devenv flake ref at dryvist owner ([#379](https://github.com/dryvist/terraform-proxmox/issues/379)) ([f8a17b3](https://github.com/dryvist/terraform-proxmox/commit/f8a17b30fba87b1bb9cd39400d7f3cf30bc1b5f8))

## [1.22.0](https://github.com/dryvist/terraform-proxmox/compare/v1.21.0...v1.22.0) (2026-06-04)


### Features

* **backup:** PBS appliance VM (ISO) declaration + ISO var ([#377](https://github.com/dryvist/terraform-proxmox/issues/377)) ([b1f753e](https://github.com/dryvist/terraform-proxmox/commit/b1f753e951b1d2031ab9fb4080264258264b33f5))

## [1.21.0](https://github.com/dryvist/terraform-proxmox/compare/v1.20.0...v1.21.0) (2026-06-04)


### Features

* **storage:** per-dataset ZFS properties in node_storage ([#374](https://github.com/dryvist/terraform-proxmox/issues/374)) ([1bd422b](https://github.com/dryvist/terraform-proxmox/commit/1bd422b98f884335ee34a8b945db91fa004e7a84))

## [1.20.0](https://github.com/dryvist/terraform-proxmox/compare/v1.19.0...v1.20.0) (2026-06-04)


### Features

* **splunk:** mark splunk ingress as https backend ([#372](https://github.com/dryvist/terraform-proxmox/issues/372)) ([0e4926f](https://github.com/dryvist/terraform-proxmox/commit/0e4926f93dbe11d59bc69ecebea319fc1a5bc978))

## [1.19.0](https://github.com/dryvist/terraform-proxmox/compare/v1.18.1...v1.19.0) (2026-06-04)


### Features

* **splunk:** tag splunk NIC onto siem VLAN + front via Traefik ([#369](https://github.com/dryvist/terraform-proxmox/issues/369)) ([6c98875](https://github.com/dryvist/terraform-proxmox/commit/6c9887567900b5fcfa6c3dbaa6ec4895baba489b))

## [1.18.1](https://github.com/dryvist/terraform-proxmox/compare/v1.18.0...v1.18.1) (2026-06-04)


### Bug Fixes

* **vm:** ignore cloud-init ip_config drift to avoid rebuilding the non-removable cloud-init drive ([#366](https://github.com/dryvist/terraform-proxmox/issues/366)) ([920f2a8](https://github.com/dryvist/terraform-proxmox/commit/920f2a8c63a1f18214b0e0bc20eca808c438d281))

## [1.18.0](https://github.com/dryvist/terraform-proxmox/compare/v1.17.0...v1.18.0) (2026-06-04)


### Features

* **ingress:** expose Open WebUI (llm) via Traefik + add LLM service ports ([#362](https://github.com/dryvist/terraform-proxmox/issues/362)) ([2607ca3](https://github.com/dryvist/terraform-proxmox/commit/2607ca340bddbde4c358796f897c17bf04c553ca))

## [1.17.0](https://github.com/dryvist/terraform-proxmox/compare/v1.16.0...v1.17.0) (2026-06-03)


### Features

* **network:** untagged-native NIC support + static IP override ([fa50592](https://github.com/dryvist/terraform-proxmox/commit/fa5059252a133b2f798bc986a0528d8954fac36c))

## [1.16.0](https://github.com/dryvist/terraform-proxmox/compare/v1.15.0...v1.16.0) (2026-06-03)


### Features

* **network:** rename lan_mgmt→mgmt; place Traefik ingress on mgmt VLAN ([#358](https://github.com/dryvist/terraform-proxmox/issues/358)) ([428d3da](https://github.com/dryvist/terraform-proxmox/commit/428d3da174a147cea7ae95e20e230a2ac74ca736))

## [1.15.0](https://github.com/dryvist/terraform-proxmox/compare/v1.14.0...v1.15.0) (2026-06-03)


### Features

* **inventory:** validate ansible_inventory against the schema before sync ([#356](https://github.com/dryvist/terraform-proxmox/issues/356)) ([402c5c9](https://github.com/dryvist/terraform-proxmox/commit/402c5c903f4841a980bc52161e423c9cbc45e027))

## [1.14.0](https://github.com/dryvist/terraform-proxmox/compare/v1.13.0...v1.14.0) (2026-06-03)


### Features

* **ingress:** single inventory-derived ingress route table (DRY) ([#352](https://github.com/dryvist/terraform-proxmox/issues/352)) ([c4bd8f8](https://github.com/dryvist/terraform-proxmox/commit/c4bd8f83d1316aff20caf712e2f14a418b4e4e74))
* **media:** declare Traefik TLS ingress LXC (215) on media VLAN ([#351](https://github.com/dryvist/terraform-proxmox/issues/351)) ([c2b9913](https://github.com/dryvist/terraform-proxmox/commit/c2b9913c0bab63914d91435f7121e3c347fabd17))


### Bug Fixes

* **terragrunt:** resolve inventory sync to public worktree layout ([#349](https://github.com/dryvist/terraform-proxmox/issues/349)) ([a84ae73](https://github.com/dryvist/terraform-proxmox/commit/a84ae73955db914db4d9f5bd5816536b5baa2abf))

## [1.13.0](https://github.com/dryvist/terraform-proxmox/compare/v1.12.0...v1.13.0) (2026-06-02)


### Features

* **ci:** multi-layer secret scanning (gitleaks + private denylist) ([#339](https://github.com/dryvist/terraform-proxmox/issues/339)) ([1cb3e35](https://github.com/dryvist/terraform-proxmox/commit/1cb3e351f4c6b460d82d0eb3e3b66dca23c56b78))
* **sops:** add plex_claim_token to terraform.sops.json ([#347](https://github.com/dryvist/terraform-proxmox/issues/347)) ([63a901f](https://github.com/dryvist/terraform-proxmox/commit/63a901feae00a543b33249f9f704c663b2be2a29))

## [1.12.0](https://github.com/dryvist/terraform-proxmox/compare/v1.11.0...v1.12.0) (2026-06-01)


### Features

* **idrac:** manage idrac-kvm (251) as Docker-in-LXC on ports 5410/5710 ([#324](https://github.com/dryvist/terraform-proxmox/issues/324)) ([7d9d19e](https://github.com/dryvist/terraform-proxmox/commit/7d9d19ec3e3fad43a9b6ca94fa6911340cc7c133))
* **media:** add Jellyseerr request UI (LXC 214) on media_svc ([#336](https://github.com/dryvist/terraform-proxmox/issues/336)) ([3bd4d5f](https://github.com/dryvist/terraform-proxmox/commit/3bd4d5f2333d1391e12343c8edd785d1b17bebe9))
* **media:** redirect stack to proxmox-1 + declare rpool node_storage ([e39a02c](https://github.com/dryvist/terraform-proxmox/commit/e39a02c712302108632c1c696cd83ce4f854f163))
* **media:** VPN-locked media stack LXCs on proxmox-2 (download-vpn/sonarr/radarr/plex) ([#327](https://github.com/dryvist/terraform-proxmox/issues/327)) ([4673dc8](https://github.com/dryvist/terraform-proxmox/commit/4673dc8f34cd94f818ae5445a1824e43ee8c5340))
* **multi-node:** node placement, proxmox-2/proxmox-3 storage, safety gates ([#325](https://github.com/dryvist/terraform-proxmox/issues/325)) ([6b3277f](https://github.com/dryvist/terraform-proxmox/commit/6b3277f4e8764f27f0cdc3bb1f62e1a0c1cb3c4b))
* **network:** per-VLAN CIDR model replacing flat network_prefix ([#331](https://github.com/dryvist/terraform-proxmox/issues/331)) ([72b292d](https://github.com/dryvist/terraform-proxmox/commit/72b292d1b11181ef3b2c68c77b9e935d4b7ff99a))


### Bug Fixes

* **ci:** repoint release-please caller to org-native reusable workflow ([#342](https://github.com/dryvist/terraform-proxmox/issues/342)) ([31b8e07](https://github.com/dryvist/terraform-proxmox/commit/31b8e07dddecee33ce123b32d3437bbfe929b1b3))
* **ci:** retarget reusable-workflow uses: refs to current org homes ([#326](https://github.com/dryvist/terraform-proxmox/issues/326)) ([c7b2def](https://github.com/dryvist/terraform-proxmox/commit/c7b2def173e2d7ce16db4cf1d2a70e547d573f21))
* **media:** align node_name with live PVE member name proxmox-1 ([6420bdd](https://github.com/dryvist/terraform-proxmox/commit/6420bdd0839d5a187ef89cb90794201682be5ca5))

## [1.11.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.10.1...v1.11.0) (2026-05-25)


### Features

* **acme:** SAN list + per-LXC/VM cert delivery via null_resource ([#320](https://github.com/JacobPEvans/terraform-proxmox/issues/320)) ([591071a](https://github.com/JacobPEvans/terraform-proxmox/commit/591071a6fa2a7e841610b8107a1dd0d6e3dfe698))

## [1.10.1](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.10.0...v1.10.1) (2026-05-25)


### Bug Fixes

* **deployment:** drop keyctl/fuse from infisical+openproject features ([#318](https://github.com/JacobPEvans/terraform-proxmox/issues/318)) ([fdc4d36](https://github.com/JacobPEvans/terraform-proxmox/commit/fdc4d3613a2a73a6498e7fac0545eff4afbc7c94))

## [1.10.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.9.1...v1.10.0) (2026-05-24)


### Features

* provision Infisical LXC at vm_id 108 with firewall + DRY constants ([#315](https://github.com/JacobPEvans/terraform-proxmox/issues/315)) ([17ef7ea](https://github.com/JacobPEvans/terraform-proxmox/commit/17ef7ea761ed42766d9fba2d3e1071c025e9aee5))

## [1.9.1](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.9.0...v1.9.1) (2026-05-24)


### Bug Fixes

* initialize OpenTofu in Copilot setup workflow ([#301](https://github.com/JacobPEvans/terraform-proxmox/issues/301)) ([84fa2f1](https://github.com/JacobPEvans/terraform-proxmox/commit/84fa2f10d90f0ca41368271dea7102b58bccc228))

## [1.9.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.8.0...v1.9.0) (2026-05-20)


### Features

* **poweredge:** declarative inventory module for cluster join ([#296](https://github.com/JacobPEvans/terraform-proxmox/issues/296)) ([40fabb3](https://github.com/JacobPEvans/terraform-proxmox/commit/40fabb3b594a2bc6428ef38119b0e445bfed150e))

## [1.8.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.7.0...v1.8.0) (2026-05-16)


### Features

* **firewall:** add idrac-kvm VM 251 with tag-driven internal firewall ([#294](https://github.com/JacobPEvans/terraform-proxmox/issues/294)) ([a67c2fa](https://github.com/JacobPEvans/terraform-proxmox/commit/a67c2fab125a2074d371797678c6c88205d97264))
* **firewall:** allow UDP/123 from VM subnets to Proxmox hosts ([#290](https://github.com/JacobPEvans/terraform-proxmox/issues/290)) ([c55ed2f](https://github.com/JacobPEvans/terraform-proxmox/commit/c55ed2f2f5814b8c06ef3b6602a4b3fb9d6db535)), closes [#285](https://github.com/JacobPEvans/terraform-proxmox/issues/285)

## [1.7.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.6.5...v1.7.0) (2026-05-14)


### Features

* **containers:** add OpenProject Community Edition LXC ([#284](https://github.com/JacobPEvans/terraform-proxmox/issues/284)) ([4d7cead](https://github.com/JacobPEvans/terraform-proxmox/commit/4d7ceadfdd7e49704eaedb9868516f23dbac77b1))

## [1.6.5](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.6.4...v1.6.5) (2026-05-07)


### Bug Fixes

* **acme:** complete proxmox_acme_* rename with state migration ([#270](https://github.com/JacobPEvans/terraform-proxmox/issues/270)) ([5afe3f1](https://github.com/JacobPEvans/terraform-proxmox/commit/5afe3f1aeb614603914fa005a65c544bfcc38b50))
* **tests:** add missing validation tests for 17 variable blocks ([#272](https://github.com/JacobPEvans/terraform-proxmox/issues/272)) ([1e999ed](https://github.com/JacobPEvans/terraform-proxmox/commit/1e999ed218d1eef9c1f5af6483a40e51800c275e))

## [1.6.4](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.6.3...v1.6.4) (2026-05-06)


### Bug Fixes

* re-enable checkov security scanning, bump rev to 3.2.526 ([#126](https://github.com/JacobPEvans/terraform-proxmox/issues/126)) [issue-solver-2026-05-06] ([736909e](https://github.com/JacobPEvans/terraform-proxmox/commit/736909e171da3fe884643b51787a306b6c0023af))

## [1.6.3](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.6.2...v1.6.3) (2026-05-06)


### Bug Fixes

* **ci:** remove deprecated app-id secret passthrough ([a9b2cbd](https://github.com/JacobPEvans/terraform-proxmox/commit/a9b2cbd78b27d200b7b57916e828e1ca7057cd9a))

## [1.6.2](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.6.1...v1.6.2) (2026-04-21)


### Bug Fixes

* add bot PR CI retrigger workflow ([#261](https://github.com/JacobPEvans/terraform-proxmox/issues/261)) ([91a8814](https://github.com/JacobPEvans/terraform-proxmox/commit/91a88141e1932cb42499a59c60513e800433e0f4))

## [1.6.1](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.6.0...v1.6.1) (2026-04-18)


### Bug Fixes

* assume credentials in environment for pre-push hooks ([#258](https://github.com/JacobPEvans/terraform-proxmox/issues/258)) ([fd1eca1](https://github.com/JacobPEvans/terraform-proxmox/commit/fd1eca10447c6e031d0d48d528b70e281d69b641))

## [1.6.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.5.3...v1.6.0) (2026-04-18)


### Features

* declare Samba NAS inventory contract ([#254](https://github.com/JacobPEvans/terraform-proxmox/issues/254)) ([6ac67b3](https://github.com/JacobPEvans/terraform-proxmox/commit/6ac67b3ba5b047f050b96a7e2b6c0e1455e95b44))

## [1.5.3](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.5.2...v1.5.3) (2026-04-13)


### Bug Fixes

* recompile gh-aw workflows with v0.68.1 ([d858ec3](https://github.com/JacobPEvans/terraform-proxmox/commit/d858ec311d9659acfd6df7494b643354ad281edb))

## [1.5.2](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.5.1...v1.5.2) (2026-04-12)


### Bug Fixes

* correct Cribl Stream API port to 9000 ([#228](https://github.com/JacobPEvans/terraform-proxmox/issues/228)) ([a42f6bb](https://github.com/JacobPEvans/terraform-proxmox/commit/a42f6bbf823a7b082ab9daf6efec2adc60b04bc1))

## [1.5.1](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.5.0...v1.5.1) (2026-04-12)


### Bug Fixes

* correct Cribl Edge API port to 9420 and support assumed-role credentials in hooks ([#223](https://github.com/JacobPEvans/terraform-proxmox/issues/223)) ([9e2ff12](https://github.com/JacobPEvans/terraform-proxmox/commit/9e2ff12c2745d2f4c6ec6804171dd219c402026f))

## [1.5.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.4.0...v1.5.0) (2026-04-08)


### Features

* add AI merge gate ([#215](https://github.com/JacobPEvans/terraform-proxmox/issues/215)) ([c45e616](https://github.com/JacobPEvans/terraform-proxmox/commit/c45e61639230a0c315e59cdf1975d4f8ca73b160))

## [1.4.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.3.2...v1.4.0) (2026-04-07)


### Features

* add MinIO LXC container for artifact storage ([#216](https://github.com/JacobPEvans/terraform-proxmox/issues/216)) ([2b16d08](https://github.com/JacobPEvans/terraform-proxmox/commit/2b16d0849b1314aae096d1a2a0da56a77b15557d))

## [1.3.2](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.3.1...v1.3.2) (2026-04-04)


### Bug Fixes

* remove claude-review workflow — replaced by Gemini + Copilot ([#212](https://github.com/JacobPEvans/terraform-proxmox/issues/212)) ([928b6f6](https://github.com/JacobPEvans/terraform-proxmox/commit/928b6f6c90426b108074cf23a5c24c22d72902ce))

## [1.3.1](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.3.0...v1.3.1) (2026-04-02)


### Bug Fixes

* use nix-devenv terraform shell instead of local flake.nix ([#210](https://github.com/JacobPEvans/terraform-proxmox/issues/210)) ([e1b7a61](https://github.com/JacobPEvans/terraform-proxmox/commit/e1b7a61a82cb7419cdd3983629381a5f611fa44f))

## [1.3.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.2.1...v1.3.0) (2026-03-25)


### Features

* auto-sync inventory to downstream repos after apply ([#207](https://github.com/JacobPEvans/terraform-proxmox/issues/207)) ([2fc6fb4](https://github.com/JacobPEvans/terraform-proxmox/commit/2fc6fb47d3b5c65fece2c280f675464dec73680e))

## [1.2.1](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.2.0...v1.2.1) (2026-03-25)


### Bug Fixes

* sync terragrunt provider version with main.tf ([#206](https://github.com/JacobPEvans/terraform-proxmox/issues/206)) ([e9a6ef7](https://github.com/JacobPEvans/terraform-proxmox/commit/e9a6ef7e9d7d613211d773925c00250faad47559))

## [1.2.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.1.0...v1.2.0) (2026-03-22)


### Features

* add FQDN auto-config and pipeline container definitions ([#185](https://github.com/JacobPEvans/terraform-proxmox/issues/185)) ([7f2a6e4](https://github.com/JacobPEvans/terraform-proxmox/commit/7f2a6e42b19783cb64e5d5ab1657f684b3e7b034))
* add host-level NAS storage config for ansible-proxmox consumption ([#184](https://github.com/JacobPEvans/terraform-proxmox/issues/184)) ([71fa736](https://github.com/JacobPEvans/terraform-proxmox/commit/71fa736e9d76baf1719c12313b86e9810f2a7bde))
* add LlamaIndex container and fix Qdrant swap ([#194](https://github.com/JacobPEvans/terraform-proxmox/issues/194)) ([54f42d3](https://github.com/JacobPEvans/terraform-proxmox/commit/54f42d3d328170b3dad47632f0c73c0dada97171))
* complete deployment.json migration, delete terraform.tfvars ([#186](https://github.com/JacobPEvans/terraform-proxmox/issues/186)) ([30cef3c](https://github.com/JacobPEvans/terraform-proxmox/commit/30cef3c95ae01dd7dbced434dc6021f11c6e3116))


### Bug Fixes

* add .file-size.yml with extended limit for TROUBLESHOOTING ([#199](https://github.com/JacobPEvans/terraform-proxmox/issues/199)) ([5da46ee](https://github.com/JacobPEvans/terraform-proxmox/commit/5da46ee867f301244e20140bf5dfee1fdf62f1ae))
* add release-please config for manifest mode ([f17447f](https://github.com/JacobPEvans/terraform-proxmox/commit/f17447f8f0550451b6571cc352fcf7238232f0dd))
* add syslog and netflow firewall rules to Cribl Stream containers ([#189](https://github.com/JacobPEvans/terraform-proxmox/issues/189)) ([51737aa](https://github.com/JacobPEvans/terraform-proxmox/commit/51737aa0b845d321a3a0af3c2073a2328f98071d))
* **ci:** add pull-requests:write for release-please auto-approve ([8dfe391](https://github.com/JacobPEvans/terraform-proxmox/commit/8dfe391755961c81aa0ed6a2363a4bdf188df6bb))
* **ci:** implement Merge Gatekeeper pattern with ci-gate.yml ([#187](https://github.com/JacobPEvans/terraform-proxmox/issues/187)) ([dc3126f](https://github.com/JacobPEvans/terraform-proxmox/commit/dc3126fca6e86f7698b489d3080d18eb942cf4eb))
* split oversized files and resolve lint errors blocking CI ([#203](https://github.com/JacobPEvans/terraform-proxmox/issues/203)) ([36b77df](https://github.com/JacobPEvans/terraform-proxmox/commit/36b77df4fae09fecd65889ddfaf68b01f53acff0))
* sync release-please config, permissions, VERSION, and unpin workflow ([c8f7b1a](https://github.com/JacobPEvans/terraform-proxmox/commit/c8f7b1a0a7548ebfaf0498adc2428602279fe27a))

## [1.1.0](https://github.com/JacobPEvans/terraform-proxmox/compare/v1.0.0...v1.1.0) (2026-03-11)


### Features

* add ansible_inventory output for dynamic Ansible integration ([#85](https://github.com/JacobPEvans/terraform-proxmox/issues/85)) ([8835db4](https://github.com/JacobPEvans/terraform-proxmox/commit/8835db429834cec83894eac55655720111744dca))
* add apt-cacher-ng LXC container (VMID 106) ([#179](https://github.com/JacobPEvans/terraform-proxmox/issues/179)) ([ad3efcb](https://github.com/JacobPEvans/terraform-proxmox/commit/ad3efcba1b574fea9cf31969cc46b88620a98d53))
* add CI auto-fix workflow and replace Claude Code placeholder ([#104](https://github.com/JacobPEvans/terraform-proxmox/issues/104)) ([79c2b93](https://github.com/JacobPEvans/terraform-proxmox/commit/79c2b9386c4079e7a8d683ad6b605eeaf9fe3365))
* add daily repo health audit agentic workflow ([#181](https://github.com/JacobPEvans/terraform-proxmox/issues/181)) ([4a16c51](https://github.com/JacobPEvans/terraform-proxmox/commit/4a16c5126e721cc09a4c0ec9384eddd844e71d35))
* add dynamic startup order to VM and container modules ([#78](https://github.com/JacobPEvans/terraform-proxmox/issues/78)) ([4adf4fb](https://github.com/JacobPEvans/terraform-proxmox/commit/4adf4fb834fa9ad7c458a4f70f3183ca20a834cb))
* add final PR review workflow ([#107](https://github.com/JacobPEvans/terraform-proxmox/issues/107)) ([e0cdb86](https://github.com/JacobPEvans/terraform-proxmox/commit/e0cdb8618275c6315f8a8acf09c01618c152088b))
* add HAProxy container, Cribl storage, and fix Splunk disk layout ([#82](https://github.com/JacobPEvans/terraform-proxmox/issues/82)) ([35abfb9](https://github.com/JacobPEvans/terraform-proxmox/commit/35abfb9164bbb44454854df9e20bb42e2ae1e832))
* add mailpit and ntfy LXC containers for notification services ([#132](https://github.com/JacobPEvans/terraform-proxmox/issues/132)) ([0545d8b](https://github.com/JacobPEvans/terraform-proxmox/commit/0545d8bb1ba52e9c0e2eb1a615f49c6ec116507a))
* add native SOPS/age integration via sops_decrypt_file() ([#113](https://github.com/JacobPEvans/terraform-proxmox/issues/113)) ([faf7bb2](https://github.com/JacobPEvans/terraform-proxmox/commit/faf7bb2f7da3377bff01dce23b9e6b9084169fa5))
* add netflow_ports to pipeline_constants and update docs ([#111](https://github.com/JacobPEvans/terraform-proxmox/issues/111)) ([267c4c1](https://github.com/JacobPEvans/terraform-proxmox/commit/267c4c12432f5ae895e40eb7dc581879cb4f4b49))
* add per-repo devShell with Terraform/Terragrunt tools ([#154](https://github.com/JacobPEvans/terraform-proxmox/issues/154)) ([3b05327](https://github.com/JacobPEvans/terraform-proxmox/commit/3b053271ae614d9d4c38187846a4eacd375b78bd))
* add Pi-Hole DNS container to infrastructure tier (ID 104) ([#80](https://github.com/JacobPEvans/terraform-proxmox/issues/80)) ([e735315](https://github.com/JacobPEvans/terraform-proxmox/commit/e7353153ae7b157c699a64678fa3aebb87555414))
* add Qdrant vector database container with firewall rules ([#177](https://github.com/JacobPEvans/terraform-proxmox/issues/177)) ([7a23464](https://github.com/JacobPEvans/terraform-proxmox/commit/7a23464c8610e7c0669ea8d3e987e57c9774be80))
* add SOPS/age secrets management integration ([e7518b7](https://github.com/JacobPEvans/terraform-proxmox/commit/e7518b7e244007ac3f813afebb0a4e7849c18581))
* adopt conventional branch standard (feature/, bugfix/) ([#168](https://github.com/JacobPEvans/terraform-proxmox/issues/168)) ([cb4cef8](https://github.com/JacobPEvans/terraform-proxmox/commit/cb4cef8eda1d531b89648ef33fc277e14a4b7ce5))
* auto-enable squash merge on all PRs when opened ([#144](https://github.com/JacobPEvans/terraform-proxmox/issues/144)) ([80d0ce8](https://github.com/JacobPEvans/terraform-proxmox/commit/80d0ce884e2a0d5bda0dd733cc27e5a9b793c059))
* **ci:** unified issue dispatch pattern with AI-created issue support ([#131](https://github.com/JacobPEvans/terraform-proxmox/issues/131)) ([7484143](https://github.com/JacobPEvans/terraform-proxmox/commit/74841430c3f0888ecfc698acc9754fe613b6e089))
* consolidate Splunk Docker deployment to ansible-splunk ([#90](https://github.com/JacobPEvans/terraform-proxmox/issues/90)) ([b26a848](https://github.com/JacobPEvans/terraform-proxmox/commit/b26a84878091ef00d9bba25b4e299e365bd2cb4f))
* **copilot:** add Copilot coding agent support + CI fail issue workflow ([#143](https://github.com/JacobPEvans/terraform-proxmox/issues/143)) ([64d6f43](https://github.com/JacobPEvans/terraform-proxmox/commit/64d6f4359f2ae6cad54d98225daf53dfcac88b01))
* create ansible inventory export script ([#88](https://github.com/JacobPEvans/terraform-proxmox/issues/88)) ([55a878d](https://github.com/JacobPEvans/terraform-proxmox/commit/55a878d03b138e4f25a9864da679dbcf1326b51d))
* disable automatic triggers on Claude-executing workflows ([41177a5](https://github.com/JacobPEvans/terraform-proxmox/commit/41177a5ae5e34dc6b5e0b86196180c346fb5be09))
* **firewall:** add netflow security group for UDP 2055 ([#93](https://github.com/JacobPEvans/terraform-proxmox/issues/93)) ([f742ab9](https://github.com/JacobPEvans/terraform-proxmox/commit/f742ab93186e71688ea4797232204919ee67dd6a))
* fuse LXC feature, dynamic container module, SOPS ssh username ([#134](https://github.com/JacobPEvans/terraform-proxmox/issues/134)) ([b66a4bc](https://github.com/JacobPEvans/terraform-proxmox/commit/b66a4bc427903268bc46027c9b3e3fbab27ee05b))
* **gh-aw:** add autonomous agentic workflows (Copilot engine) ([#151](https://github.com/JacobPEvans/terraform-proxmox/issues/151)) ([156120c](https://github.com/JacobPEvans/terraform-proxmox/commit/156120ca9add9b3e17d9c8fcc1de57b2d3d93a68))
* implement Docker-based Splunk VM with UniFi syslog ingestion ([#83](https://github.com/JacobPEvans/terraform-proxmox/issues/83)) ([f1fb448](https://github.com/JacobPEvans/terraform-proxmox/commit/f1fb448b702bdb2c858a22ca8a16603a21940bd0))
* **packer:** add systemd restart policy for Splunk service ([#79](https://github.com/JacobPEvans/terraform-proxmox/issues/79)) ([c84bebe](https://github.com/JacobPEvans/terraform-proxmox/commit/c84bebee7928c9393541d267b6cb4e24f91b1c9d))
* **pipeline:** add static IPs, docker_vms output, testing, and validation ([#99](https://github.com/JacobPEvans/terraform-proxmox/issues/99)) ([28a08c3](https://github.com/JacobPEvans/terraform-proxmox/commit/28a08c3ec33efc77b8e1adc0e25e9622e798f6eb))
* **renovate:** extend shared preset for org-wide auto-merge rules ([#148](https://github.com/JacobPEvans/terraform-proxmox/issues/148)) ([8a93126](https://github.com/JacobPEvans/terraform-proxmox/commit/8a9312614cdf6b7840f78130a217f79bf76aa6ad))
* split config into deployment.json (plaintext) + tiny SOPS + derived networks ([#129](https://github.com/JacobPEvans/terraform-proxmox/issues/129)) ([21f40dd](https://github.com/JacobPEvans/terraform-proxmox/commit/21f40dd805328a459afe186c736c74eaa30777f3))
* switch to ai-workflows reusable workflows ([#108](https://github.com/JacobPEvans/terraform-proxmox/issues/108)) ([c189b53](https://github.com/JacobPEvans/terraform-proxmox/commit/c189b53324501da42fac7134ec258262f8344db2))
* **terraform:** add vga_type support and env-specific tfvars loading ([#75](https://github.com/JacobPEvans/terraform-proxmox/issues/75)) ([1dd4710](https://github.com/JacobPEvans/terraform-proxmox/commit/1dd4710aa1673bfde98fa369a82d78f328dd2bea))


### Bug Fixes

* add splunk VM lifecycle protection and remove dead variables ([#115](https://github.com/JacobPEvans/terraform-proxmox/issues/115)) ([134e3eb](https://github.com/JacobPEvans/terraform-proxmox/commit/134e3ebf699e367bcf3835667c5232f75d82dc62))
* address devShell review feedback ([#155](https://github.com/JacobPEvans/terraform-proxmox/issues/155)) ([40b3947](https://github.com/JacobPEvans/terraform-proxmox/commit/40b3947afd806ed953f68657b4a4b86674b9fb20))
* address devShell review feedback ([#156](https://github.com/JacobPEvans/terraform-proxmox/issues/156)) ([0c6ca50](https://github.com/JacobPEvans/terraform-proxmox/commit/0c6ca506525d21a43a7e1946a7af5badf7ffc3b0))
* bump ai-workflows callers to v0.2.9 and add OIDC permissions ([#120](https://github.com/JacobPEvans/terraform-proxmox/issues/120)) ([0bb4a6c](https://github.com/JacobPEvans/terraform-proxmox/commit/0bb4a6c116b1dd41c201537ccc07f5f5e41515fb))
* bump all ai-workflows callers to v0.2.6 and add id-token:write ([#119](https://github.com/JacobPEvans/terraform-proxmox/issues/119)) ([3e6b4ef](https://github.com/JacobPEvans/terraform-proxmox/commit/3e6b4ef772a295315e727b419f5082d34ab393f1))
* bump all callers to ai-workflows v0.2.3 with explicit permissions ([#118](https://github.com/JacobPEvans/terraform-proxmox/issues/118)) ([781e621](https://github.com/JacobPEvans/terraform-proxmox/commit/781e6212ff8b9a3a6a7bdff5b5813320f973363f))
* **ci:** add dispatch pattern for post-merge and bot guard for triage ([#127](https://github.com/JacobPEvans/terraform-proxmox/issues/127)) ([64f2bcd](https://github.com/JacobPEvans/terraform-proxmox/commit/64f2bcda03cecfa6a470ef1314528e7b9ea85070))
* correct CIDR notation from /32 to /24 for standard LAN hosts ([32a5fc7](https://github.com/JacobPEvans/terraform-proxmox/commit/32a5fc7b910b5a6229b9c5200535be608edc9dc2))
* **docs:** replace leaked 10.0.1.x IPs with 192.168.1.x placeholders ([f45d476](https://github.com/JacobPEvans/terraform-proxmox/commit/f45d47652876434d862ac1f4c1fa39712e60e23b))
* **docs:** use /32 subnet mask and correct RFC reference ([41bfbd1](https://github.com/JacobPEvans/terraform-proxmox/commit/41bfbd1f2014ce30784aa4c6983f6fb05f99c1b6))
* **firewall:** add cluster firewall resource to enable VM-level rules ([#92](https://github.com/JacobPEvans/terraform-proxmox/issues/92)) ([98be51f](https://github.com/JacobPEvans/terraform-proxmox/commit/98be51f980dad1da118fe847358d61203e461ec3))
* **firewall:** add missing pipeline container port rules ([#114](https://github.com/JacobPEvans/terraform-proxmox/issues/114)) ([7918acf](https://github.com/JacobPEvans/terraform-proxmox/commit/7918acf55ff1980b584ee15e091d4bd87ef32c33))
* Packer template ID 9200 for Splunk Docker ([#91](https://github.com/JacobPEvans/terraform-proxmox/issues/91)) ([5f1f7d8](https://github.com/JacobPEvans/terraform-proxmox/commit/5f1f7d85fe78d4540617017fa15756f2a0a64dd3))
* remove .envrc from git tracking ([a714a89](https://github.com/JacobPEvans/terraform-proxmox/commit/a714a891153e6c1a6717d25f5910344ca90dcdec))
* remove blanket auto-merge workflow ([#171](https://github.com/JacobPEvans/terraform-proxmox/issues/171)) ([7920027](https://github.com/JacobPEvans/terraform-proxmox/commit/79200277f3a9d50e4616211dac077a647b26c96f))
* **splunk:** increase resources and fix data disk setup ([#110](https://github.com/JacobPEvans/terraform-proxmox/issues/110)) ([d0cd071](https://github.com/JacobPEvans/terraform-proxmox/commit/d0cd0713cf19d3facd6d4988b299bd7ba2c7ea19))
* use coalesce() for container IP derivation fallback ([#84](https://github.com/JacobPEvans/terraform-proxmox/issues/84)) ([be39d8e](https://github.com/JacobPEvans/terraform-proxmox/commit/be39d8e61aa16b14cc7bc1335f377e0fec2e2b81))
* use SPLUNK_ADMIN_PASSWORD envvar name to match Doppler ([#95](https://github.com/JacobPEvans/terraform-proxmox/issues/95)) ([3531043](https://github.com/JacobPEvans/terraform-proxmox/commit/3531043a8dac0025887b13e1a150ed05828f11a7))
