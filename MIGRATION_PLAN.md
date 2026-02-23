# AEGIS AWS Migration Plan

## 1. Project Overview

AEGIS(Agent-based Safety Monitoring System)를 로컬 Docker Compose 환경에서 AWS 클라우드로 마이그레이션하는 계획.

### 현재 로컬 구성

```
aegis/
  aegis-backend/      # Spring Boot 3.5.9 (Java 21) REST API
  aegis-ai-agent/     # Python FastAPI + LangGraph AI 분석 파이프라인
  aegis-frontend/     # Next.js 15 + React 19 + TypeScript SPA
  aegis-infra/        # Docker Compose 인프라
```

### 현재 인프라 (Docker Compose)

| 서비스 | 역할 | 포트 |
|---|---|---|
| Caddy | 리버스 프록시 + HTTPS | 443 |
| MediaMTX | RTSP/WebRTC 비디오 스트리밍 | 8554, 8889, 8890, 8189 |
| PostgreSQL | 관계형 데이터베이스 | 5432 |
| MinIO | S3 호환 오브젝트 스토리지 | 9000, 9001 |
| Redis | 캐시 + Pub/Sub | 6379 |
| Qdrant | 벡터 데이터베이스 | 6333, 6334 |

---

## 2. AWS 아키텍처

```
카메라 PC ──(Tailscale VPN)──► MediaMTX (ECS)
                                │   ├─ SRT:8890/udp (Tailscale)
                                │   ├─ RTSP:8554/tcp → AI Agent Ingest
                                │   ├─ WHEP:8889/tcp → ALB → CloudFront → Browser
                                │   ├─ WebRTC:8189/udp → NLB → Browser
                                │   └─ API:9997/tcp → Backend
                                │
Browser ──► CloudFront ──► ALB ─┤── /api/* → Backend (ECS)
                                ├── /stream/* → MediaMTX WHEP
                                ├── /sse/* → Backend SSE
                                └── /* → S3 (Frontend)

Services (Cloud Map: aegis.local):
┌─────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Backend      │  │ Agent Ingest (1) │  │ Agent Worker(1-8)│
│ (Spring Boot)│  │ (Frame capture)  │  │ (LLM analysis)   │
│ Port 8080    │  │ Port 8000        │  │ Port 8000        │
└──────┬───────┘  └──────┬───────────┘  └──────┬───────────┘
       │                 │                      │
  ┌────┴────┐       ┌────┴────┐           ┌────┴────┐
  │RDS(PG)  │       │SQS Queue│           │Qdrant   │
  │Redis    │       │Redis    │           │(ECS+EFS)│
  │S3       │       │S3       │           │Port 6333│
  └─────────┘       └─────────┘           └─────────┘
```

### AWS 서비스 매핑

| 현재 (로컬) | AWS 서비스 | 선택 이유 |
|---|---|---|
| `queue.Queue(max=20)` | **Amazon SQS Standard Queue** | 관리형, 무제한 처리량, 메시지 영속성, DLQ |
| `ThreadPoolExecutor(4)` | **ECS Fargate/EC2 (Auto Scaling)** | 컨테이너 수준 수평 확장 |
| MediaMTX | **ECS + NLB(UDP) + ALB(HTTP)** | 기존 MediaMTX 유지, dual LB 구성 |
| PostgreSQL | **RDS PostgreSQL** | 관리형, 백업 자동화 |
| MinIO | **Amazon S3** | 네이티브, 최소 코드 변경 |
| Redis | **ElastiCache Redis** | 관리형, VPC 내 |
| Qdrant | **ECS + EFS** | 공식 이미지 + 영구 저장소 |
| Caddy | **ALB + CloudFront** | 매니지드, SSL/TLS 자동 |
| Next.js Frontend | **S3 + CloudFront** (정적 배포) | SSR 미사용 |

---

## 3. Service Discovery (Cloud Map)

서비스 간 통신은 **AWS Cloud Map** (`aegis.local` 네임스페이스)으로 해결:

| 서비스 | DNS | 포트 | 사용처 |
|---|---|---|---|
| Backend | `backend.aegis.local` | 8080 | Agent Worker → 분석 결과 전송 |
| MediaMTX | `mediamtx.aegis.local` | 8554/9997 | Agent Ingest → RTSP, Backend → API |
| Qdrant | `qdrant.aegis.local` | 6333 | Agent Ingest/Worker → 벡터 검색 |

