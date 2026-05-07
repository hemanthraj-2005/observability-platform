# DevOps Observability Platform - Project Feature Summary

## 1. Project Overview

This project is a production-style observability platform for a containerized Flask application. It demonstrates application monitoring, infrastructure monitoring, centralized log aggregation, dashboard visualization, alerting, automated validation, and cloud deployment automation.

The platform combines:

- Flask for a sample instrumented application.
- Prometheus for metrics scraping and PromQL querying.
- Node Exporter for host/system metrics.
- Loki for centralized log storage.
- Promtail for Docker log collection.
- Grafana for dashboards, logs, datasources, and alert rules.
- Docker Compose for local and production orchestration.
- Terraform for AWS EC2 infrastructure provisioning.
- GitHub Actions for CI, Terraform execution, and deployment.

## 2. Architecture Summary

The local architecture runs all observability services as Docker containers.

```text
Flask App
  |-- /metrics ------------------> Prometheus ----\
  |-- Docker container logs -----> Promtail ------> Loki ----\
                                                              > Grafana
Node Exporter -------------------> Prometheus ---------------/
```

Prometheus scrapes application and infrastructure metrics. Promtail reads Docker JSON logs from the host and pushes them to Loki. Grafana connects to both Prometheus and Loki, then displays metrics, logs, and alerts from pre-provisioned configuration files.

The cloud deployment architecture adds CI/CD and infrastructure automation:

```text
GitHub Actions CI
  |-- tests, syntax checks, JSON validation, Compose validation, Docker build

GitHub Actions Terraform
  |-- provisions AWS security group and EC2 host

GitHub Actions CD
  |-- syncs repo to EC2
  |-- writes production .env from GitHub Secrets
  |-- runs Docker Compose on EC2
```

## 3. Repository Structure

| Path | Purpose |
| --- | --- |
| `README.md` | Main usage guide, architecture notes, run instructions, CI/CD details, and query examples. |
| `app/app.py` | Flask sample application with endpoints, logging, and Prometheus metrics. |
| `app/test_app.py` | Pytest endpoint and metrics tests for the Flask app. |
| `app/Dockerfile` | Container image definition for the Flask app. |
| `app/requirements.txt` | Runtime Python dependencies. |
| `app/requirements-dev.txt` | Development/test Python dependencies. |
| `docker-compose.yml` | Local multi-service stack definition. |
| `docker-compose.prod.yml` | Production Compose override with persistent volumes and secret-driven Grafana credentials. |
| `.env.example` | Example production environment variables. |
| `monitoring/prometheus/prometheus.yml` | Prometheus scrape configuration. |
| `logging/loki/loki-config.yml` | Loki filesystem-backed local storage configuration. |
| `logging/promtail/promtail-config.yml` | Promtail Docker log scraping configuration. |
| `grafana/provisioning/datasources/datasources.yml` | Automatically provisions Prometheus and Loki datasources. |
| `grafana/provisioning/dashboards/dashboards.yml` | Automatically provisions dashboards from JSON files. |
| `grafana/provisioning/alerting/alerts.yml` | Automatically provisions Grafana alert rules. |
| `grafana/dashboards/devops-observability.json` | Main Grafana dashboard definition. |
| `infra/terraform/*.tf` | AWS infrastructure as code for EC2, networking, and outputs. |
| `infra/scripts/bootstrap-ec2.sh` | EC2 user-data bootstrap script for Docker and firewall setup. |
| `infra/scripts/deploy.sh` | Server-side deployment script for production Compose. |
| `.github/workflows/ci.yml` | Continuous integration workflow. |
| `.github/workflows/terraform.yml` | Manual Terraform plan/apply workflow. |
| `.github/workflows/cd.yml` | Continuous deployment workflow to EC2. |

## 4. Feature: Instrumented Flask Application

The Flask app is the sample workload being observed. It exposes normal traffic, health checks, simulated failures, and Prometheus metrics.

Source files:

- `app/app.py`
- `app/Dockerfile`
- `app/requirements.txt`
- `app/requirements-dev.txt`
- `app/test_app.py`

