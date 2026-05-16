# Myra Pipeline — CI, Docker, Monitoring, Terraform and Kubernetes

---

## 📌 Project Overview
This is a transaction pipeline that simulates how transactions flow through a fintech system in three stages — Ingestion, Validation, and Processing. It aims to demonstrate modern DevOps practices including containerisation, monitoring, CI/CD, and cloud deployment.

---

## 🚀 Features
- Three stage transaction pipeline (Ingestion → Validation → Processing)
- Docker-based containerisation
- Continuous testing on every push with GitHub Actions
- Prometheus metrics and Grafana dashboard
- Kubernetes deployment with Minikube
- AWS infrastructure with Terraform

---

## 🔧 Technologies Used
- Git & GitHub
- GitHub Actions (CI/CD)
- Docker & Docker Compose
- Python (FastAPI)
- MySQL
- Redis (message queue)
- Prometheus & Grafana
- Kubernetes (Minikube)
- Terraform (AWS)

---

## 📂 Project Structure

```
project/
├── .github/workflows/ci.yml
├── ingestion/
│   ├── main.py
│   ├── Dockerfile
│   └── requirements.txt
├── validation/
│   ├── main.py
│   ├── Dockerfile
│   └── requirements.txt
├── processing/
│   ├── main.py
│   ├── Dockerfile
│   └── requirements.txt
├── db/
│   └── init.sql
├── prometheus/
│   └── prometheus.yml
├── scripts/
│   ├── load_check.sh
│   └── health_check.sh
├── k8s/
├── infra/
├── RUNBOOK.md
├── README.md
└── docker-compose.yml
```

---

## 🛠 How to Run

### Running Locally

Clone the repo:
```bash
git clone <repo-url>
cd SCA-fintech-pipeline
```

Build and start all containers:
```bash
docker compose up --build
```

Check all containers are running:
```bash
./scripts/health_check.sh
```

Send 50 test transactions through the pipeline:
```bash
./scripts/load_check.sh
```

Watch live logs from all three services:
```bash
docker compose logs -f ingestion validation processing
```

Check the database is storing transactions:
```bash
docker compose exec db mysql -u user -ppassword transactions -e "SELECT * FROM transactions;"
```

Open Grafana at `http://localhost:3000` (login: admin/admin), add Prometheus as a datasource using `http://prometheus:9090`, then build your dashboard with these queries:
```
transactions_received_total
transactions_validated_total
transactions_failed_total
transactions_approved_total
```

---

### Setting Up Kubernetes

Start Minikube:
```bash
minikube start
minikube status
```

If Minikube throws an error, do a clean restart:
```bash
minikube stop
minikube delete
minikube start
```

Apply in order:
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/redis/
kubectl apply -f k8s/ingestion/
kubectl apply -f k8s/validation/
kubectl apply -f k8s/processing/
```

Check pods and services:
```bash
kubectl get pods -n payment-pipeline
kubectl get services -n payment-pipeline
```

> **Note:** Ingestion, validation and processing will likely show `ErrImageNeverPull` because Minikube runs a separate Docker environment. Fix it by loading the images manually:

```bash
eval $(minikube docker-env --unset)

docker build -t ingestion:latest ./ingestion
docker build -t validation:latest ./validation
docker build -t processing:latest ./processing

minikube image load ingestion:latest
minikube image load validation:latest
minikube image load processing:latest
```

Run `kubectl get pods -n payment-pipeline` again — status should now show `Running`.

Test the pipeline is working inside Kubernetes:
```bash
minikube service ingestion -n payment-pipeline --url
```

Use the URL it returns to send a test transaction:
```bash
curl -X POST {minikube url}/transaction \
  -H "Content-Type: application/json" \
  -d '{"amount": 500, "currency": "NGN", "sender": "minikube_test", "receiver": "merchant_01"}'
```

A `202 Accepted` response means the pipeline is working inside Kubernetes.

Check logs to confirm the transaction flowed through all stages:
```bash
kubectl logs -n payment-pipeline deployment/validation
kubectl logs -n payment-pipeline deployment/processing
```

You should see `action=validated` and `action=approved` in the output.

---

### Setting Up Terraform (AWS)

Configure your AWS credentials first:
```bash
aws configure
```

Then:
```bash
cd infra
terraform init
terraform plan
terraform apply -var="db_password=yourpassword"
```

> **Important:** Run `terraform destroy` when done to avoid unnecessary AWS charges:
```bash
terraform destroy
```

---

### Cleanup

Stop Docker Compose and Minikube when done:
```bash
docker compose down
minikube stop
```