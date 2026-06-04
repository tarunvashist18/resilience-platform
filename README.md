# 🛡️ Resilience Testing Platform

A web-based chaos engineering platform that accepts any Docker image, deploys it dynamically to Kubernetes, runs automated chaos experiments, and produces a scored resilience report.

**Built by:** Ashu Chaudhary  
**Stack:** Flask · Docker · Kubernetes · Minikube · Chaos Mesh  
**Monitoring:** Prometheus · Grafana  
**CI/CD:** GitHub Actions · Trivy  

---

## 🚀 What It Does

1. User enters any public Docker image (e.g. `nginx:latest`)
2. Platform deploys it dynamically to Kubernetes (2 replicas)
3. Runs 5 automated chaos experiments via Chaos Mesh
4. Scores recovery performance and assigns a letter grade (A–D)
5. Displays a full breakdown dashboard with per-test results

**Total test time:** ~5–8 minutes per image

---

## 🏗️ Architecture

```
Browser → Flask App (port 5001)
            ├── services/deployer.py     → kubectl apply dynamic YAML
            ├── services/chaos_runner.py → Chaos Mesh experiments
            └── services/scorer.py      → Score calculation engine

Infrastructure (chaos-project):
MacBook M2 Air → Minikube → Kubernetes Cluster
    ├── Chaos Mesh       (chaos-testing namespace)
    ├── Prometheus       (monitoring namespace)
    └── Grafana          (monitoring namespace)
```

---

## 🧪 Chaos Tests

| # | Test | Type | Condition | Pass Criteria |
|---|------|------|-----------|---------------|
| 1 | Pod Chaos | PodChaos / pod-kill | 1 pod killed | ≥ 2 pods running |
| 2 | CPU Stress | StressChaos | 80% CPU, 60s | ≥ 2 pods running |
| 3 | Memory Stress | StressChaos | 256MB, 60s | ≥ 2 pods running |
| 4 | Network Delay | NetworkChaos | 3000ms latency | ≥ 2 pods running |
| 5 | Packet Loss | NetworkChaos | 30% loss, 60s | ≥ 2 pods running |
| 6 | Recovery Validation | — | Final check | ≥ 2 pods running |

---

## 📊 Scoring System

| Category | PASS Score | FAIL Score | Weight |
|----------|-----------|-----------|--------|
| Self-Healing (Pod Chaos) | 95/100 | 30/100 | 25% |
| CPU Resilience | 88/100 | 25/100 | 15% |
| Memory Resilience | 90/100 | 25/100 | 15% |
| Network Resilience | 92/100 | 20/100 | 15% |
| Packet Resilience | 89/100 | 20/100 | 15% |
| Recovery Validation | 95/100 | 10/100 | 15% |

**Grades:** A (90–100) · B (75–89) · C (60–74) · D (0–59)

---

## 📁 File Structure

```
resilience-platform/
├── app.py                    # Flask web server (port 5001)
├── venv/                     # Python virtual environment
├── templates/
│   ├── index.html            # Dashboard — Docker image input
│   └── result.html           # Results page with scores
├── static/
│   └── style.css             # Dark terminal-style theme
└── services/
    ├── deployer.py           # Dynamic K8s deployment generator
    ├── chaos_runner.py       # Chaos experiment engine
    └── scorer.py             # Score calculation engine
```

---

## ⚙️ Prerequisites

- macOS with Minikube installed
- Chaos Mesh installed in `chaos-testing` namespace
- Prometheus + Grafana running
- Python 3 + pip

---

## 🏃 How to Run

### Step 1 — Start Minikube
```bash
minikube start
minikube status
```

### Step 2 — Verify Chaos Mesh
```bash
kubectl get pods -n chaos-testing
# Should see: chaos-controller-manager, chaos-daemon, chaos-dashboard — all Running
```

### Step 3 — Start the platform
```bash
cd ~/kitchenofthebunny/resilience-platform
source venv/bin/activate
python3 app.py
```

### Step 4 — Open browser
```
http://127.0.0.1:5001
```

---

## 🔧 Troubleshooting

| Problem | Fix |
|---------|-----|
| `python` not found | Use `python3` |
| Port 5001 in use | `lsof -i :5001` then `kill -9 <PID>` |
| venv not activated | `source venv/bin/activate` (look for `(venv)` in prompt) |
| Chaos test FAIL | Check `kubectl get pods -n chaos-testing` — Chaos Mesh must be running |
| Pods not ready | Image may take longer to pull — increase timeout in `deployer.py` |

### Cleanup after testing
```bash
kubectl delete deployment resilience-nginx-latest
```

---

## 🗺️ Roadmap

- [x] Phase 1 — Web Dashboard
- [x] Phase 2 — Dynamic Kubernetes Deployment
- [x] Phase 3 — Automated Chaos Testing Engine
- [x] Phase 4 — Resilience Scoring Engine
- [x] Phase 5a — Loading Screen (no browser freeze)
- [ ] Phase 5b — Dynamic scoring based on recovery time
- [ ] Phase 5c — PDF report download
- [ ] Phase 5d — Auto-cleanup after testing
- [ ] Phase 5e — Cloud deployment (AWS EKS / GKE)
- [ ] Phase 5f — User accounts + test history
- [ ] Phase 5g — Webhook notifications (email / Slack)
- [ ] Phase 5h — Batch testing (multiple images)

---

## 📄 License

MIT — built for learning, portfolio, and fun.