Application endpoints:

| Endpoint | Method | Behavior |
| --- | --- | --- |
| `/` | GET | Returns `Application running` and emits an info log. |
| `/health` | GET | Returns `OK` with HTTP 200 for health checking. |
| `/error` | GET | Emits an error log, increments the simulated error counter, and returns HTTP 500. |
| `/metrics` | GET | Exposes Prometheus metrics in text format. |

Application metrics:

| Metric | Type | Labels | Purpose |
| --- | --- | --- | --- |
| `flask_http_requests_total` | Counter | `method`, `endpoint`, `http_status` | Counts handled HTTP requests, excluding `/metrics`. |
| `flask_http_request_duration_seconds` | Histogram | `method`, `endpoint` | Records request latency, excluding `/metrics`. |
| `flask_http_errors_total` | Counter | `endpoint` | Counts simulated application errors from `/error`. |

Important behavior:

- A `before_request` hook records request start time.
- An `after_request` hook records request count and latency for all routes except `/metrics`.
- `/error` exists specifically to generate observable failures for metrics, logs, dashboards, and alerts.
- The app runs on port `5000` inside the container and is published as `localhost:5001` by Docker Compose.

## 5. Feature: Docker Compose Local Stack

The main Compose file starts the full observability platform locally.

Source file:

- `docker-compose.yml`

Services:

| Service | Container | Port Mapping | Purpose |
| --- | --- | --- | --- |
| `flask-app` | `flask-app` | `5001:5000` | Sample application with metrics and logs. |
| `prometheus` | `prometheus` | `9090:9090` | Metrics scraping and PromQL querying. |
| `grafana` | `grafana` | `3005:3000` | Dashboards, logs, datasources, and alerts. |
| `node-exporter` | `node-exporter` | `9100:9100` | Host/system metrics exporter. |
| `loki` | `loki` | `3100:3100` | Log storage and LogQL API. |
| `promtail` | `promtail` | Internal | Docker log collector that pushes to Loki. |

Local URLs:

| Component | URL |
| --- | --- |
| Flask app | `http://localhost:5001` |
| Prometheus | `http://localhost:9090` |
| Grafana | `http://localhost:3005` |
| Node Exporter | `http://localhost:9100` |
| Loki | `http://localhost:3100` |

Default local Grafana credentials:

| Field | Value |
| --- | --- |
| Username | `admin` |
| Password | `admin` |

## 6. Feature: Production Compose Override

The production Compose override adds persistence and secret-driven Grafana credentials.

Source file:

- `docker-compose.prod.yml`

Production changes:

- Grafana admin username comes from `GRAFANA_ADMIN_USER`, defaulting to `admin`.
- Grafana admin password comes from `GRAFANA_ADMIN_PASSWORD`.
- Grafana data persists in the `grafana-data` Docker volume.
- Prometheus data persists in the `prometheus-data` Docker volume.
- Loki data persists in the `loki-data` Docker volume.

The file is intended to be used together with the base Compose file:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

## 7. Feature: Prometheus Metrics Collection

Prometheus is configured to scrape itself, host metrics, and the Flask app.

Source file:

- `monitoring/prometheus/prometheus.yml`

Global configuration:

- Scrape interval: `15s`

Scrape jobs:

| Job | Target | Purpose |
| --- | --- | --- |
| `prometheus` | `prometheus:9090` | Collect Prometheus server metrics. |
| `node-exporter` | `node-exporter:9100` | Collect host and system metrics. |
| `flask-app` | `flask-app:5000/metrics` | Collect custom Flask application metrics. |

Useful PromQL queries included in the project:

