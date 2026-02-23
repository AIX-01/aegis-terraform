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
