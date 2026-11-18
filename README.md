# marcelwalder-infra

Monorepo managing OCI cloud infrastructure, Porkbun DNS, server configuration, and the static CV site at [`marcelwalder.eu`](https://marcelwalder.eu/).

## Repository Structure

```text
marcelwalder-infra/
├── .github/workflows/
│   ├── infra.yml           # OpenTofu fmt, tflint, validate, weekly drift plan, PR plan comment, and gated apply
│   └── deploy-site.yml     # Self-hosted/CSP/Compose/ansible-lint guard, pinned-SSH Ansible deploy + smoke check
├── docs/
│   └── DR-RUNBOOK.md       # Backup verification, cold-start VM rebuild, and opentofu-ci rotation runbook
├── infra/
│   ├── modules/
│   │   ├── network/        # VCN, IGW, default route/security list, subnets, composable NSGs
│   │   ├── compute/        # Map-driven OCI VM instances + optional reserved public IPs
│   │   └── dns/            # Porkbun DNS record module
│   └── live/
│       ├── prod/           # Primary OCI stack (VCN, NSG, VM, versioned+lifecycle buckets, backup policy, Email Delivery, alarms, ONS, budget, least-privilege CI IAM)
│       └── dns/            # Porkbun DNS stack (consumes prod public IPs via remote state)
├── ansible/
│   ├── inventory/hosts.yml
│   ├── roles/              # Modular roles: base_os, firewall, ssh_wireguard, mail_stack, monitoring_backups
│   ├── files/
│   │   ├── mailserver/     # Docker-Mailserver & SnappyMail compose manifests and mail configs
│   │   ├── nginx/          # Hardened Nginx main config, snippets, ACME bootstrap template, and site vhosts
│   │   └── web/            # BIMI SVG assets and MTA-STS policy
│   └── playbooks/
│       ├── site.yml        # Multi-domain ACME bootstrap, sync site/, BIMI/MTA-STS assets, Nginx vhosts
│       ├── harden.yml      # Role-based VM hardening (native nftables, Fail2ban, WireGuard, mail, monitoring, Restic)
│       └── restore.yml     # Cold-start Restic S3 restore of /etc/letsencrypt, mail, SnappyMail, Kuma, and WireGuard
└── site/                   # Self-hosted static CV bundle (zero external font/avatar requests)
```

## Architecture Highlights

- **OpenTofu + OCI Object Storage Backend:** State is stored in private, versioned OCI Object Storage (`tfstate-marcelwalder-prod`, `eu-frankfurt-1`, `prevent_destroy = true`) with native S3 lockfiles (`use_lockfile = true`), bucket object lifecycle expiration (30-day non-current versions, 7-day aborted multipart uploads), committed multi-platform `.terraform.lock.hcl` files, weekly drift detection, and **client-side AES-GCM encryption** (`encryption.tf`).
- **Complete OCI Operational Guardrails:** `infra/live/prod` manages the `backups-marcelwalder-prod` and `tfstate-marcelwalder-prod` buckets (with lifecycle policies), `Mail-Server-NSG` per-instance firewalling, `Always-Free-Mail-Backup-Policy`, OCI Email Delivery (`marcelwalder.eu` domain, `dkim1`, approved senders), `Free-Tier-Quota-Alerts` ONS topic/subscription, modern `condition_details` backup completion events, Always Free down/idle-reclaim monitoring alarms, `Zero-Spend-Guard` budget/alert rules, and least-privilege `opentofu-ci` IAM user/group/policy.
- **Native `nftables` & All-Systemd Automation:** Host firewalling and Fail2ban (`banaction = nftables[type=multiport]`) run natively on `nftables` alongside country geoblocking (`marcelwalder_geoblock`) while preserving Docker `iptables-nft` chains and the Oracle `169.254.0.0/16` metadata guard. All scheduled jobs (OS patching, relay quota watchdog, daily encrypted Restic S3 backup + Uptime Kuma Push dead-man's switch, weekly `restic check --read-data-subset=5%`, geoblock refresh, GoAccess reports, and 2-minute self-healing watchdog) run as systemd timers with `OnFailure=` email alerts and capped `journald` storage (`SystemMaxUse=200M`).
- **Extensible Multi-VM Compute & DR Ready:** `infra/live/prod/topology.auto.tfvars` defines `instances` as a map. Cold-start rebuilds use `ansible/playbooks/restore.yml` + `harden.yml` + `site.yml` per [docs/DR-RUNBOOK.md](docs/DR-RUNBOOK.md).
- **Automated DNS Sync:** `infra/live/dns` reads `instance_public_ips` directly from `prod/terraform.tfstate` via `terraform_remote_state` and includes `imports.tf` for existing `marcelwalder.eu` records (`ha.marcelwalder.eu` is intentionally managed by a separate Home Assistant repository).
- **Strict GitOps & Automated Dependency Updates:** Container images (`docker-mailserver`, `snappymail`, `uptime-kuma`) are pinned to explicit versions and SHA256 digests in `ansible/files/` and reconciled by Ansible on deploy. [renovate.json](renovate.json) tracks weekly updates for GitHub Actions SHA pins, OpenTofu CLI/providers (against `registry.opentofu.org`), and Docker Compose digests.
- **Unattended Host Patching & Compliance CI:** `base_os` configures daily security-only `unattended-upgrades` (`ansible/files/apt/`, blacklisting `docker-ce*`, `containerd.io`, and `nginx*` from background restarts and keeping `Automatic-Reboot "false"`), paired with weekly `marcelwalder-os-update.timer` patching. PRs run `ansible-lint`, `tflint`, Compose validation, and asset/CSP checks; deploys pin the VM SSH key via `ansible/files/ssh/known_hosts` and skip `harden.yml` on `site/`-only updates.
- **4-Layer Failure Alerting + Dead-Man's Switch:** Real-time inbox alerts via direct OCI Email Delivery (`marcelwalder-send-alert`) from (1) Uptime Kuma SMTP notifications + backup Push heartbeat monitor, (2) a 2-minute self-healing host watchdog (`marcelwalder-healthcheck.timer`), (3) systemd `OnFailure=marcelwalder-alert@%n.service` hooks across all scheduled timers, and (4) OCI Cloud Monitoring (`Always-Free-Instance-Down-Guard`) when the VM itself is unreachable.

## Required GitHub Actions Secrets

Configure these in **Settings → Secrets and variables → Actions** (and optionally require manual reviewer approval on a `production` Environment):

| Secret | Used For |
| --- | --- |
| `OCI_S3_ACCESS_KEY_ID` | OCI Customer Secret Key ID for OpenTofu S3 state backend |
| `OCI_S3_SECRET_ACCESS_KEY` | OCI Customer Secret Key secret for OpenTofu S3 state backend |
| `TOFU_STATE_PASSPHRASE` | Client-side AES-GCM passphrase for state & plan encryption |
| `OCI_COMPARTMENT_OCID` | OCI Compartment / Tenancy OCID (`TF_VAR_compartment_id`) |
| `OCI_TENANCY_OCID` | OCI Tenancy OCID for provider auth |
| `OCI_USER_OCID` | OCI IAM User OCID for provider auth |
| `OCI_FINGERPRINT` | OCI API Key fingerprint |
| `OCI_PRIVATE_KEY_PEM` | Private PEM contents of the OCI API key |
| `VM_SSH_AUTHORIZED_KEYS_JSON` | JSON list of SSH public keys, e.g. `["ssh-ed25519 AAAA..."]` |
| `PORKBUN_API_KEY` | Porkbun API key (`pk1_...`) for `infra/live/dns` |
| `PORKBUN_SECRET_KEY` | Porkbun Secret API key (`sk1_...`) for `infra/live/dns` |
| `DEPLOY_SSH_PRIVATE_KEY` | SSH private key for Ansible deployments (`ubuntu` user) |
| `MAIL_SERVER_HOST` | Public IP or hostname of `Mail-Server` (`92.5.85.159`) |

## Adding a Second VM Later

1. Add a new key (e.g., `app = { ... }`) to `instances` in `infra/live/prod/topology.auto.tfvars` and any needed NSG rules in `nsgs`.
2. Optionally add a DNS record in `infra/live/dns/main.tf` referencing `data.terraform_remote_state.prod.outputs.instance_public_ips["app"]`.
3. Open a Pull Request to inspect the OpenTofu plan comment before merging to `main`.
4. Add the new host to `ansible/inventory/hosts.yml` and run `ansible-playbook playbooks/harden.yml -e target_hosts=app_hosts`.
