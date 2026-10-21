# 테스트 규칙

> 상태: 초안 · 갱신: 2026-10-21 · 도구: [tech-stack.md](../01-architecture/tech-stack.md)

## 테스트 종류

| 종류 | 위치 | 대상 | CI |
|---|---|---|---|
| 단위 | `tests/Synthetix.Modules.{Name}.Tests` | 도메인 규칙, 값 객체, 핸들러 (DB 없이) | 항상 |
| 통합 | `tests/Synthetix.Server.IntegrationTests` | HTTP → DB 전체 흐름, 권한, 데이터 범위 | 항상 (Testcontainers SQL Server) |
| 아키텍처 | `tests/Synthetix.ArchitectureTests` | 모듈 경계, 참조 규칙, 금지 API, 데이터 분류 누락 | 항상 |
| 클라이언트 | `tests/Synthetix.Client.Tests` | ViewModel, 화면 흐름 (Avalonia.Headless) | 항상 |
| DB 스키마 | `docs/06-data/ddl/tests` + `tools/ddl/Test-Ddl.ps1` | DDL 실행, 제약조건 동작, ERD 대조 | DDL·ERD 변경 시 (Docker 필요) |
| AI 평가 | `tests/Synthetix.AI.Evals` | 추출 정확도, 비식별화 재현율 | 수동 실행, 또는 모델·프롬프트 변경 시 |

## 이름 규칙

- 테스트 클래스: `{대상}Tests`
- 테스트 메서드: `{메서드또는상황}_{조건}_{기대결과}`
  - 예: `Verify_WhenCodeReused_ReturnsInvalidCode`

## 반드시 테스트할 것

- **인증**
  - TOTP 시간 경계(앞뒤 주기)
  - 같은 코드 재사용 거부
  - mfaToken 만료와 시도 횟수 초과
  - refresh 회전과 재사용 탐지
  - 계정 잠금
  - 시간은 `FakeTimeProvider`로 조작합니다.
- **권한**
  - 엔드포인트마다 권한 없는 사용자는 403
  - 데이터 범위 밖의 리소스는 404
  - **엔드포인트가 새로 추가됐는데 권한 지정이 빠졌으면 실패하는 테스트**를 둡니다 (모든 엔드포인트의 메타데이터를 검사).
  - 유효 권한 계산기: 조직 상속, 겸직, 조직장 부여, 예외, 기간 만료, 범위 합산의 조합 (표 기반 테스트)
  - 조직 변경 이벤트를 받은 뒤 권한 캐시가 무효화되는지
- **민감정보**
  - 응답 DTO에서 `Restricted` 필드가 가려지는지
  - 로그에 민감정보가 원문으로 나오지 않는지
- **AI**
  - 비식별화 탐지기 단위 테스트
  - 외부 공급자 차단 정책
  - 비식별화가 실패하면 요청이 차단되는지
- **도메인**
  - 전표의 차변과 대변 합계 일치
  - M/M 계산
  - 계약 만료 규칙 (HR-R01~R04)

## 테스트 데이터

- 모두 가상 데이터입니다. 주민번호처럼 보이는 값도 실제로 존재할 수 없는 값으로 만듭니다.
- 테스트 데이터를 만드는 빌더(`EmployeeBuilder`, `ContractBuilder`)는 모듈 테스트 프로젝트에 둡니다.
- 통합 테스트는 테스트마다 DB를 초기화합니다(Respawn 같은 도구를 검토). 테스트끼리 서로 영향을 주지 않게 합니다.