| Use Case | Query |
| --- | --- |
| Request rate by endpoint | `sum by (endpoint) (rate(flask_http_requests_total[1m]))` |
| Application errors in 5 minutes | `sum(increase(flask_http_errors_total[5m]))` |
| P95 request latency | `histogram_quantile(0.95, sum(rate(flask_http_request_duration_seconds_bucket[5m])) by (le))` |
| CPU usage | `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |
| Memory usage | `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100` |

## 8. Feature: Host Monitoring With Node Exporter

Node Exporter provides machine-level metrics to Prometheus.

Source file:

- `docker-compose.yml`

Observed areas include:

- CPU time and utilization.
- Memory availability and usage.
- Other default Node Exporter host metrics exposed on port `9100`.

The Grafana dashboard uses Node Exporter metrics for:

- CPU Usage %
- Memory Usage %

## 9. Feature: Centralized Logging With Loki and Promtail

The logging stack stores and queries Docker container logs centrally.

Source files:

- `logging/loki/loki-config.yml`
- `logging/promtail/promtail-config.yml`
- `docker-compose.yml`

Loki configuration:

- Authentication disabled for local/internal use.
- HTTP listener on port `3100`.
- Filesystem storage under `/loki`.
- TSDB schema version `v13`.
- Single-node in-memory ring with replication factor `1`.

Promtail configuration:

- HTTP listener on port `9080`.
- Positions file at `/tmp/positions.yaml`.
- Pushes logs to `http://loki:3100/loki/api/v1/push`.
- Reads Docker JSON log files from `/var/lib/docker/containers/*/*-json.log`.
- Applies the label `job=docker`.

Useful LogQL queries included in the project:

| Use Case | Query |
| --- | --- |
| All Docker logs | `{job="docker"}` |
| Error logs | `{job="docker"} |= "error"` |
| Flask activity | `{job="docker"} |= "flask-app"` |

Important note:

- The Docker log path works naturally on Linux Docker hosts. On Docker Desktop for macOS, direct access to `/var/lib/docker/containers` can vary by runtime configuration.

## 10. Feature: Grafana Datasource Provisioning

Grafana datasources are provisioned automatically when the Grafana container starts.

Source file:

- `grafana/provisioning/datasources/datasources.yml`

Provisioned datasources:

| Datasource | UID | Type | URL | Default |
| --- | --- | --- | --- | --- |
| Prometheus | `Prometheus` | `prometheus` | `http://prometheus:9090` | Yes |
| Loki | `Loki` | `loki` | `http://loki:3100` | No |

This removes manual setup after starting the stack. Grafana can immediately query metrics from Prometheus and logs from Loki.

## 11. Feature: Grafana Dashboard Provisioning

Grafana dashboards are loaded from JSON automatically.

Source files:

- `grafana/provisioning/dashboards/dashboards.yml`
- `grafana/dashboards/devops-observability.json`

Dashboard provider:

| Field | Value |
| --- | --- |
| Provider name | `Observability Platform` |
| Folder | `DevOps Observability` |
| Dashboard path | `/var/lib/grafana/dashboards` |
| Editable | `true` |

Main dashboard:

| Field | Value |
| --- | --- |
| Title | `DevOps Observability Platform` |
| Tags | `devops`, `observability`, `docker` |

Dashboard panels:

| Panel | Type | Datasource/Query Purpose |
| --- | --- | --- |
| User Requests | Timeseries | Shows request rate by Flask endpoint. |
| Application Errors - Last 5m | Stat | Shows recent simulated Flask error count. |
| P95 Request Latency | Gauge | Shows 95th percentile request latency. |
| CPU Usage % | Timeseries | Shows host CPU usage from Node Exporter. |
| Memory Usage % | Timeseries | Shows host memory usage from Node Exporter. |
| Recent Error Logs | Logs | Shows Loki log lines containing `error`. |

## 12. Feature: Grafana Alerting

Grafana alert rules are provisioned automatically.

Source file:

- `grafana/provisioning/alerting/alerts.yml`

Alert groups:

| Group | Folder | Evaluation Interval |
| --- | --- | --- |
| Flask Application Alerts | DevOps Observability | `1m` |
| Infrastructure Alerts | DevOps Observability | `1m` |

Alert rules:

| Alert | Trigger Query | Threshold | Duration | Severity |
| --- | --- | --- | --- | --- |
| Flask High Error Count | `round(sum(increase(flask_http_errors_total[5m])))` | Greater than `5` | `1m` | `warning` |
| Node High CPU Usage | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | Greater than `80` | `2m` | `warning` |

