# AEGIS Terraform Infrastructure

AEGIS(Agent-based Safety Monitoring System)의 AWS 인프라를 Terraform으로 관리하는 레포지토리.

## Architecture

```
Browser ──► CloudFront ──► ALB ─┬── /api/*    → Backend (ECS Fargate)
                                ├── /stream/* → MediaMTX WHEP
                                ├── /sse/*    → Backend SSE
                                └── /*        → S3 (Frontend 정적 파일)

카메라 PC ──(Tailscale VPN)──► MediaMTX (ECS) ──► Agent Ingest ──► SQS ──► Agent Worker
```

| AWS 서비스 | 용도 | 로컬 대응 |
|-----------|------|----------|
| ECS Fargate | Backend, Agent, MediaMTX, Qdrant | Docker Compose |
| RDS PostgreSQL | 관계형 DB | PostgreSQL 컨테이너 |
| ElastiCache | Redis 캐시 + Pub/Sub | Redis 컨테이너 |
| S3 | Frontend 정적 호스팅 + 영상 클립 저장 | MinIO |
| CloudFront | CDN + API 프록시 | Caddy 리버스 프록시 |
| SQS | 분석 작업 큐 | Python queue.Queue |
| EFS | Qdrant 벡터 DB 영구 저장소 | Docker volume |
| Cloud Map | 서비스 간 DNS (`aegis.local`) | localhost |

## 관련 레포지토리

| 레포 | 기술 스택 | 배포 방식 |
|------|----------|----------|
| [aegis-backend](https://github.com/AIX-01/aegis-backend) | Spring Boot 3.5.9 (Java 21) | ECR → ECS |
| [aegis-frontend](https://github.com/AIX-01/aegis-frontend) | Next.js 15 + React 19 | S3 + CloudFront |
| [aegis-ai-agent](https://github.com/AIX-01/aegis-ai-agent) | Python FastAPI + LangGraph | ECR → ECS (ingest/worker) |

## AWS 리소스 현황

```bash
# terraform output (2026-02-23)
CloudFront  = d32tvhj9tbkse8.cloudfront.net
ALB         = aegis-alb-1046588538.ap-northeast-2.elb.amazonaws.com
RDS         = aegis-postgres.cbq8esiccx10.ap-northeast-2.rds.amazonaws.com:5432
Redis       = aegis-redis.v1hxb6.0001.apn2.cache.amazonaws.com
SQS         = https://sqs.ap-northeast-2.amazonaws.com/676323537989/aegis-analysis-queue
ECR         = aegis/backend, aegis/agent
S3          = aegis-frontend-676323537989, aegis-clips-676323537989
```

## 디렉토리 구조

```
├── MIGRATION_PLAN.md     # 마이그레이션 계획 (아키텍처, 결정사항, 비용 등)
├── ISSUES.md             # 배포/운영 이슈 기록
├── fargate/              # Fargate 버전 (현재 사용 중)
│   ├── main.tf           # Provider, S3 backend
│   ├── variables.tf      # 변수 정의
│   ├── terraform.tfvars  # 변수 값 (gitignore)
│   ├── vpc.tf            # VPC, 서브넷, IGW, NAT
│   ├── security_groups.tf
│   ├── iam.tf            # ECS Task Role, GitHub OIDC
│   ├── rds.tf            # PostgreSQL
│   ├── elasticache.tf    # Redis
│   ├── s3.tf             # Frontend + Clips 버킷
│   ├── sqs.tf            # 분석 큐 + DLQ
│   ├── ecr.tf            # 컨테이너 레지스트리
│   ├── efs.tf            # Qdrant 저장소
│   ├── ecs_*.tf          # ECS 서비스 (backend, agent, mediamtx, qdrant)
│   ├── alb.tf / nlb.tf   # 로드밸런서
│   ├── cloudfront.tf     # CDN + API 프록시 + SPA rewrite
│   ├── cloudwatch.tf     # 모니터링
│   └── outputs.tf
└── ec2/                  # EC2 버전 (비용 최적화 시 전환용)
```

## 배포 상태 (2026-02-23)

| 서비스 | 코드 변경 | Dockerfile | deploy.yml | 배포 |
|--------|---------|------------|------------|------|
| Backend | ✅ Actuator, S3 IAM 분기 | ✅ Multi-stage JRE 21 | ✅ ECR → ECS | ✅ 2 tasks RUNNING |
| Frontend | ✅ 변경 불필요 | N/A (S3 정적) | ✅ S3 sync + CF invalidation | ✅ CloudFront 접속 확인 |
| AI Agent | ✅ AGENT_MODE 분기, SQS 어댑터 | ✅ Python 3.12 | ✅ ECR → ECS | ✅ |
| Terraform | - | - | ⚠️ OIDC 인증 실패 | 로컬 apply 우회 중 |

## CI/CD (GitHub Actions)

`.github/workflows/terraform.yml` — Terraform 버전 1.7.0, OIDC 인증.

| 트리거 | 조건 | 동작 |
|--------|------|------|
| `pull_request` → main | `fargate/**` 또는 `ec2/**` 변경 시 | `terraform plan` 실행, PR에 결과 코멘트 |
| `push` → main | `fargate/**` 또는 `ec2/**` 변경 시 | `terraform apply -auto-approve` |

각 서비스 레포에도 별도 deploy workflow 존재:

| 레포 | 워크플로우 | 트리거 | 동작 |
|------|-----------|--------|------|
| aegis-backend | `deploy.yml` | main push | Docker build → ECR push → ECS force-new-deployment |
| aegis-frontend | `deploy.yml` | main push | pnpm build → S3 sync → CloudFront invalidation |
| aegis-ai-agent | `deploy.yml` | main push | Docker build → ECR push → ECS force-new-deployment (ingest + worker) |

## 미해결 사항

- **GitHub Actions OIDC**: `aegis-terraform` repo에서 `terraform apply` 자동 실행 불가 → [ISSUES.md #2](./ISSUES.md#issue-2-github-actions-oidc-인증-실패-미해결)
- **Tailscale VPN**: 카메라 PC 연결 미설정
- **도메인**: 커스텀 도메인 미설정 (현재 CloudFront 기본 도메인 사용)

## 사용법

```bash
cd fargate

# 초기화
terraform init

# 변경 사항 확인
terraform plan

# 적용
terraform apply

# 특정 리소스만 적용
terraform apply -target=aws_cloudfront_function.spa_rewrite
```
