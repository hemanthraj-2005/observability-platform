# Architecture

![DevOps Observability Platform architecture](assets/architecture-diagram.svg)

## Interview Walkthrough

This project has two connected parts: the runtime observability stack and the cloud delivery flow.

The runtime stack runs in Docker Compose. The Flask application exposes `/metrics`, `/health`, and `/error`. Prometheus scrapes Flask metrics and Node Exporter host metrics. Promtail tails Docker container logs from the host and forwards them to Loki. Grafana connects to Prometheus and Loki to show dashboards, logs, and alert rules.

The cloud delivery flow uses GitHub Actions and Terraform. CI validates tests, dashboard JSON, Compose configuration, and Docker builds. The Terraform workflow provisions an AWS EC2 host and security group. The CD workflow syncs the repository to EC2, writes production environment variables from GitHub Secrets, and runs the production Docker Compose stack.

## Data Flow

| Flow | Source | Destination | Purpose |
| --- | --- | --- | --- |
| Application metrics | Flask `/metrics` | Prometheus | Request count, latency, and simulated error metrics. |
| Host metrics | Node Exporter | Prometheus | CPU and memory monitoring. |
| Docker logs | Docker JSON log files | Promtail | Container log collection. |
| Centralized logs | Promtail | Loki | Log storage and LogQL queries. |
| Visualization | Prometheus and Loki | Grafana | Dashboards, panels, logs, and alerts. |
| Deployment | GitHub Actions | AWS EC2 | Automated provisioning and production deployment. |