Alert behavior:

- No-data state is `OK`.
- Execution error state is `Error`.
- Alert annotations explain what happened and where to investigate.

## 13. Feature: Automated Tests

The project includes focused pytest coverage for the Flask app.

Source file:

- `app/test_app.py`

Test coverage:

| Test | Validates |
| --- | --- |
| `test_home_endpoint_returns_application_status` | `/` returns HTTP 200 and `Application running`. |
| `test_health_endpoint_returns_ok` | `/health` returns HTTP 200 and `OK`. |
| `test_error_endpoint_returns_500` | `/error` returns HTTP 500 and `Error generated`. |
| `test_metrics_endpoint_exposes_custom_metrics` | `/metrics` exposes the custom Prometheus metric names. |

These tests validate the application behavior that feeds the observability platform.

## 14. Feature: Continuous Integration

The CI workflow validates the project on pushes and pull requests to `main`.

Source file:

- `.github/workflows/ci.yml`

CI steps:

| Step | Purpose |
| --- | --- |
| Checkout repository | Retrieves project code. |
| Set up Python 3.11 | Creates a consistent Python runtime. |
| Install Python dependencies | Installs Flask, Prometheus client, and pytest dependencies. |
| Run Flask tests | Runs `pytest -q` inside `app`. |
| Validate Python syntax | Compiles `app/app.py` and `app/test_app.py`. |
| Validate Grafana dashboard JSON | Parses dashboard JSON using `python -m json.tool`. |
| Validate Docker Compose config | Runs `docker compose config`. |
| Validate production Compose config | Runs Compose validation with production override and a test Grafana password. |
| Build Flask Docker image | Builds the app image from `./app`. |

This workflow catches application, configuration, dashboard, Compose, and Docker image issues before deployment.

## 15. Feature: AWS Infrastructure With Terraform

Terraform provisions the EC2 host and security controls needed to run the stack in AWS.

Source files:

- `infra/terraform/main.tf`
- `infra/terraform/variables.tf`
- `infra/terraform/outputs.tf`
- `infra/terraform/versions.tf`
- `infra/terraform/terraform.tfvars.example`

Terraform provider and versioning:

| Setting | Value |
| --- | --- |
| Terraform version | `>= 1.6.0` |
| AWS provider | `hashicorp/aws`, version `~> 5.0` |
| Default region | `ap-south-1` |

Provisioned AWS resources:

| Resource | Purpose |
| --- | --- |
| Default or specified VPC lookup | Selects the VPC for the EC2 host. |
| Default or specified subnet lookup | Selects the subnet for the EC2 host. |
| Ubuntu 22.04 AMI lookup | Uses the latest official Canonical Jammy image. |
| Security group | Allows SSH, Flask, Grafana, and Prometheus access from configured CIDRs. |
| EC2 instance | Runs the Docker Compose observability stack. |
| Encrypted gp3 root volume | Provides encrypted disk storage. |
| Instance metadata options | Requires IMDSv2 tokens. |

Security group ingress:

| Port | Purpose | CIDR Variable |
| --- | --- | --- |
| `22` | SSH | `allowed_ssh_cidr` |
| `5001` | Flask app | `allowed_app_cidr` |
| `3005` | Grafana | `allowed_app_cidr` |
| `9090` | Prometheus | `allowed_app_cidr` |

Important variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `aws_region` | `ap-south-1` | AWS region. |
| `project_name` | `observability-platform` | Resource naming and tags. |
| `environment` | `dev` | Environment naming and tags. |
| `instance_type` | `t3.small` | EC2 size. |
| `key_name` | Required | Existing EC2 key pair. |
| `allowed_ssh_cidr` | Required | SSH allowlist. |
| `allowed_app_cidr` | `0.0.0.0/0` | App/observability allowlist. |
| `root_volume_size` | `30` | Root EBS volume size in GiB. |

Terraform outputs:

