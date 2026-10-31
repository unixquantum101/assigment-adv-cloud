# Cloud Computing Capstone — GitHub · Jenkins · Terraform · Docker · Docker Swarm · EC2

**Name:** _Seng Kimoun_  **Course:** Cloud Computing  **Date:** _31-10-2026_
**Repository:**https://github.com/unixquantum101/assigment-adv-cloud.git
**Live deployment:** http://_MANAGER_ELASTIC_IP_  (nginx load balancer, served by a 3-node Docker Swarm on EC2)

## 1. What this project is

A small multi-service web application that is provisioned, built, tested and deployed
without manual steps:

- **Terraform** creates the AWS network and a 3-node EC2 cluster (1 manager + 2 workers) and forms the Docker Swarm.
- **Jenkins** (running on my own Ubuntu machine, exposed with ngrok) is triggered by a **GitHub** webhook, lints and tests the code, builds three Docker images, pushes them to **Docker Hub**, and deploys the stack to the Swarm.
- **Docker Swarm** runs the services with replicas, rolling updates and an internal service VIP load balancer; **nginx** is the public entry point and routes to each backend service.

## 2. Architecture

```
                       ┌──────────────────────────────────────────────────────┐
 Developer ──push──▶ GitHub ──webhook──▶ Jenkins (local Ubuntu + ngrok)         │
                       │   lint → test → build → push → deploy → verify         │
                       └───────────┬──────────────────────────┬───────────────┘
                                   │ docker push              │ ssh + docker stack deploy
                                   ▼                          ▼
                              Docker Hub              ┌─── AWS (Terraform) ─────────────────────────────┐
                                   │ docker pull      │ VPC 10.20.0.0/16 · public subnet · SG · key pair │
                                   └─────────────────▶│                                                  │
                                                      │  manager (EIP)      worker-1        worker-2     │
 User ──HTTP :80──▶ routing mesh (any node) ─────────▶│  ┌────────┐       ┌────────┐      ┌────────┐    │
                                                      │  │ nginx  │       │ nginx  │      │ nginx  │    │  global
                                                      │  └───┬────┘       └───┬────┘      └───┬────┘    │
                                                      │      │  overlay `appnet` (service VIPs)         │
                                                      │      ├── "/"      ─▶ web  (2 replicas)          │
                                                      │      └── "/api/*" ─▶ api  (3 replicas)          │
                                                      │                         │ overlay `datanet`      │
                                                      │                         ▼                        │
                                                      │                      redis (1, on manager,       │
                                                      │                      named volume)               │
                                                      └──────────────────────────────────────────────────┘
```

**Request path:** user → any node's public IP on port 80 → Swarm routing mesh → an `nginx` task →
`web` or `api` by **service name** (Docker DNS resolves it to the service VIP, which spreads requests over all replicas) →
`api` talks to `redis` over a private overlay network.

| Route (via nginx) | Backend | Proves |
|---|---|---|
| `/nginx-health` | nginx | the load balancer itself |
| `/` | `web` (2 replicas) | nginx → web; web calls api by name |
| `/api/health`, `/api/info` | `api` (3 replicas) | nginx → api; `hostname` changes between replicas |
| `/api/hits` | `api` → `redis` | full path incl. data store |

## 3. Repository layout

```
.
├── services/
│   ├── web/            # Flask front-end + Dockerfile + tests
│   └── api/            # Flask JSON API + Dockerfile + tests
├── nginx/              # nginx.conf + Dockerfile (load balancer)
├── terraform/          # VPC, subnet, SG, key pair, EC2 x3, EIP, swarm bootstrap, S3 backend
├── jenkins/SETUP.md    # Jenkins plugins, credentials, job, webhook
├── scripts/            # smoke-test.sh, wait-converged.sh
├── docker-compose.yml  # local development (one command)
├── docker-stack.yml    # Swarm stack (replicas, restart_policy, update_config)
├── Jenkinsfile         # pipeline as code
└── docs/               # report
```

## 4. Run locally (Docker Compose)

```bash
docker compose up --build
# open http://localhost:8080  and  http://localhost:8080/api/info
bash scripts/smoke-test.sh http://localhost:8080
docker compose down
```

## 5. Provision the cloud (Terraform)

Prerequisites: Terraform ≥ 1.10, AWS CLI configured (`aws configure`) with a user allowed to manage EC2/VPC/S3, and `ssh`.

