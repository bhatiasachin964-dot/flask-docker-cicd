# Flask App with Docker and a CI/CD Pipeline

A small Flask API, containerized with a multi-stage Docker build, served through Nginx with Docker Compose, and shipped to an AWS EC2 server automatically by **GitHub Actions** on every push to `main`.

<!-- TODO: add a screenshot of a green GitHub Actions run here -->
<!-- TODO: add a screenshot or curl output of the live /health endpoint here -->

## Pipeline

```
git push to main
      |
      v
  test job:   pytest  ->  docker build  ->  start container, curl /health
      |
      v
  build job:  push image to GitHub Container Registry (tags: latest + commit SHA)
      |
      v
  deploy job: SSH into EC2  ->  git pull  ->  docker compose pull && up -d
      |
      v
  verify:     curl http://<server>/health (retries until healthy)
```

Pull requests run only the test job. Nothing is deployed until code reaches `main`.

## Stack

| Layer | Tool |
|---|---|
| App | Python 3.12, Flask, gunicorn |
| Container | Docker, multi-stage build, non-root user, `HEALTHCHECK` |
| Reverse proxy | Nginx (Docker Compose) |
| CI/CD | GitHub Actions |
| Registry | GitHub Container Registry (ghcr.io) |
| Server | AWS EC2 |

## Endpoints

| Path | Returns |
|---|---|
| `/` | message, app version (the commit SHA when deployed) and container hostname |
| `/health` | `{"status": "ok", "uptime_seconds": ...}` |

## Run locally

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements-dev.txt
pytest -v                     # run the tests

docker compose up --build     # app behind Nginx on http://localhost
curl http://localhost/health
```

## Deploy setup (one time)

### 1. Prepare the EC2 instance

- Launch an instance (Amazon Linux or Ubuntu). In the security group, allow **SSH (22)** from your IP and **HTTP (80)** from anywhere.
- Install Docker and the Compose plugin (see the Docker documentation for your OS), and add your user to the `docker` group.
- Clone this repo into the home directory (the workflow expects `~/flask-docker-cicd`):
  ```bash
  git clone https://github.com/bhatiasachin964-dot/flask-docker-cicd.git ~/flask-docker-cicd
  ```
- Tell Compose which image to run, by creating `~/flask-docker-cicd/.env`:
  ```
  APP_IMAGE=ghcr.io/bhatiasachin964-dot/flask-docker-cicd:latest
  ```

### 2. Let the server pull the image

After the first pipeline run, the image appears under your GitHub profile's **Packages**. Either set the package visibility to **public**, or log in on the server once with a personal access token that has the `read:packages` scope:
```bash
echo <TOKEN> | docker login ghcr.io -u <github-username> --password-stdin
```

### 3. Add GitHub repository secrets

Under *Settings > Secrets and variables > Actions*:

| Secret | Value |
|---|---|
| `EC2_HOST` | Public IP or DNS name of the instance |
| `EC2_USER` | SSH user (for example `ec2-user` or `ubuntu`) |
| `EC2_SSH_KEY` | Private key contents. Use a dedicated deploy key, not your personal one. |

Push to `main` and watch the **Actions** tab.

## Design decisions

- **Multi-stage build:** dependencies install in a builder stage, so the final image carries no build tooling.
- **Non-root container user:** a compromised app process does not get root inside the container.
- **gunicorn, not the Flask dev server:** the dev server is not meant for production.
- **Image tagged with the commit SHA:** every deployment can be traced to the exact commit, and rolled back by pointing `APP_IMAGE` at an older tag.
- **Smoke test in CI:** the pipeline runs the built container and calls `/health`, so a broken image fails before it is pushed.
- **Post-deploy verification:** the deploy job fails if `/health` does not respond afterwards.
- **No secrets in the repo:** deploy credentials live in GitHub Secrets.

## Rollback

On the server, set `APP_IMAGE` in `.env` to a previous SHA tag, then:
```bash
docker compose pull && docker compose up -d
```

## Possible improvements

- [ ] HTTPS with Let's Encrypt (Certbot or Caddy)
- [ ] Use AWS SSM or OIDC instead of long-lived SSH keys
- [ ] Add a linter and an image vulnerability scan (for example Trivy) to the pipeline
- [ ] Blue/green or rolling deployment
- [ ] Provision the EC2 instance with Terraform

## Author

**Sachin Bhatia** · [LinkedIn](https://linkedin.com/in/sachin-bhatia-725a7a1a0) · [GitHub](https://github.com/bhatiasachin964-dot)