| Output | Purpose |
| --- | --- |
| `instance_id` | EC2 instance identifier. |
| `public_ip` | EC2 public IP address. |
| `ssh_command` | Example SSH command. |
| `grafana_url` | Public Grafana URL. |
| `prometheus_url` | Public Prometheus URL. |
| `flask_app_url` | Public Flask app URL. |

## 16. Feature: EC2 Bootstrap Automation

The EC2 bootstrap script prepares a new Ubuntu host to run the platform.

Source file:

- `infra/scripts/bootstrap-ec2.sh`

Bootstrap actions:

| Action | Purpose |
| --- | --- |
| Install base packages | Installs certificates, curl, git, and UFW. |
| Add Docker apt repository | Configures Docker's official Ubuntu package source. |
| Install Docker components | Installs Docker Engine, CLI, containerd, Buildx, and Compose plugin. |
| Enable Docker service | Starts Docker on boot. |
| Add `ubuntu` to Docker group | Allows the Ubuntu user to run Docker commands. |
| Create `/opt/observability-platform` | Prepares the deployment directory. |
| Configure UFW | Allows SSH, Flask, Grafana, and Prometheus ports, then enables the firewall. |

## 17. Feature: Server-Side Deployment Script

The deployment script runs on the EC2 host to start or update the production stack.

Source file:

- `infra/scripts/deploy.sh`

Deployment behavior:

| Step | Purpose |
| --- | --- |
| Set `APP_DIR` | Defaults to `/opt/observability-platform`. |
| Use base and prod Compose files | Combines `docker-compose.yml` and `docker-compose.prod.yml`. |
| Ensure `.env` exists | Copies `.env.example` if `.env` is missing. |
| Pull images | Updates external service images. |
| Build and start containers | Runs `docker compose up -d --build --remove-orphans`. |
| Prune unused images | Frees disk space after deployment. |
| Show container status | Runs `docker compose ps`. |

## 18. Feature: Terraform GitHub Actions Workflow

The Terraform workflow allows manual infrastructure planning or applying from GitHub Actions.

Source file:

- `.github/workflows/terraform.yml`

Workflow behavior:

- Triggered manually through `workflow_dispatch`.
- Accepts an `action` input with `plan` or `apply`.
- Configures AWS credentials from repository secrets.
- Uses `AWS_REGION` GitHub variable when present, otherwise defaults to `ap-south-1`.
- Runs `terraform init`.
- Runs `terraform validate`.
- Runs `terraform plan` with secrets for EC2 key pair and CIDR allowlists.
- Runs `terraform apply -auto-approve tfplan` only when the selected action is `apply`.

Required secrets:

| Secret | Purpose |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | AWS access key for Terraform. |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for Terraform. |
| `EC2_KEY_NAME` | Existing EC2 key pair name. |
| `ALLOWED_SSH_CIDR` | CIDR allowed to SSH. |
| `ALLOWED_APP_CIDR` | CIDR allowed to access Flask, Grafana, and Prometheus. |

## 19. Feature: Continuous Deployment to EC2

The CD workflow deploys the application and observability stack to the provisioned EC2 host.

Source file:

- `.github/workflows/cd.yml`

Triggers:

- Manual `workflow_dispatch`.
- Push to `main`.

Deployment steps:

| Step | Purpose |
| --- | --- |
| Checkout repository | Retrieves project files. |
| Set up SSH key | Writes private key and populates known hosts. |
| Sync files to EC2 | Uses `rsync` to copy the project to `/opt/observability-platform`. |
| Write production `.env` | Creates `.env` from Grafana secrets and copies it to EC2. |
| Deploy stack | Runs `infra/scripts/deploy.sh` on the EC2 host. |

Files excluded from deployment sync:

- `.git`
- `.github`
- `.venv`
- `__pycache__`

Required secrets:

| Secret | Purpose |
| --- | --- |
| `EC2_HOST` | EC2 public IP or DNS name. |
| `EC2_USER` | SSH user, usually `ubuntu`. |
| `EC2_SSH_PRIVATE_KEY` | Private SSH key for the EC2 key pair. |
| `GRAFANA_ADMIN_USER` | Production Grafana admin username. |
| `GRAFANA_ADMIN_PASSWORD` | Production Grafana admin password. |

