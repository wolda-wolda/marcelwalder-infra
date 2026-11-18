# Disaster Recovery & Credential Rotation Runbook

This runbook covers routine encrypted backup verification, cold-start VM recovery using OpenTofu + Restic + Ansible, and rotating GitHub Actions OCI credentials to the least-privilege `opentofu-ci` IAM user.

---

## 1. Backup Architecture (100% OCI Always Free Tier)

| Layer | Schedule / Trigger | Destination / Scope | Alerting / Dead-Man's Switch |
| --- | --- | --- | --- |
| **Offsite Restic S3 Backup** | Daily `03:15 UTC` (`marcelwalder-restic-backup.timer`) | Private OCI bucket `backups-marcelwalder-prod` (`eu-frankfurt-1`), AES-256 encrypted | Failure triggers `OnFailure=marcelwalder-alert@%n.service`; success pings Uptime Kuma Push monitor (`restic-heartbeat.url`) |
| **Restic Repository Scrub** | Weekly Sunday `04:15 UTC` (`marcelwalder-restic-check.timer`) | `restic check --read-data-subset=5%` integrity verification | Failure triggers `OnFailure=marcelwalder-alert@%n.service` |
| **OCI Boot Volume Backup** | Scheduled Always Free backup policy (`Always-Free-Mail-Backup-Policy`) | OCI block storage snapshots + event rule `Mail-Backup-Completion-Alert` | Failure/completion alerts via ONS `Free-Tier-Quota-Alerts` |
| **Static Configs & Manifests** | GitOps (`main` branch) | Compose files, Nginx configs, firewall rules, Ansible roles, CV site in GitHub | Verified by `verify-compliance` + `validate-prod` / `validate-dns` CI gates |

Directories restored by `ansible/playbooks/restore.yml`:
- `/etc/letsencrypt` (TLS certificates & renewal configs)
- `/opt/mailserver` (`mail-data/`, `config/postfix-accounts.cf`, DKIM keys, compose files)
- `/opt/snappymail` (`volume/` webmail state)
- `/opt/uptime-kuma/data` (`kuma.db` monitors, push tokens, notification config)
- `/etc/wireguard` (`server.key`, `wg0.conf`)
- `/etc/marcelwalder` (`restic.env`, alert/push config)

---

## 2. Routine Verification & Restore Drill

Automated verification runs weekly via `marcelwalder-restic-check.timer`. To inspect snapshots or perform a manual non-destructive restore drill on the host:

```bash
set -a
source /etc/marcelwalder/restic.env
set +a

# List recent snapshots
sudo -E restic snapshots

# Run repository structure + 5% pack read check
sudo -E restic check --read-data-subset=5%

# Non-destructive restore drill into /tmp/restore-drill
sudo rm -rf /tmp/restore-drill
sudo -E restic restore latest --target /tmp/restore-drill --include /opt/mailserver/config --include /etc/letsencrypt
sudo ls -la /tmp/restore-drill/opt/mailserver/config /tmp/restore-drill/etc/letsencrypt
sudo rm -rf /tmp/restore-drill
```

Verify the dead-man's-switch heartbeat URL is configured in `/etc/marcelwalder/restic-heartbeat.url` (`0600`, `root:root`) pointing at your Uptime Kuma `Restic Offsite Backup` Push monitor (expected every 24h, grace period ~26h).

---

## 3. Cold-Start VM Rebuild Procedure (Full Instance Loss)

Use this procedure if `Mail-Server` or its boot volume is lost and you need to rebuild from scratch onto a fresh Ubuntu 24.04 ARM64 OCI instance.

### Phase A: Provision Infrastructure & DNS
1. **Run `Infrastructure (OpenTofu)` (`infra/live/prod`)** against `main` (via `workflow_dispatch` or merged PR).
   - If the reserved public IP (`module.compute.oci_core_public_ip.reserved["mail"]`) survived, it automatically re-attaches (`92.5.85.159`).
   - If a brand-new public IP was provisioned, update `MAIL_SERVER_HOST` in GitHub Secrets and let `DNS (OpenTofu)` (`infra/live/dns`) apply the updated A record from remote state.
