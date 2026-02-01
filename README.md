# Moltbot (OpenClaw) GCP Deployment

Deploy **OpenClaw** on Google Cloud Platform with full CI/CD via GitHub Actions.

## Features

- **Channels**: WhatsApp, Telegram
- **LLM Provider**: Anthropic (Claude)
- **Access**: HTTP via public IP
- **VM Size**: e2-medium (4GB RAM)
- **State**: Remote in GCS bucket
- **CI/CD**: GitHub Actions on push to `master`

## Repository Structure

```
moltbot-gcp/
├── .github/workflows/deploy.yml    # GitHub Actions CI/CD workflow
├── terraform/
│   ├── main.tf                     # GCP resources (VM, network, firewall)
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Output values (IP address, etc.)
│   ├── versions.tf                 # Provider & Terraform versions
│   ├── backend.tf                  # GCS remote state configuration
│   └── project.tf                  # GCP project creation
├── docker/
│   ├── Dockerfile                  # OpenClaw Docker image
│   └── docker-compose.yml          # Docker Compose for Gateway
├── scripts/
│   └── startup.sh                  # VM cloud-init startup script
├── config/
│   └── openclaw.json               # OpenClaw configuration
├── .env.example                    # Template for secrets
└── README.md                       # This file
```

## Initial Setup (One-time)

### 1. Create GCS Bucket for Terraform State

```bash
# Set your project ID
export PROJECT_ID="your-existing-project-id"

# Create bucket (must be globally unique)
gsutil mb -p $PROJECT_ID -l us-central1 gs://openclaw-terraform-state

# Enable versioning
gsutil versioning set on gs://openclaw-terraform-state
```

### 2. Create GCP Service Account

```bash
# Create service account
gcloud iam service-accounts create github-deployer \
    --display-name="GitHub Actions Deployer" \
    --project=$PROJECT_ID

# Grant Project Creator role (for creating new projects)
gcloud organizations add-iam-policy-binding YOUR_ORG_ID \
    --member="serviceAccount:github-deployer@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/resourcemanager.projectCreator"

# Grant Billing Account User role
gcloud beta billing accounts add-iam-policy-binding YOUR_BILLING_ACCOUNT \
    --member="serviceAccount:github-deployer@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/billing.user"

# Create and download key
gcloud iam service-accounts keys create sa-key.json \
    --iam-account=github-deployer@$PROJECT_ID.iam.gserviceaccount.com
```

### 3. Configure GitHub Secrets

Add these secrets to your GitHub repository (Settings > Secrets and variables > Actions):

| Secret | Description |
|--------|-------------|
| `GCP_SA_KEY` | Contents of `sa-key.json` (service account JSON key) |
| `GCP_BILLING_ACCOUNT` | GCP billing account ID (format: `XXXXXX-XXXXXX-XXXXXX`) |
| `GCP_PROJECT_ID` | Project ID for the Terraform state bucket |
| `ANTHROPIC_API_KEY` | Claude API key from [console.anthropic.com](https://console.anthropic.com) |
| `GATEWAY_TOKEN` | Random token for Gateway auth (`openssl rand -hex 32`) |
| `TELEGRAM_BOT_TOKEN` | From [@BotFather](https://t.me/botfather) on Telegram |

### 4. Deploy

Push to `master` branch to trigger deployment:

```bash
git add .
git commit -m "Initial deployment"
git push origin master
```

## Post-Deployment Setup

### 1. Access Gateway UI

After deployment, check the GitHub Actions summary for the Gateway URL:
```
http://<VM_IP>:18789
```

### 2. Configure Gateway

1. Open the Gateway URL in your browser
2. Enter your `GATEWAY_TOKEN` in Settings

### 3. Connect WhatsApp

SSH to the VM and run the WhatsApp login:

```bash
# Get SSH command from terraform output
gcloud compute ssh openclaw-vm --project=openclaw-bot --zone=us-central1-a

# Inside VM, run login command
docker exec -it openclaw-gateway openclaw channels login
```

Scan the QR code with WhatsApp to connect.

### 4. Connect Telegram

Telegram connects automatically using the `TELEGRAM_BOT_TOKEN`. Send a message to your bot to verify.

## Verification

### Check Infrastructure

```bash
cd terraform
terraform output
```

### Check VM Status

```bash
gcloud compute ssh openclaw-vm --project=openclaw-bot --zone=us-central1-a

# Inside VM
docker ps                                    # Check containers
docker logs openclaw-gateway                 # Check logs
curl http://localhost:18789/health           # Health check
```

### Test Channels

- **WhatsApp**: Send a message to the connected number
- **Telegram**: Send `/start` or any message to your bot

## Troubleshooting

### VM Not Starting

Check startup script logs:
```bash
gcloud compute ssh openclaw-vm -- sudo cat /var/log/openclaw-startup.log
```

### Docker Issues

```bash
gcloud compute ssh openclaw-vm

# Check Docker status
sudo systemctl status docker

# Check OpenClaw service
sudo systemctl status openclaw

# Rebuild and restart
cd /home/openclaw/docker
sudo -u openclaw docker compose down
sudo -u openclaw docker compose up -d --build
```

### Gateway Not Accessible

1. Verify firewall rules in GCP Console
2. Check if container is running: `docker ps`
3. Check container logs: `docker logs openclaw-gateway`

## Local Development

To run locally without deploying to GCP:

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values
vim .env

# Run with Docker Compose
cd docker
docker compose up -d --build
```

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

## License

MIT