---

## 4. MediaMTX 스트리밍 아키텍처

### 네트워크 구성

| 프로토콜 | 포트 | LB | 접근자 | 용도 |
|---|---|---|---|---|
| API | 9997/tcp | - | Backend (Cloud Map) | 경로 관리/웹훅 |
| RTSP | 8554/tcp | - | Agent Ingest (Cloud Map) | 프레임 수집 |
| WHEP | 8889/tcp | ALB | Browser (CloudFront) | HTTP 기반 스트리밍 |
| WebRTC | 8189/udp | NLB | Browser (직접) | UDP 미디어 전송 |
| SRT | 8890/udp | VPC only | 카메라 (Tailscale) | 카메라 영상 수신 |

### ICE Candidate 설정

WebRTC 브라우저 연결을 위해 `MTX_WEBRTCADDITIONALHOSTS`에 NLB DNS를 설정해야 함.
NLB는 UDP health check를 지원하지 않으므로 TCP:9997(API 포트)로 대체.

### Tailscale VPN 사이드카 (선택)

`enable_tailscale = true` 시 MediaMTX task에 Tailscale 사이드카 컨테이너 추가:
- 카메라 PC에 Tailscale 설치 → SRT로 MediaMTX에 push
- 포트포워딩/공인 IP 불필요, 암호화 P2P 터널
- `NET_ADMIN` + `NET_RAW` capabilities 필요

---

## 5. Qdrant 벡터 DB 아키텍처

### EFS 영구 저장소

- EFS (elastic throughput, encrypted) → Qdrant `/qdrant/storage` 마운트
- Access Point: UID/GID 1000, path `/qdrant/storage`
- Private subnet별 mount target (Multi-AZ)
- 소규모 벡터(<1M)에서 충분한 성능. 대규모 시 provisioned throughput 고려

---

## 6. VPC 네트워크 설계

```
VPC (10.0.0.0/16)
├── Public Subnet AZ-a  (10.0.1.0/24)   ── ALB, NLB, NAT Gateway
├── Public Subnet AZ-c  (10.0.2.0/24)   ── ALB, NLB (다중 AZ)
├── Private Subnet AZ-a (10.0.10.0/24)  ── ECS, RDS, ElastiCache, EFS
├── Private Subnet AZ-c (10.0.20.0/24)  ── ECS, RDS (다중 AZ), EFS
├── Internet Gateway (public ↔ internet)
└── NAT Gateway (private → internet, 아웃바운드만)
```

### Security Groups

| SG | 인바운드 | 소스 |
|---|---|---|
| ALB | 80, 443/tcp | 0.0.0.0/0 |
| Backend | 8080/tcp | ALB SG |
| Agent Ingest | 아웃바운드만 | - |
| Agent Worker | 아웃바운드만 | - |
| MediaMTX | 9997,8554,8889/tcp + 8890,8189/udp | Backend SG, Agent SG, ALB SG, VPC, 0.0.0.0/0(WebRTC) |
| Qdrant | 6333,6334/tcp | Agent Ingest SG + Agent Worker SG |
| EFS | 2049/tcp | Qdrant SG |
| RDS | 5432/tcp | Backend SG |
| Redis | 6379/tcp | Backend SG + Agent SGs |

### VPC Endpoints (비용 최적화)

- **S3**: Gateway 타입 (무료)
- **ECR API/DKR, SQS, CloudWatch Logs, Secrets Manager**: Interface 타입

---

## 7. CI/CD 파이프라인

### GitHub Actions OIDC 인증

- AWS IAM OIDC Provider로 GitHub Actions에서 직접 AWS 자격 증명 획득
- `github_org` + `github_repos` 변수로 허용 리포지토리 제어
- 시크릿 키 관리 불필요 (OIDC 토큰 기반)

### 인프라 워크플로우

```
terraform/ 수정 → git push → PR 생성
  → GitHub Actions: terraform plan (미리보기)
  → PR 승인 & main 머지
  → GitHub Actions: terraform apply (실제 배포)
```

### 애플리케이션 배포 워크플로우

