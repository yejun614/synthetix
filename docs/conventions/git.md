# Git 규칙

> 상태: 초안 · 갱신: 2026-10-21

## 브랜치

| 브랜치 | 역할 | 들어오는 방법 |
|---|---|---|
| `develop` | **기본 브랜치.** 다음 릴리스를 모으는 통합 브랜치입니다 | 작업 브랜치에서 PR (Squash merge) |
| `main` | 릴리스된 코드만 있습니다. 릴리스 태그는 여기에 답니다 | `develop` 또는 `hotfix/*`에서 PR (Merge commit) |
| `{type}/{짧은-설명}` | 작업 브랜치. 예: `feat/auth-totp`, `fix/refresh-race`, `docs/ai-gateway` | `develop`에서 만듭니다 |
| `hotfix/{설명}` | 운영 중 긴급 수정 | `main`에서 만들고, `main`과 `develop` 양쪽에 PR로 합칩니다 |

- `main`과 `develop`은 **보호 브랜치**입니다.
  - 직접 푸시, 강제 푸시, 삭제가 금지됩니다.
  - 관리자도 예외가 아닙니다. 반드시 PR로만 합칩니다.
  - 혼자 개발하므로 리뷰 승인 수는 0으로 둡니다. CI가 생기면 "상태 검사 통과"를 필수 조건에 추가합니다.
- 두 브랜치 모두 항상 빌드와 테스트가 통과하는 상태를 유지합니다.
- 혼자 개발하더라도 PR을 남겨 설계 의도를 기록합니다. 머지한 작업 브랜치는 지웁니다.

## 커밋 메시지 (Conventional Commits, 영어)

```
{type}({scope}): {요약, 명령형, 소문자로 시작}

{본문: 무엇을, 왜 바꿨는지}
```

- `type`: `feat`, `fix`, `refactor`, `test`, `docs`, `build`, `ci`, `chore`, `perf`
- `scope`: 모듈 이름이나 영역. `identity`, `projects`, `hr`, `accounting`, `ai`, `client`, `infra`, `docs`
- 예: `feat(identity): add totp replay protection`

## PR

- 제목은 커밋 규칙과 같습니다.
- 본문에는 다음을 적습니다.
  - 무엇을 왜 바꿨는지
  - 관련 문서와 ADR
  - 어떻게 테스트했는지
  - 스크린샷 (UI가 바뀐 경우)
- 설계가 바뀌었다면 **같은 PR 안에서 `docs/`도 갱신**합니다.

## 버전과 태그

- SemVer를 씁니다. 서버와 클라이언트는 같은 버전 번호로 함께 릴리스합니다 ([client-update.md](../01-architecture/client-update.md)).
- 릴리스 태그 형식은 `v{major}.{minor}.{patch}`입니다. `develop`을 `main`에 합친 뒤 `main`에 태그를 달면 릴리스 파이프라인이 실행됩니다.

## 저장소에 넣지 않는 것

- 비밀 값: 연결 문자열 비밀번호, 키, 인증서
- 실제 개인정보, 실제 계약서. 테스트와 평가 데이터는 모두 가상 데이터로 만듭니다.
- 빌드 결과물, 로컬 설정(`appsettings.Development.local.json` 등)
