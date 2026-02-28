# AEGIS Infrastructure Issues

배포 및 운영 중 발견된 이슈와 해결 기록.

---

## Issue #1: CloudFront 무한 새로고침 (2026-02-23)

### 증상
- `https://d32tvhj9tbkse8.cloudfront.net` 접속 시 페이지가 무한 새로고침
- 브라우저가 `/auth` → `/` → `/auth` 반복

### 원인
CloudFront Function(`aegis-spa-rewrite`)이 **전통 SPA 방식**으로 작성되어 모든 비파일 경로를 `/index.html`(루트)로 리라이트.

```javascript
// 기존 (잘못된 코드)
request.uri = '/index.html';  // 항상 루트 index.html
```

Next.js `output: 'export'` + `trailingSlash: true`는 **경로별 index.html**을 생성하므로:
- `/auth` 요청 → `/index.html`(루트 대시보드) 서빙 → 인증 없음 → `/auth`로 리다이렉트 → 루프

### 해결
`fargate/cloudfront.tf`의 SPA rewrite 함수를 각 경로의 `index.html`로 매핑하도록 수정.

```javascript
// 수정 후
if (uri.endsWith('/')) {
  request.uri = uri + 'index.html';     // /auth/ → /auth/index.html
} else {
  request.uri = uri + '/index.html';    // /auth → /auth/index.html
}
```

### 적용
- 커밋: `bd28bfd` (main)
- 적용: 로컬 `terraform apply` (GitHub Actions OIDC 실패로 인해)

---

## Issue #2: GitHub Actions OIDC 인증 실패 (미해결)

### 증상
- `aegis-terraform` repo에 push → GitHub Actions에서 `terraform apply` 실행 시 실패
- 에러: `Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity`

### 원인 (추정)
IAM Role(`aegis-github-actions-role`)의 trust policy에서 `aegis-terraform` 레포가 허용 목록에 없을 가능성.

### 영향
- `aegis-terraform` repo push 시 자동 `terraform apply` 불가
- 현재 로컬에서 수동 `terraform apply`로 우회 중
- 다른 레포(aegis-backend, aegis-frontend, aegis-ai-agent)의 deploy.yml은 정상 동작

### 조치 필요
1. IAM Role trust policy 확인: `repo:AIX-01/aegis-terraform:*` 조건 존재 여부
2. 없으면 `fargate/iam.tf`의 OIDC trust policy에 `aegis-terraform` 추가
3. `terraform apply` 후 재테스트

### 참고
```bash
# trust policy 확인 명령
aws iam get-role --role-name aegis-github-actions-role --query "Role.AssumeRolePolicyDocument"
```

---

## Issue #3: `ec2/**` 변경 시에도 `fargate`만 실행됨

### 상태
- 현재는 EC2 기반 배포를 실행하지 않았으므로 즉시 장애는 아님.
- 다만 `.github/workflows/terraform.yml`은 `ec2/**` 변경도 트리거하면서 실제 실행 디렉터리는 `WORKING_DIR: "fargate"`로 고정되어 있음.

### 영향 (EC2 도입 시)
- `ec2/**` 변경 PR/Push에서도 `ec2` plan/apply가 수행되지 않음.
- 실제로는 `fargate`만 검증/적용되어 변경 누락 위험이 생김.

### 해결 방향
1. 변경 경로 감지 단계 추가 (`dorny/paths-filter` 권장)
2. plan/apply를 스택별(`fargate`, `ec2`)로 분기 실행
3. 각 잡의 `working-directory`를 고정값 대신 스택 값으로 설정

### 구현 옵션
- 옵션 A: 스택별 잡 2개 (`plan-fargate`, `plan-ec2`, `apply-fargate`, `apply-ec2`)
  - 장점: 단순하고 디버깅이 쉬움
  - 단점: YAML 중복 증가
- 옵션 B: matrix + 경로 조건
  - 장점: 중복이 적고 확장에 유리
  - 단점: 조건식이 복잡해질 수 있음

### 권장안
- 현재 단계: 그대로 유지 (EC2 미사용)
- EC2 도입 시점: `paths-filter + matrix`로 전환

### 참고
- 이 내용은 인프라 워크플로우 운영 이슈이므로 `AGENTS.md`보다 프로젝트 문서(`ISSUES.md`)에 기록하는 것이 적절함.