```
src/ 수정 → git push → GitHub Actions
  → docker build → ECR push → ECS 서비스 업데이트
```

### Dockerfile 스펙

| 서비스 | 베이스 이미지 | 빌드 |
|---|---|---|
| aegis-backend | Java 21 (multi-stage) | Gradle → JRE slim |
| aegis-ai-agent | Python 3.12 | pip + system deps (ffmpeg 등), 단일 이미지 + AGENT_MODE 환경변수로 ingest/worker 분기 |
| aegis-frontend | Node.js → S3 sync | next build → static export |

---

## 8. Terraform 파일 구조

```
terraform-example/
├── MIGRATION_PLAN.md              # 이 문서
├── fargate/                       # Fargate 버전
│   ├── main.tf                    # Provider, Backend 설정
│   ├── variables.tf               # 변수 정의
│   ├── outputs.tf                 # 출력값
│   ├── terraform.tfvars.example   # 변수 예시
│   ├── vpc.tf                     # VPC, 서브넷, IGW, NAT
│   ├── security_groups.tf         # 보안 그룹 (ALB, Backend, Agent, MediaMTX, Qdrant, EFS, RDS, Redis)
│   ├── vpc_endpoints.tf           # VPC 엔드포인트
│   ├── iam.tf                     # IAM 역할/정책 (ECS, GitHub OIDC, MediaMTX)
│   ├── secrets.tf                 # Secrets Manager (DB, JWT, AI Keys, Tailscale)
│   ├── acm.tf                     # SSL 인증서
│   ├── rds.tf                     # PostgreSQL
│   ├── elasticache.tf             # Redis
│   ├── s3.tf                      # S3 버킷 (클립 + 프론트엔드)
│   ├── sqs.tf                     # SQS 큐 + DLQ
│   ├── ecr.tf                     # 컨테이너 레지스트리
│   ├── efs.tf                     # EFS (Qdrant 영구 저장소)
│   ├── service_discovery.tf       # Cloud Map (aegis.local)
│   ├── ecs_cluster.tf             # ECS 클러스터 + 로그 그룹
│   ├── ecs_backend.tf             # Spring Boot 서비스
│   ├── ecs_agent_ingest.tf        # 영상 수집 서비스
│   ├── ecs_agent_worker.tf        # 분석 워커 서비스 + 오토스케일링
│   ├── ecs_mediamtx.tf            # MediaMTX 스트리밍 (+ Tailscale sidecar)
│   ├── ecs_qdrant.tf              # Qdrant 벡터 DB (+ EFS)
│   ├── alb.tf                     # ALB (Backend + WHEP)
│   ├── nlb.tf                     # NLB (WebRTC UDP + SRT)
│   ├── cloudfront.tf              # CDN (S3 + API + Stream + SSE)
│   ├── cloudwatch.tf              # 모니터링 + 알람
│   └── route53.tf                 # DNS (선택)
└── ec2/                           # EC2 버전
    ├── (동일 구조 + EC2 전용 파일)
    ├── launch_template.tf         # EC2 시작 템플릿 + ASG
    └── vpc_endpoints.tf           # VPC 엔드포인트
```

---

## 9. Fargate vs EC2 비교

### ECS Fargate
- **장점**: 서버 관리 불필요, 태스크 단위 세밀한 스케일링, 빠른 시작
- **단점**: EC2 대비 ~1.5배 비용
- **적합**: 초기 구축, 운영 인력 부족, 가변 워크로드

### ECS EC2
- **장점**: 비용 효율적, Reserved Instance 할인
- **단점**: EC2 인스턴스 관리 필요, AMI 업데이트
- **적합**: 안정적 워크로드, 비용 최적화 단계

### 공통
- MediaMTX, Qdrant는 양쪽 모두 **awsvpc** 네트워크 모드 사용 (Cloud Map A 레코드 호환)
- EC2 버전의 Backend, Agent Ingest/Worker는 bridge 모드 (동적 포트 매핑)

### 권장 전략
> Fargate로 시작 → 워크로드 안정화 후 EC2로 전환 검토

---

## 10. 예상 AWS 리소스 수: ~63개

