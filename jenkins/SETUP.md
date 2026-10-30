# Jenkins setup (local Ubuntu 24.04, exposed with ngrok)

## 1. Requirements on the Jenkins machine
```bash
sudo usermod -aG docker jenkins      # jenkins user can run docker
sudo systemctl restart jenkins
```
Docker, `ssh`, `scp` and `curl` must be installed. (No Python or AWS CLI needed: lint/test run in containers.)

## 2. Plugins
Git, GitHub, Pipeline, Credentials Binding, JUnit (usually pre-installed).

## 3. Credentials (Manage Jenkins → Credentials → Global)

| ID | Kind | Value |
|---|---|---|
| `dockerhub-creds` | Username with password | Docker Hub username + an **access token** (Docker Hub → Account Settings → Security) |
| `swarm-manager-ssh` | SSH Username with private key | username `ubuntu`, contents of `~/.ssh/cc-project` |
| `telegram-bot-token` | Secret text | token from @BotFather |
| `telegram-chat-id` | Secret text | your chat ID (see below) |

Telegram: talk to **@BotFather** → `/newbot` → copy the token. Send any message to your bot, then open
`https://api.telegram.org/bot<TOKEN>/getUpdates` and read `"chat":{"id": ...}`.

## 4. Job
New Item → `cc-capstone` → **Pipeline** → *Pipeline script from SCM* → Git → repo URL → branch `*/main` → script path `Jenkinsfile`.
Run **Build Now** once so Jenkins reads the `githubPush()` trigger from the Jenkinsfile.

## 5. Webhook
`ngrok http 8080`, then GitHub → repo → Settings → Webhooks → Add:
- Payload URL `https://<ngrok-domain>/github-webhook/` (keep the trailing slash)
- Content type `application/json`, event *Just the push event*

## 6. Edit the Jenkinsfile
`REGISTRY_USER` (Docker Hub username) and `SWARM_MANAGER` (`ubuntu@<terraform output manager_public_ip>`).
