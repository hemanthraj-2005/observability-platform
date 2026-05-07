# DevOps Observability Platform

A production-style local observability platform for containerized applications using Docker Compose, Flask, Prometheus, Node Exporter, Loki, Promtail, and Grafana.

The stack demonstrates infrastructure monitoring, application metrics, centralized Docker log collection, dashboard visualization, and simulated error tracking.

## Architecture

```text
Flask App
  |-- /metrics ------------------> Prometheus ----\
  |-- Docker container logs -----> Promtail ------> Loki ----\
                                                              > Grafana
Node Exporter -------------------> Prometheus ---------------/
```

## Cloud Deployment Architecture

```text
GitHub Actions CI
  |-- tests, JSON validation, Compose validation, Docker build

GitHub Actions Terraform
  |-- provisions AWS security group and EC2 host

GitHub Actions CD
  |-- syncs repo to EC2
  |-- writes production .env from GitHub Secrets
  |-- runs docker compose on EC2
```

## Services

| Service | Purpose | URL |
| --- | --- | --- |
| Flask App | Sample application with logs, health checks, errors, and Prometheus metrics | http://localhost:5001 |
| Prometheus | Time-series metrics collection and PromQL queries | http://localhost:9090 |
| Grafana | Dashboards for metrics and logs | http://localhost:3005 |
| Node Exporter | Host/system metrics exporter | http://localhost:9100 |
| Loki | Centralized log storage and querying | http://localhost:3100 |
| Promtail | Docker log collector that forwards logs to Loki | Internal |

Grafana login:

```text
username: admin
password: admin
```

## Application Endpoints

| Endpoint | Purpose |
| --- | --- |
| `/` | Returns application status and emits an info log |
| `/error` | Generates a simulated HTTP 500 error and error log |
| `/health` | Health check endpoint |
| `/metrics` | Prometheus metrics endpoint |

## Metrics Added

The Flask app exposes custom Prometheus metrics:

| Metric | Description |
| --- | --- |
| `flask_http_requests_total` | Request counter by method, endpoint, and HTTP status |
| `flask_http_request_duration_seconds` | Request latency histogram |
| `flask_http_errors_total` | Simulated application error counter |

Prometheus also scrapes:

- `prometheus:9090`
- `node-exporter:9100`
- `flask-app:5000/metrics`

## Grafana Dashboard

The project provisions Grafana automatically with:

- Prometheus datasource
- Loki datasource
- DevOps Observability dashboard

Dashboard panels:

- User Requests
- Application Errors
- P95 Request Latency
- CPU Usage %
- Memory Usage %
- Recent Error Logs

## Alerts

Grafana alert rules are provisioned automatically:

| Alert | Trigger |
| --- | --- |
| Flask High Error Count | More than 5 Flask errors in 5 minutes |
| Node High CPU Usage | CPU usage above 80% for 2 minutes |

## Run Locally

Start the full stack:

```bash
docker compose up --build
```

Generate normal traffic:

```bash
curl http://localhost:5001/
curl http://localhost:5001/health
```

Generate an application error:

```bash
curl http://localhost:5001/error
```

Open Grafana:

```text
http://localhost:3005
```

Go to **Dashboards > DevOps Observability > DevOps Observability Platform**.

## CI/CD

The project includes GitHub Actions workflows:

| Workflow | Purpose |
| --- | --- |
| `.github/workflows/ci.yml` | Test, validate, and build |
| `.github/workflows/terraform.yml` | Provision AWS EC2 infrastructure with Terraform |
| `.github/workflows/cd.yml` | Deploy the Docker Compose stack to EC2 |

The CI pipeline runs on every push and pull request to `main`:

- installs Python dependencies
- runs Flask endpoint tests
- validates Python syntax
- validates Grafana dashboard JSON
- validates Docker Compose configuration
- validates production Docker Compose configuration
- builds the Flask Docker image

Run the same core checks locally:

```bash
pip install -r app/requirements-dev.txt
cd app
pytest -q
cd ..
docker compose config
GRAFANA_ADMIN_PASSWORD=ci-test-password docker compose -f docker-compose.yml -f docker-compose.prod.yml config
docker build -t observability-platform-flask-app:ci ./app
```

## AWS Infrastructure With Terraform

Terraform files live in `infra/terraform`.

The Terraform module provisions:

- EC2 instance
- security group
- encrypted EBS root volume
- Docker bootstrap through EC2 user data
- public URLs as outputs

Create a Terraform variables file:

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region       = "ap-south-1"
key_name         = "your-existing-ec2-keypair"
allowed_ssh_cidr = "YOUR_PUBLIC_IP/32"
allowed_app_cidr = "YOUR_PUBLIC_IP/32"
```

Run Terraform locally:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

## GitHub Secrets For Terraform/CD

Add these GitHub repository secrets:

| Secret | Purpose |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | AWS access key for Terraform |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for Terraform |
| `EC2_KEY_NAME` | Existing AWS EC2 key pair name |
| `ALLOWED_SSH_CIDR` | CIDR allowed to SSH, for example `x.x.x.x/32` |
| `ALLOWED_APP_CIDR` | CIDR allowed to reach Grafana, Prometheus, and Flask |
| `EC2_HOST` | EC2 public IP or DNS after Terraform creates the host |
| `EC2_USER` | SSH user, usually `ubuntu` |
| `EC2_SSH_PRIVATE_KEY` | Private key matching the EC2 key pair |
| `GRAFANA_ADMIN_USER` | Production Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | Production Grafana admin password |

Optional GitHub variable:

| Variable | Purpose |
| --- | --- |
| `AWS_REGION` | AWS region, default is `ap-south-1` |

## Deploy To EC2

After Terraform creates the instance and Docker bootstrap finishes, run the **CD** workflow from GitHub Actions or push to `main`.

The CD workflow:

- copies the project to `/opt/observability-platform`
- writes `.env` on the server from GitHub Secrets
- runs `infra/scripts/deploy.sh`
- starts the production Compose stack

Production Compose uses persistent Docker volumes for:

- Grafana data
- Prometheus data
- Loki data

## Useful PromQL Queries

Request rate:

```promql
sum by (endpoint) (rate(flask_http_requests_total[1m]))
```

Application errors in the last 5 minutes:

```promql
sum(increase(flask_http_errors_total[5m]))
```

P95 request latency:

```promql
histogram_quantile(0.95, sum(rate(flask_http_request_duration_seconds_bucket[5m])) by (le))
```

CPU usage:

```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

Memory usage:

```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

## Useful LogQL Queries

All Docker logs:

```logql
{job="docker"}
```

Error logs:

```logql
{job="docker"} |= "error"
```

Flask access/error activity:

```logql
{job="docker"} |= "flask-app"
```

## Notes

Promtail reads Docker JSON logs from `/var/lib/docker/containers`. This path works naturally on Linux Docker hosts. On Docker Desktop for macOS, Docker log access can vary depending on the Docker runtime configuration.

## Resume Summary

Designed and deployed a centralized observability platform using Grafana, Prometheus, Loki, Promtail, Docker Compose, Node Exporter, and Flask. Implemented real-time infrastructure monitoring, application-level Prometheus metrics, centralized Docker log aggregation, dashboard provisioning, and simulated error tracking for containerized services.