```bash
# one-time: SSH key pair (the public half is uploaded by Terraform, the private half never leaves your machine)
ssh-keygen -t ed25519 -f ~/.ssh/cc-project -N ""

# one-time: S3 bucket for remote state
aws s3api create-bucket --bucket <unique-state-bucket> --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1
aws s3api put-bucket-versioning --bucket <unique-state-bucket> --versioning-configuration Status=Enabled

cd terraform
cp terraform.tfvars.example terraform.tfvars      # set admin_cidr = "<your-public-ip>/32"
terraform init -backend-config="bucket=<unique-state-bucket>" -backend-config="region=ap-southeast-1"
terraform plan
terraform apply
```

Outputs give the manager's Elastic IP. Check the cluster:

```bash
ssh -i ~/.ssh/cc-project ubuntu@<manager-ip> "docker node ls"     # 3 nodes, all Ready
```

Teardown when finished grading: `terraform destroy`.

SSH (22) is open to 0.0.0.0/0 because the administrator works from a mobile hotspot whose public IP changes constantly. Access is key-pair only: no passwords exist on the instances and the private key is never committed. HTTP (80) is open to the world for the application; swarm ports 2377/7946/4789 are allowed only between members of the cluster’s security group. In a production setup SSH would be restricted to a fixed address or replaced by AWS Systems Manager Session Manager.

## 6. CI/CD (Jenkins)

See [jenkins/SETUP.md](jenkins/SETUP.md) for plugins, credentials, job configuration and the webhook.

| Stage | What it does |
|---|---|
| Checkout | clone, compute tag `<build#>-<git sha>` |
| Lint | `flake8` for both services (in a Python container) |
| Test | `pytest` for both services; a failing test fails the pipeline; JUnit results published |
| Build images | `cc-api`, `cc-web`, `cc-nginx` |
| Push to Docker Hub | credentials from Jenkins, images pushed with the traceable tag |
| Deploy to Swarm | SSH to the manager → `docker stack deploy --with-registry-auth` → wait for rolling update |
| Verify | `smoke-test.sh` makes a live request to every route through nginx |
| post (always) | Telegram message ✅/❌ with job name, build number, tag, URL |

Trigger: GitHub webhook `https://<ngrok>/github-webhook/` on push to `main`.

## 7. How to verify the deployment

```bash
bash scripts/smoke-test.sh http://<manager-ip>           # all PASS
curl -s http://<manager-ip>/api/info                     # run several times: hostname changes (load balancing)
ssh ubuntu@<manager-ip> "docker stack ps cc"             # tasks spread over 3 nodes
ssh ubuntu@<manager-ip> "docker service ls"              # replicas: nginx 3/3, web 2/2, api 3/3, redis 1/1
```

**Rolling update:** change a message in `services/web/app.py`, push to `main`; Jenkins redeploys and
`docker service ps cc_web` shows old tasks `Shutdown` and new ones `Running`, one at a time (`parallelism: 1`, `order: start-first`),
while `curl` against the site keeps answering.

**Failover test:** `ssh ubuntu@<manager-ip> "docker node update --availability drain <worker-name>"` (or stop a worker
instance in the console): Swarm reschedules that node's tasks on the others and the site stays up.
Restore with `--availability active`.

## 8. Extra credit — Telegram notifications

The `post { always }` block of the `Jenkinsfile` calls the Telegram Bot API. The bot token and chat ID are
Jenkins credentials (`telegram-bot-token`, `telegram-chat-id`) — never in the repository. The message starts with ✅ on success and ❌ on failure and includes the job name and build number.

## 9. Git workflow

Feature branches merged by pull request, small descriptive commits:
_(list your PRs, e.g. `feature/app-services`, `feature/terraform`, `feature/jenkinsfile`)_

## 10. Screenshots (in `docs/screenshots/`)

| File | Shows |
|---|---|
| `01-compose-local.png` | local stack running with Compose |
| `02-terraform-apply.png` | `terraform apply` output + outputs |
| `03-aws-console-instances.png` | 3 tagged EC2 instances + security group rules |
| `04-docker-node-ls.png` | 1 manager + 2 workers, all Ready |
| `05-jenkins-stages.png` | pipeline stage view, all green |
| `06-github-webhook.png` | webhook recent delivery 200 |
| `07-dockerhub.png` | Docker Hub repositories with pushed tags |
| `08-stack-ps.png` | `docker stack ps cc` across 3 nodes |
| `09-smoke-test.png` | live request per route |
| `10-load-balancing.png` | repeated `/api/info` showing different hostnames |
| `11-rolling-update.png` | `docker service ps` during a redeploy |
| `12-failover.png` | drained worker and rescheduled tasks |
| `13-failed-test.png` | a deliberately failing test stopping the pipeline |
| `14-telegram.png` | Telegram ✅ and ❌ messages |
# assigment-adv-cloud