| 카테고리 | 수량 | 주요 항목 |
|---|---|---|
| 네트워크 | ~14 | VPC, 서브넷 4개, IGW, NAT, 라우팅, VPC Endpoints |
| 보안 | ~14 | SG 8개 (ALB, Backend, Agent×2, MediaMTX, Qdrant, EFS, RDS, Redis), IAM 역할 5개 |
| 데이터 | ~6 | RDS, Redis, S3 2개, SQS + DLQ |
| 컨테이너 | ~17 | ECR 2개, 클러스터, Task Def 5개, Service 5개, ASG policies, EFS + mount targets |
| 서비스 디스커버리 | ~4 | Cloud Map namespace, 서비스 등록 3개 |
| 로드밸런서 | ~6 | ALB + TG + listener + rule, NLB + TG + listener |
| 프론트엔드 | ~4 | S3, CloudFront, OAC, CF Function |
| 기타 | ~5 | ACM, Secrets, CloudWatch alarms, Route53 |

### 예상 월간 비용 (최소 구성, 서울 리전)

| 항목 | 예상 비용 |
|---|---|
| ECS Fargate (5 tasks, 0.5~1 vCPU) | ~$80-120 |
| RDS db.t3.micro | ~$15 |
| ElastiCache cache.t3.micro | ~$13 |
| NAT Gateway | ~$35 |
| ALB + NLB | ~$35 |
| S3 + CloudFront | ~$5 |
| VPC Endpoints (Interface×4) | ~$30 |
| EFS (elastic) | ~$5 |
| SQS, CloudWatch, etc. | ~$5 |
| **합계** | **~$220-270/월** |

---

## 11. 핵심 결정사항 요약

| # | 결정 | 이유 |
|---|---|---|
| 1 | ECS Fargate/EC2 | Lambda 부적합 (always-on), EKS 과도 |
| 2 | SQS Standard Queue | FIFO 불필요 (윈도우 태스크 독립 분석) |
| 3 | MediaMTX ECS 배포 | NLB(WebRTC UDP) + ALB(WHEP HTTP) dual LB |
| 4 | Qdrant ECS + EFS | 영구 벡터 저장소, 관리형 대안 없음 |
| 5 | Cloud Map | VPC 내부 서비스 간 DNS 기반 통신 |
| 6 | Tailscale VPN | 카메라 연결, 포트포워딩/공인 IP 불필요 |
| 7 | GitHub Actions OIDC | repo 목록 기반 접근 제어, 시크릿 키 불필요 |
| 8 | AI Agent 단일 ECR 이미지 | 하나의 Dockerfile, ECS 태스크에서 `AGENT_MODE=ingest/worker`로 역할 분기 |
| 9 | 환경 비종속적 코드 | dev/main 동일, env var로 로컬/AWS 분기 |
| 10 | Terraform 별도 repo | aegis-terraform으로 인프라 코드 분리 |
| 11 | ap-northeast-2 (서울) | 대상 사용자 위치 |
| 12 | VPC Endpoints | NAT Gateway GB당 과금 회피 |

---

## 12. 주의사항

| 주제 | 상세 |
|------|------|
| **MediaMTX ICE** | `MTX_WEBRTCADDITIONALHOSTS`에 NLB DNS 필수. 브라우저 WebRTC 연결에 필요 |
| **NLB UDP Health** | UDP 직접 health check 불가 → TCP:9997로 대체 |
| **EFS 성능** | 소규모 벡터(<1M)에서 충분. 대규모 시 provisioned throughput 고려 |
| **Tailscale 키** | OAuth client credentials 권장 (만료 없음) |
| **EC2 awsvpc** | MediaMTX/Qdrant는 EC2에서도 awsvpc 모드 사용 (Cloud Map A 레코드 호환) |

---

## 13. 수동 작업 목록 (사용자)

### Terraform 실행 전 (1회)

1. AWS 계정/CLI 설정 (`aws configure`)
2. S3 버킷 `aegis-terraform-state` + DynamoDB `aegis-terraform-lock` 수동 생성
3. `terraform.tfvars.example` → `terraform.tfvars` 복사 후 값 입력
4. GitHub에 `aegis-terraform` repo 생성

### Terraform 실행 후 (1회)