2. **Pin the new VM's SSH Ed25519 host key** (if the VM was recreated with new SSH host keys):
   - Fetch the new key from the OCI Console or WireGuard/verified first connection (`ssh-keyscan -t ed25519 <NEW_IP>`), verify the fingerprint against OCI Console Serial Connection, and commit the updated entry in `ansible/files/ssh/known_hosts`.

### Phase B: Restore Stateful Data from Restic
Run `restore.yml` before `harden.yml` so mail accounts, mail spools, DKIM keys, TLS certificates, WireGuard server keys, and `kuma.db` are present on disk first:

```bash
cd ansible
export OCI_S3_ACCESS_KEY_ID="..."
export OCI_S3_SECRET_ACCESS_KEY="..."
export RESTIC_PASSWORD="..."
ansible-playbook playbooks/restore.yml -e target_hosts=web_hosts --private-key ~/.ssh/id_deploy
```

### Phase C: Harden Host, Start Containers, & Deploy Web Stack
1. **Run `harden.yml`** to install packages, configure native `nftables`, Fail2ban, WireGuard, Docker Mailserver, SnappyMail, Uptime Kuma, systemd timers, and Restic timers:
   ```bash
   export WG_CLIENT_PUBLIC_KEY="..."
   ansible-playbook playbooks/harden.yml -e target_hosts=web_hosts --private-key ~/.ssh/id_deploy
   ```
2. **Run `site.yml`** to configure Nginx vhosts (including automatic Certbot webroot issuance if any certificate is missing), sync `marcelwalder.eu`, BIMI SVGs, and MTA-STS policy:
   ```bash
   ansible-playbook playbooks/site.yml --private-key ~/.ssh/id_deploy
   ```
   *(Or trigger the **Deploy Static CV Site** GitHub Actions workflow via `workflow_dispatch`.)*

### Phase D: Post-Recovery Verification
```bash
sudo nft list tables
sudo systemctl is-active nftables fail2ban nginx wg-quick@wg0 marcelwalder-healthcheck.timer marcelwalder-restic-backup.timer marcelwalder-restic-check.timer
sudo docker ps --format "table {{.Names}}\t{{.Status}}"
sudo /usr/local/sbin/marcelwalder-healthcheck
```

---

## 4. Rotating GitHub Actions Secrets to Least-Privilege `opentofu-ci` IAM User

`infra/live/prod/main.tf` provisions a dedicated `opentofu-ci` IAM user, `opentofu-ci` group, and `OpenTofu-CI-Least-Privilege` policy (`Default` Identity Domain) so CI does not need Tenancy Administrator credentials.

To switch GitHub Actions from the legacy admin user:
1. Obtain the new user OCID from OpenTofu outputs:
   ```bash
   tofu -chdir=infra/live/prod output -raw opentofu_ci_user_ocid
   ```
2. In **OCI Console → Identity & Security → Domains → Default → Users → `opentofu-ci`**:
   - Upload/generate an **API Key** and note its **Fingerprint** and private PEM file.
   - Generate a **Customer Secret Key** (S3-compatible) and note its Access Key ID + Secret Access Key (maximum 2 Customer Secret Keys per user).
3. Update these **GitHub Repository Secrets**:
   - `OCI_USER_OCID` → `opentofu_ci_user_ocid`
   - `OCI_FINGERPRINT` → new API Key fingerprint
   - `OCI_PRIVATE_KEY_PEM` → new private PEM
   - `OCI_S3_ACCESS_KEY_ID` → new Customer Secret Key ID
   - `OCI_S3_SECRET_ACCESS_KEY` → new Customer Secret Key secret
4. Run a `workflow_dispatch` on **Infrastructure (OpenTofu)** (`infra.yml`) and verify `plan` / `apply` succeed before revoking the old admin user's API key / Customer Secret Key.
