# DDL (실행 가능한 SQL)

> 상태: 초안 · 갱신: 2026-10-21 · 관련: [erd/](../erd/README.md), [db-conventions.md](../db-conventions.md)

[ERD 문서](../erd/README.md)를 실제 SQL Server 2025에서 실행할 수 있는 스크립트로 옮긴 것입니다. ERD는 구조를 **보여주고**, DDL은 타입, 기본값, CHECK, 필터링된 인덱스, 임시 테이블, DB 권한까지 **정확하게 정의**합니다.

## 파일

| 파일 | 내용 | ERD |
|---|---|---|
| [00-schemas.sql](00-schemas.sql) | 스키마 8개 | |
| [01-iam.sql](01-iam.sql) | 계정, MFA, 세션, 역할과 역할 부여, 조직 프로젝션 | [identity.md](../erd/identity.md) |
| [02-hr.sql](02-hr.sql) | 조직, 소속, 조직개편, 직원과 부속 정보 | [hr.md](../erd/hr.md) |
| [03-projects.sql](03-projects.sql) | 거래처, 계약, 프로젝트, 일정, 투입 | [projects.md](../erd/projects.md) |
| [04-accounting.sql](04-accounting.sql) | 회계, 클라우드 비용 | [accounting.md](../erd/accounting.md) |
| [05-platform.sql](05-platform.sql) | platform, audit, ai, outbox | [platform.md](../erd/platform.md) |
| [99-security.sql](99-security.sql) | DB 역할과 권한 (감사 로그는 추가만 가능) | |
| [tests/constraint-checks.sql](tests/constraint-checks.sql) | 제약조건이 잘못된 데이터를 거부하는지 확인 (24개 항목) | |

**파일 이름 순서대로 실행합니다.** 각 파일 앞머리에서 `QUOTED_IDENTIFIER`와 `ANSI_NULLS`를 켭니다. sqlcmd의 기본값은 `QUOTED_IDENTIFIER OFF`인데, 이 상태에서는 필터링된 인덱스를 만들 수 없기 때문입니다.

## 검증 방법

Docker가 있으면 아래 명령 하나로 검증합니다.

```powershell
./tools/ddl/Test-Ddl.ps1                  # 검증 후 컨테이너 삭제
./tools/ddl/Test-Ddl.ps1 -KeepContainer   # 컨테이너를 남겨 두고 직접 조회
```

[Test-Ddl.ps1](../../../tools/ddl/Test-Ddl.ps1)이 하는 일은 다음과 같습니다.

1. `mcr.microsoft.com/mssql/server:2025-latest` 컨테이너를 새로 띄웁니다. 포트는 외부에 열지 않습니다.
2. 빈 DB(`Korean_100_CI_AS_SC_UTF8` 정렬)를 만들고 DDL을 순서대로 실행합니다.
3. `tests/*.sql`을 실행합니다.
4. ERD 문서의 테이블·컬럼과 DDL을 대조합니다. 하나라도 다르면 실패합니다.

**DDL이나 ERD를 고쳤다면 이 스크립트를 반드시 통과시킵니다.** 마지막 확인: 2026-10-21, SQL Server 2025 (17.0.5015.4), 69개 테이블과 24개 제약조건 테스트 통과

## 작성 규칙

- **공통 컬럼:** 다이어그램에서는 생략하지만, DDL에는 모두 적습니다.

  | 테이블 종류 | 공통 컬럼 |
  |---|---|
  | 수정 가능한 엔티티 | `CreatedAt`, `CreatedBy`, `UpdatedAt`, `UpdatedBy`, `RowVersion` |
  | 연결 테이블, 추가만 하는 테이블 | `CreatedAt`, `CreatedBy` |
  | 감사 로그 | `OccurredAt` 하나 |

- **임시 테이블:** 기간 컬럼은 `PeriodStart`와 `PeriodEnd`, 이력 테이블은 `{Table}History`로 이름 짓습니다. EF Core의 `IsTemporal()` 기본값과 같습니다.
- **제약조건 이름:** `PK_`, `FK_{Table}_{RefTable}_{Column}`, `UX_`, `IX_`, `CK_`, `DF_`. FK 이름은 EF Core 기본 규칙과 같습니다.
- **enum 컬럼:** 허용 값을 CHECK로 고정합니다. 구현할 때 EF Core의 `HasCheckConstraint`로 같은 제약을 만듭니다.
- **기본키 값:** GUID는 애플리케이션(EF Core)이 만들기 때문에 DB 기본값을 두지 않습니다.
- **T-SQL 예약어를 피합니다.** 실제로 피한 예:
  - 스키마 `identity` → `iam`
  - 컬럼 `LineNo` → `LineNumber`

## SQL Server 2025 기능 사용처

| 기능 | 사용처 |
|---|---|
| `json` 타입 | 조직개편 항목, 감사 변경 내역, Outbox 페이로드, 클라우드 태그, 시스템 설정 |
| `vector(n)` 타입, `VECTOR_DISTANCE` | `ai.DocumentChunks` (RAG). 차원 1024는 가정이며, 임베딩 모델을 정한 뒤 확정합니다 |
| `hierarchyid` | `hr.OrgUnits`, `iam.OrgUnits` |
| 시스템 버전 임시 테이블 | 계약, 직원, 조직, 단가, 역할 부여 등 이력이 중요한 테이블 |
| 필터링된 유니크 인덱스 | 현재 주 소속 하나, 현재 조직장 한 명, 루트 조직 하나, 멱등 키 |

## 구현 이후

EF Core 마이그레이션이 만들어지면 원본은 마이그레이션이 됩니다. 그때 이 폴더는 다음 방식으로 바꿉니다.

- `dotnet ef migrations script --idempotent`로 모듈별 SQL을 **생성**하는 방식으로 전환합니다.
- `tests/`의 제약조건 테스트는 그대로 유지합니다. 마이그레이션이 같은 제약을 만들었는지 확인하는 회귀 테스트로 씁니다.