5. Secrets Manager에 `ai-api-keys` 값 입력 (OpenAI API 키 등)
6. Tailscale: 계정 생성 → auth key 발급 → Secrets Manager에 저장 → 카메라 PC 설치
7. GitHub repo별 Secrets 설정 (`AWS_ROLE_ARN`, `S3_FRONTEND_BUCKET`, `CLOUDFRONT_DISTRIBUTION_ID`)
8. 도메인 설정 (선택)

---

## 14. TODO: Multi-AZ 고가용성

현재 비용 절감을 위해 일부 리소스가 Single-AZ:

| 리소스 | Multi-AZ | 현재 상태 |
|---|---|---|
| VPC 서브넷 | O | 2a, 2c 각각 public/private |
| ALB / NLB | O | public 서브넷 2개에 걸쳐 배포 |
| ECS 서비스 | O | private 서브넷 전체에 분산 |
| EFS | O | private subnet별 mount target |
| S3 / SQS / CloudFront | O | 리전 서비스 (자동 Multi-AZ) |
| **NAT Gateway** | **X** | Single-AZ (2AZ 전환 필요) |
| **RDS PostgreSQL** | **X** | Single-AZ (multi_az = false) |
| **ElastiCache Redis** | **X** | Single-AZ (노드 1개) |

---

## 15. 이후 별도 진행 (서비스 repo)

서비스 repo 코드 변경은 각 repo의 git 상태 정리 후 별도 진행:

### Spring Boot Backend 코드 변경
- `application.properties`: 이미 `${ENV_VAR:default}` 패턴 사용 중 → 코드 변경 최소
- 환경변수 매핑 (ECS task definition에서 주입):
  - `DB_URL` → RDS endpoint (`jdbc:postgresql://aegis-postgres.xxx.rds.amazonaws.com:5432/aegis`)
  - `DB_USERNAME`, `DB_PASSWORD` → Secrets Manager
  - `REDIS_HOST` → ElastiCache endpoint
  - `AWS_S3_BUCKET` → `aegis-clips-676323537989`
  - `AWS_S3_ENDPOINT` → 빈 값 (AWS S3 네이티브 사용, MinIO endpoint 불필요)
  - `AWS_S3_ACCESS_KEY`, `AWS_S3_SECRET_KEY` → ECS Task Role로 대체 (IAM 인증)
  - `MEDIAMTX_API_URL` → `http://mediamtx.aegis.local:9997` (Cloud Map)
  - `CORS_ALLOWED_ORIGINS` → CloudFront 도메인
  - `JWT_SECRET` → Secrets Manager
- S3 클라이언트: MinIO 호환 → AWS S3 네이티브 전환 (endpoint 제거, IAM 인증)

### Next.js Frontend 코드 변경
- 배포 방식: S3 정적 호스팅 + CloudFront CDN (SSR 미사용)
- API 호출: 이미 상대경로 `/api/...` 사용 → CloudFront가 ALB로 라우팅하므로 코드 변경 없음
- SSE: `/api/notifications/stream` → CloudFront SSE 경로로 라우팅 (Terraform에서 설정 완료)
- 스트리밍: MediaMTX WHEP → CloudFront `/stream/*` 경로로 라우팅
- `next.config.js`: `output: 'export'` 설정 추가 (정적 빌드)
- 빌드: `next build` → S3 sync → CloudFront invalidation

### AI Agent 코드 변경
- `config.py`: 모든 하드코딩 → `os.getenv('KEY', 'default')` 패턴
- `queue_adapter.py` (신규): LocalQueueAdapter / SQSQueueAdapter
- `app.py`: `AGENT_MODE` 환경변수로 ingest/worker/all 모드 분리
- Terraform에 `AGENT_MODE` 환경변수 추가 (ingest: Producer만, worker: Consumer만)

### Dockerfiles
- `aegis-backend/Dockerfile`: Multi-stage Java 21 빌드 (Gradle → JRE slim)
- `aegis-ai-agent/Dockerfile`: Python 3.12 + system deps (ffmpeg 등)

### GitHub Actions Workflows
- `aegis-backend/.github/workflows/deploy.yml`: Docker build → ECR push → ECS 서비스 업데이트
- `aegis-ai-agent/.github/workflows/deploy.yml`: Docker build → ECR push → ECS 서비스 업데이트
- `aegis-frontend/.github/workflows/deploy.yml`: next build → S3 sync → CloudFront invalidation
