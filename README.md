# Homelab Infra

Git-managed infrastructure for my homelab.

This repo holds all Docker Compose stacks, configuration, and notes for the services running on my Unraid host (and eventually beyond). Portainer uses these files as the source of truth, and Renovate will keep image versions up to date via pull requests.

---

## Layout

```text
homelab-infra/
├── docs/                   # Human-facing notes and diagrams
│   ├── migration-notes.md
│   └── stacks.md
├── env/                    # Example env files (no real secrets)
├── renovate.json           # Renovate configuration for image updates
└── stacks/                 # All stacks organized by domain
    ├── ai/
    │   ├── faster-whisper/
    │   ├── ollama/
    │   ├── openwakeword/
    │   ├── piper/
    │   └── speaches/
    ├── apps/
    │   ├── audiobookshelf/
    │   ├── freshrss/
    │   ├── static-web/
    │   └── vaultwarden/
    ├── core/
    │   ├── authelia/
    │   ├── caddy/
    │   ├── keycloak/
    │   └── mosquitto/
    ├── home-assistant/
    │   ├── home-assistant/
    │   ├── mosquitto/
    │   └── mqtt-explorer/
    └── nextcloud/
        ├── nextcloud/
        ├── postgres/
        └── redis/
````

Conventions:

* Each leaf directory under `stacks` contains **one** `docker-compose.yml` describing that stack.
* Secrets are **never** committed. Compose files reference environment variables, which are provided via Portainer or local env files that are ignored by Git.
* `docs/` contains free-form notes; `stacks.md` summarizes what each stack does and which domains/ports it uses.

---

## How stacks are deployed

### Via Portainer

Each stack is deployed from this repo using Portainer’s “Git repository” mode.

High-level process for a new stack:

1. Create a directory, e.g.:

   ```text
   stacks/apps/example-service/
     docker-compose.yml
   ```

2. Commit and push the changes.

3. In Portainer:

   * **Stacks → Add stack → Repository**
   * Repository URL: this repo
   * Reference: branch name (e.g. `main`)
   * Compose path: e.g. `stacks/apps/example-service/docker-compose.yml`
   * Set any required environment variables for the stack (passwords, secrets, etc.).
   * Deploy the stack.

4. Portainer will pull the images, create the containers, and reuse existing volumes if they were previously created.

Updating a stack:

* Change the image tag(s) in `docker-compose.yml` (or let Renovate open a PR).
* Merge the change.
* In Portainer, either:

  * Trigger a Git pull / “Update stack from repository”, or
  * Let auto-update (if enabled) pick it up on its schedule.

---

## Image updates (Renovate)

`renovate.json` is configured to watch `stacks/**/docker-compose.yml` for Docker images and propose updates as pull requests.

Typical flow:

1. Renovate detects a new version of an image (e.g. `freshrss/freshrss:1.24.1`).
2. It opens a PR updating the relevant `docker-compose.yml`.
3. The PR is reviewed and merged.
4. Portainer pulls from Git and redeploys the stack using the new image.

This gives:

* Visibility into what’s changing (via PRs).
* Reproducible deployments (explicit tags instead of `latest`).
* A single place (Git) to see what versions are currently in use.

---

## Secrets and environment variables

Secrets are passed to stacks via environment variables, defined **outside** this repo.

Patterns:

* Compose files reference variables, for example:

  ```yaml
  environment:
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    KC_BOOTSTRAP_ADMIN_PASSWORD: ${KC_BOOTSTRAP_ADMIN_PASSWORD}
  ```

* In Portainer, each stack has those variables defined in the “Environment variables” section.

* `env/*.env.example` can be used as templates for what needs to be set, but they must not contain real secrets.

---

## Backups and restores

Some stacks (e.g. Keycloak) have dedicated backup/restore procedures documented in their own `README.md` under `stacks/**`. See:

* `stacks/core/keycloak/README.md` – Keycloak database backup/restore notes.
* `docs/migration-notes.md` – ad-hoc notes from service migrations.

Backups are generally performed via `docker exec` (e.g. `pg_dump`, `mysqldump`) into a backup directory on Unraid (`/mnt/user/backups/...`) and retained for a limited time. Restore procedures are written to be explicit, step-by-step, and reversible wherever possible.

