# CyberBlueSOC — Default Credentials

> **These are lab defaults.** CyberBlueSOC is a learning / demo platform and
> ships with fixed, published credentials so students can log in on first
> boot. **Change them before pointing this at any real data, before exposing
> the box to the internet, and before using it for anything that isn't a
> deliberate test run.**
>
> Every tool below has a "Rotate it" column telling you exactly how.

## Quickest route to the same information

You don't need to read this file to look up a credential while you're
working:

| Where | Shows |
|---|---|
| Welcome dashboard → click **Creds** on any tool card | Username + password + "Open" button |
| Welcome dashboard → **Credentials** link in the header | This full table in the browser |
| `cyberblue creds` in a terminal | This full table, ANSI-coloured |
| `cyberblue urls` in a terminal | URL + credentials, all tools on one line |

Firefox on this box also has every credential pre-saved in its password
manager, so login forms auto-fill the moment you open the page — you
should only need to look them up when scripting against the APIs.

## Web UIs with hardcoded defaults

| Tool | URL | Username | Password | Rotate it |
|---|---|---|---|---|
| Wazuh            | `https://<ip>:7001` | `admin`               | `SecretPassword` | *Wazuh dashboard* → **Security → Users** → edit `admin` → *Reset password*. Then update the password in `wazuh.yml` / `opensearch_dashboards.yml` and restart. |
| Velociraptor     | `https://<ip>:7000` | `admin`               | `cyberblue`      | `docker compose exec velociraptor velociraptor --config server.config.yaml user add admin --role administrator` (prompts for new password). |
| MISP             | `https://<ip>:7003` | `admin@admin.test`    | `admin`          | Top-right avatar → **My Profile → Edit Password**. Also update the API user in `MISP/app/Config/config.php`. |
| TheHive          | `http://<ip>:7005`  | `admin@thehive.local` | `secret`         | Top-right avatar → **Settings → Change password**. Consider also creating a new super-admin and deleting the default. |
| Cortex           | `http://<ip>:7006`  | `admin`               | `admin`          | Top-right avatar → **My Account → Change Password**. |
| Arkime           | `http://<ip>:7008`  | `admin`               | `admin`          | `docker compose exec arkime /opt/arkime/bin/arkime_add_user.sh admin 'Admin' <new-pw> --admin`. |
| Caldera          | `http://<ip>:7009`  | `admin`               | `admin`          | Edit `caldera/conf/default.yml` → `users.red.admin`, then `docker compose restart caldera`. |
| FleetDM          | `http://<ip>:7007`  | `admin`               | `admin123`       | **Settings → Users** → edit admin user. Or `fleetctl user change_password --email admin`. |
| Grafana          | `http://<ip>:3000`  | `admin`               | `cyberblue`      | `docker compose exec grafana grafana-cli admin reset-admin-password '<new-pw>'`. |

`<ip>` is whatever `cyberblue urls` prints as the host — usually the
VM's primary IPv4.

## Web UIs that set the password on first visit

These tools don't ship a default. They'll ask you to create an admin
account the first time you open them. Don't lose these — there is no
password reset for most.

| Tool | URL | Notes |
|---|---|---|
| Portainer  | `https://<ip>:9443`           | Set admin on first load. 5-minute timeout — if you wait too long you have to `docker compose restart portainer`. |
| Shuffle    | `http://<ip>:3001`            | First user created is the org admin. |
| CyberBlue Portal | `https://<ip>:5443`     | No auth on the portal itself — it's a dashboard for `cyberblue` state. Front it with a reverse proxy + auth before exposing externally. |

## Web UIs with no authentication

Intended for lab use with no login. Don't expose these to an untrusted
network.

- **MITRE Navigator** — `http://<ip>:7013`
- **CyberChef** — `http://<ip>:7004`
- **EveBox** — `http://<ip>:7015`
- **CrowdSec LAPI metrics** — `http://<ip>:6060/metrics`

## Infrastructure credentials (containers / databases)

You only need these when you're poking at backing stores directly.
Don't change them without also updating the app that depends on them.

| Service | Where | User | Password | Rotate it |
|---|---|---|---|---|
| Wazuh Indexer (OpenSearch) | `https://wazuh-indexer:9200` inside the compose network | `admin` | `SecretPassword` | `docker compose exec wazuh-indexer opensearch-plugin-cli ...` — see the Wazuh docs; this is a multi-file change. |
| Cassandra (TheHive / Cortex backing) | `cassandra:9042` | `cassandra` | `cassandra` | Change via `cqlsh` and update the `cassandra-auth` section of `application.conf`. |
| Elasticsearch (TheHive) | `elasticsearch:9200` | — (no auth by default) | — | Enable X-Pack security in `elasticsearch.yml` + update TheHive's `application.conf`. |
| Redis (Shuffle / Falcosidekick UI) | `redis:6379` | — (no auth by default) | — | Set `requirepass` in `redis.conf` + update consumer env. |

## SSH into the VM

These are the OS-level credentials for the AWS lab box / ISO install.
They are **not** part of the stack itself; they're whatever the
installer or cloud-init set up.

- AWS lab box: SSH key auth only (`ubuntu@<public-ip>` with the key you
  launched the instance with). No password.
- ISO install: whatever username + password you chose during Ubuntu's
  installer. The stack never adds a second admin.

## Rotation checklist (when handing a VM off to a student / colleague)

Run these in order:

```bash
# 1. Show what's set right now
cyberblue creds

# 2. Rotate each web UI admin using the table above (Wazuh, TheHive, ...)
#    Record the new values somewhere they can find them.

# 3. Re-seed Firefox's password manager so autofill still works
sudo bash /home/ubuntu/CyberBlue/tools/native/desktop/install-desktop.sh
#    (the seeder is idempotent; it reads tools/native/desktop/firefox-logins.json
#     so edit that file FIRST if you want the new creds in autofill)

# 4. Rotate the OS password for the interactive user
sudo passwd ubuntu
```

## If you just want to disable a default login entirely

Every tool's admin account is recoverable with shell access to its
container. Deleting the default user and creating a fresh one is always
safe:

```bash
# Example: Wazuh
docker compose exec wazuh-dashboard \
  /usr/share/wazuh-dashboard/bin/wazuh-dashboard-users passwd admin
```

## Why we publish the defaults at all

The alternative — generating random credentials on first boot and
storing them in `/root/cred.txt` — is what most commercial appliances
do, but it hurts the *teaching* use case CyberBlueSOC is built for.
Students working from the public docs need to be able to replicate what
they see. We make the defaults loud and give you one-command rotations
so the guardrails are there when you need them.