## 20. Feature: Environment Configuration

The project includes a minimal environment template for production Grafana credentials.

Source file:

- `.env.example`

Variables:

| Variable | Example | Purpose |
| --- | --- | --- |
| `GRAFANA_ADMIN_USER` | `admin` | Grafana login username. |
| `GRAFANA_ADMIN_PASSWORD` | `change-me-before-deploying` | Grafana login password. |

In production, the CD workflow writes these values from GitHub Secrets into `/opt/observability-platform/.env` on the EC2 host and sets file permissions to `600`.

## 21. Feature: Local Developer Workflow

Start the full platform locally:

```bash
docker compose up --build
```

Generate normal traffic:

```bash
curl http://localhost:5001/
curl http://localhost:5001/health
```

Generate an observable error:

```bash
curl http://localhost:5001/error
```

Open the dashboard:

```text
http://localhost:3005
```

Navigate in Grafana to:

```text
Dashboards > DevOps Observability > DevOps Observability Platform
```

Run core local checks:

```bash
pip install -r app/requirements-dev.txt
cd app
pytest -q
cd ..
docker compose config
GRAFANA_ADMIN_PASSWORD=ci-test-password docker compose -f docker-compose.yml -f docker-compose.prod.yml config
docker build -t observability-platform-flask-app:ci ./app
```

## 22. Feature: Operational Observability Scenarios

The project supports several practical observability demonstrations.

Request monitoring:

- Visit `/` or `/health`.
- Prometheus records request count and latency.
- Grafana displays request rate and P95 latency.

Error monitoring:

- Visit `/error`.
- The Flask app emits an error log.
- `flask_http_errors_total` increments.
- Grafana shows the error count.
- Loki can query the error log.
- Grafana alerting can fire when errors exceed the configured threshold.

Infrastructure monitoring:

- Node Exporter exposes host CPU and memory metrics.
- Prometheus scrapes those metrics every 15 seconds.
- Grafana visualizes CPU and memory usage.
- Grafana alerting can fire when CPU usage exceeds 80% for 2 minutes.

Log aggregation:

- Docker writes container logs as JSON files.
- Promtail tails those files.
- Loki stores the log streams.
- Grafana displays error logs through the logs panel.

## 23. External Access and Ports

| Port | Component | Local URL | AWS Security Group |
| --- | --- | --- | --- |
| `5001` | Flask app | `http://localhost:5001` | Allowed from `allowed_app_cidr`. |
| `3005` | Grafana | `http://localhost:3005` | Allowed from `allowed_app_cidr`. |
| `9090` | Prometheus | `http://localhost:9090` | Allowed from `allowed_app_cidr`. |
| `9100` | Node Exporter | `http://localhost:9100` | Exposed locally by Compose; not opened in Terraform security group. |
| `3100` | Loki | `http://localhost:3100` | Exposed locally by Compose; not opened in Terraform security group. |
| `22` | SSH | Not applicable | Allowed from `allowed_ssh_cidr`. |

## 24. Current Implementation Boundaries

The project is intentionally demonstration-oriented and lightweight.

Current boundaries:

- Flask app has simple string responses rather than a full business domain.
- Grafana local credentials default to `admin/admin`; production override expects secrets.
- Loki uses local filesystem storage, suitable for demo/single-host usage.
- Terraform creates a single EC2 instance, not a highly available deployment.
- Promtail Docker log access depends on Linux-style Docker log paths.
- Alerting rules are provisioned, but notification contact points are not defined in the repository.

## 25. Resume Summary

This repository implements a centralized observability platform for containerized services. It includes real-time application metrics, infrastructure metrics, centralized Docker logs, Grafana dashboards, Grafana alert rules, CI validation, AWS EC2 provisioning, and automated EC2 deployment. The main value of the project is showing a complete DevOps monitoring workflow from local development through cloud deployment using common production observability tools.
