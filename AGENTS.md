# Synthetix — 에이전트 작업 가이드

Synthetix는 SI/SM 기업을 위한 **설치형 ERP**입니다.
프로젝트·계약 관리, 인사(계약직·파견 포함), 회계(클라우드 비용 포함)를 하나로 묶고, 업무 흐름 전반에 **로컬 LLM 기반 AI**를 적용합니다.

> **현재 단계: 설계.** 아직 코드가 없습니다. 설계 지식은 모두 [`docs/`](docs/README.md)에 있습니다.

## 반드시 지킬 규칙

1. **docs가 기준입니다.** 작업 전에 아래 "작업별 필독 문서"를 읽습니다. 설계와 다르게 구현해야 하면 **문서를 먼저 고치고**, 중요한 결정은 [ADR](docs/adr/README.md)로 남깁니다.
2. **LLM 호출은 AI Gateway(`Synthetix.Modules.AI`)로만 합니다.** 다른 모듈에서 LLM SDK나 HTTP를 직접 호출하지 않습니다. → [ai-gateway.md](docs/04-ai/ai-gateway.md)
3. **민감정보를 원문으로 남기지 않습니다.** 비밀번호, OTP, 토큰, 주민등록번호, 계좌번호 등은 로그·예외 메시지·AI 프롬프트에 원문으로 들어가면 안 됩니다. → [data-protection.md](docs/03-security/data-protection.md)
4. **모듈 경계를 지킵니다.** 다른 모듈은 `Synthetix.Modules.{Name}.Public`만 참조합니다. 다른 모듈의 Domain, DbContext, 테이블에는 직접 접근하지 않습니다. → [solution-structure.md](docs/01-architecture/solution-structure.md)
5. **클라이언트와 서버가 함께 쓰는 DTO는 `Synthetix.Contracts`에만 둡니다.** JSON 직렬화는 source-generated `JsonSerializerContext`를 씁니다(WASM 트리밍 대응).
6. **시간은 `TimeProvider`를 주입받아 씁니다.** `DateTime.Now`와 `DateTime.UtcNow`를 직접 호출하지 않습니다.
7. **상용 라이선스로 바뀐 라이브러리를 들이지 않습니다.** 예: MediatR, AutoMapper, FluentAssertions. → [tech-stack.md](docs/01-architecture/tech-stack.md)
8. **언어 규칙:** 문서와 주석은 한국어, 코드 식별자와 커밋 메시지는 영어로 씁니다. 업무 용어의 영문 이름은 [glossary.md](docs/00-overview/glossary.md)를 따릅니다.
9. **미결 사항 확인:** [open-questions.md](docs/00-overview/open-questions.md)에 있는 "가정"은 사용자 확인 없이 확정 처리하지 않습니다.

## 작업별 필독 문서

| 작업 | 읽을 문서 |
|---|---|
| 어떤 작업이든 처음 | [docs/README.md](docs/README.md), [glossary.md](docs/00-overview/glossary.md) |
| 솔루션·프로젝트 구조 | [solution-structure.md](docs/01-architecture/solution-structure.md), [tech-stack.md](docs/01-architecture/tech-stack.md), [coding.md](docs/conventions/coding.md) |
| 로그인·인증 | [authentication.md](docs/03-security/authentication.md) |
| 권한·접근제어·조직 | [authorization.md](docs/03-security/authorization.md), [organization.md](docs/02-domain/organization.md), [ADR-0007](docs/adr/0007-org-based-access-control.md) |
| 업무 기능 | [docs/02-domain/](docs/02-domain/) 아래 해당 모듈 문서, [api-conventions.md](docs/05-api/api-conventions.md) |
| DB·엔티티·마이그레이션 | [db-conventions.md](docs/06-data/db-conventions.md), [docs/06-data/erd/](docs/06-data/erd/README.md)와 [docs/06-data/ddl/](docs/06-data/ddl/README.md)의 해당 스키마. ERD나 DDL을 고치면 `tools/ddl/Test-Ddl.ps1`을 통과시킵니다 |
| AI 기능 | [ai-gateway.md](docs/04-ai/ai-gateway.md), [deidentification.md](docs/04-ai/deidentification.md), [use-cases.md](docs/04-ai/use-cases.md) |
| 클라이언트 UI | [avalonia-conventions.md](docs/07-client/avalonia-conventions.md) |
| 배포·업데이트 | [deployment.md](docs/01-architecture/deployment.md), [client-update.md](docs/01-architecture/client-update.md) |
| 테스트 | [testing.md](docs/conventions/testing.md) |

## 빌드·실행 명령

구현을 시작한 뒤에 추가합니다.
