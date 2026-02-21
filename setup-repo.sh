#!/bin/bash
# aegis-terraform repo 초기화 스크립트
# terraform-example/ 디렉토리에서 실행

set -e

echo "=== aegis-terraform repo setup ==="

# 1. GitHub repo 생성 (gh CLI 필요)
echo "Creating GitHub repo..."
gh repo create aegis-terraform --private --description "Aegis AWS Infrastructure (Terraform)" || echo "Repo may already exist"

# 2. 현재 디렉토리를 git 초기화
cd "$(dirname "$0")"

if [ ! -d .git ]; then
  git init
  git branch -M main
fi

# 3. 커밋
git add -A
git commit -m "Initial terraform setup: MediaMTX, Qdrant, Cloud Map, NLB, Tailscale

- EC2 + Fargate dual deployment configurations
- MediaMTX streaming (NLB WebRTC UDP + ALB WHEP HTTP)
- Qdrant vector DB with EFS persistent storage
- Cloud Map service discovery (aegis.local)
- Tailscale VPN sidecar (conditional)
- GitHub Actions OIDC CI/CD
- CloudWatch alarms for all services"

# 4. Remote 추가 및 push
git remote add origin "$(gh repo view aegis-terraform --json sshUrl -q '.sshUrl')" 2>/dev/null || true
git push -u origin main

echo "=== Done! ==="
echo "Next steps:"
echo "1. Copy terraform.tfvars.example -> terraform.tfvars (in your chosen dir: ec2/ or fargate/)"
echo "2. Fill in terraform.tfvars values"
echo "3. Create S3 backend bucket + DynamoDB lock table"
echo "4. Run: cd fargate && terraform init && terraform plan"
