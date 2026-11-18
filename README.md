# marcelwalder-infra

Monorepo managing OCI cloud infrastructure, Porkbun DNS, server configuration, and the static CV site at [`marcelwalder.eu`](https://marcelwalder.eu/).

## Repository Structure

```text
marcelwalder-infra/
├── .github/workflows/
│   ├── infra.yml           # OpenTofu fmt, validate, PR plan comment, and gated apply
│   └── deploy-site.yml     # Self-hosted/CSP hygiene guard + Ansible site deploy + smoke check
├── infra/
│   ├── modules/
│   │   ├── network/        # VCN, IGW, default route/security list, subnets, composable NSGs
│   │   ├── compute/        # Map-driven OCI VM instances + optional reserved public IPs
│   │   └── dns/            # Porkbun DNS record module
│   └── live/
│       ├── prod/           # Primary OCI stack (VCN, VM, buckets, backup policy, Email Delivery, alarms, ONS, budget, IAM)
│       └── dns/            # Porkbun DNS stack (consumes prod public IPs via remote state)
├── ansible/
│   ├── inventory/hosts.yml
│   ├── files/
│   │   ├── mailserver/     # Docker-Mailserver & SnappyMail compose manifests and mail configs
│   │   ├── nginx/          # Hardened Nginx main config, snippets, and site vhosts
│   │   └── web/            # BIMI SVG assets and MTA-STS policy
│   └── playbooks/
│       ├── site.yml        # Sync site/, BIMI/MTA-STS assets, Nginx vhosts, and reload Nginx
│       └── harden.yml      # Host hardening, mail/monitoring stacks, backups, firewall, and WireGuard
└── site/                   # Self-hosted static CV bundle (zero external font/avatar requests)
```

## Architecture Highlights

- **OpenTofu + OCI Object Storage Backend:** State is stored in the private, versioned OCI Object Storage bucket `tfstate-marcelwalder-prod` (`eu-frankfurt-1`, also tracked with `prevent_destroy = true`) using S3 compatibility and **client-side AES-GCM encryption** (`encryption.tf`).
- **Complete OCI Operational Guardrails:** `infra/live/prod` manages the `backups-marcelwalder-prod` and `tfstate-marcelwalder-prod` buckets, `Always-Free-Mail-Backup-Policy` boot volume schedule, OCI Email Delivery (`marcelwalder.eu` domain, `dkim1`, approved senders), `Free-Tier-Quota-Alerts` ONS topic/subscription, backup completion event rule, Always Free down/idle-reclaim monitoring alarms, `Zero-Spend-Guard` budget/alert rules, and `Tenant Admin Policy`.
- **Extensible Multi-VM Compute:** `infra/live/prod/topology.auto.tfvars` defines `instances` as a map. Adding another Always Free ARM or micro VM only requires adding a map entry (plus an NSG in `nsgs` if custom ports are needed).
- **Automated DNS Sync:** `infra/live/dns` reads `instance_public_ips` directly from `prod/terraform.tfstate` via `terraform_remote_state` and includes `imports.tf` for existing `marcelwalder.eu` records (`ha.marcelwalder.eu` is intentionally managed by a separate Home Assistant repository).
- **GDPR & CSP Guardrails:** `.github/workflows/deploy-site.yml` fails if external Google Fonts / GitHub avatar URLs or inline `<script>` blocks appear in `site/`, then deploys via Ansible and smoke-tests live HTTPS headers.

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
