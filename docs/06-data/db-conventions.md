# 데이터베이스 규칙

> 상태: 초안 · 갱신: 2026-10-21 · 테이블 설계: [erd/](erd/README.md) · DDL: [ddl/](ddl/README.md)

## 구조

- DB는 하나이고, **모듈마다 스키마**를 나눕니다: `iam`(Identity 모듈), `hr`, `projects`, `accounting`, `platform`, `ai`, `audit`
  - Identity 모듈의 스키마가 `identity`가 아닌 이유: `IDENTITY`는 T-SQL 예약어라서 SQL을 쓸 때마다 대괄호로 감싸야 합니다.
  - 공통 인프라용 스키마도 둡니다: `outbox`, `hangfire`
- 모듈마다 DbContext가 하나 있고, `HasDefaultSchema("{module}")`로 기본 스키마를 지정합니다.
- **다른 모듈의 스키마는 읽지도 쓰지도 않습니다.** 외래키도 모듈 안에서만 겁니다. 다른 모듈의 ID는 외래키 없이 값으로만 저장합니다.

## 이름 규칙

| 대상 | 규칙 | 예 |
|---|---|---|
| 테이블 | PascalCase 복수형 | `projects.Contracts` |
| 컬럼 | PascalCase | `StartDate` |
| 기본키 | `Id` | |
| 외래키 컬럼 | `{Entity}Id` | `ClientId` |
| 인덱스 | `IX_{Table}_{Columns}` | |
| 유니크 인덱스 | `UX_{Table}_{Columns}` | |

## 키

- 기본키는 `uniqueidentifier`입니다. 값은 **EF Core의 기본 생성기**(SQL Server에 맞춘 순차 GUID)로 만듭니다.
  - `Guid.CreateVersion7()`은 쓰지 않습니다. SQL Server는 `uniqueidentifier`를 바이트 순서가 다르게 정렬하기 때문에, v7 GUID를 써도 순차 삽입 효과가 없습니다.
- 사람이 읽는 코드(`PRJ-2026-0007`)는 따로 유니크 컬럼을 두고, 연도별 시퀀스로 만듭니다.
- **예외:** 대용량으로 추가만 하는 테이블(`audit.*`, `accounting.CloudCostRecords`)은 `bigint identity`를 씁니다.

## 공통 컬럼

| 컬럼 | 설명 |
|---|---|
| `CreatedAt`, `CreatedBy`, `UpdatedAt`, `UpdatedBy` | SaveChanges 인터셉터가 자동으로 채웁니다. 시각은 UTC `datetimeoffset` |
| `RowVersion` | `rowversion`. 동시성 검사와 ETag에 씁니다 |
| `IsDeleted` | 마스터 데이터(고객사, 직원 등)에만 씁니다 (소프트 삭제). 거래 데이터는 상태값으로 관리합니다 |

## 이력 관리

- 변경 이력이 중요한 테이블(계약, 직원, 단가, 역할과 권한)은 SQL Server **시스템 버전 임시 테이블**(Temporal Table)로 만듭니다. EF Core의 `IsTemporal()`을 씁니다.
- "누가 바꿨는가"는 감사 로그(`audit`)에 남깁니다. 임시 테이블은 "어느 시점에 값이 무엇이었는가"를 조회하는 데 씁니다.

## 타입

| 데이터 | SQL 타입 |
|---|---|
| 문자열 | `nvarchar(n)`. 길이를 꼭 정합니다. `max`는 본문 같은 긴 텍스트에만 씁니다 |
| 금액 | `decimal(19,4)` |
| 비율 | `decimal(5,4)` |
| 업무 날짜 | `date` (`DateOnly`) |
| 시각 | `datetimeoffset` |
| enum | `nvarchar` 문자열로 저장합니다(가독성과 안전성) |
| 암호화 필드 | `varbinary` + 블라인드 인덱스 `binary(32)` |
| 임베딩 | `vector(n)` (SQL Server 2025) |
| 트리 계층 (조직) | `hierarchyid` (EF Core HierarchyId 패키지). 하위 조직 조회에 `IsDescendantOf`를 씁니다 |

## 마이그레이션

- 마이그레이션은 모듈별로 각 모듈의 `Infrastructure/Migrations` 폴더에 둡니다.
- 마이그레이션 이름은 PascalCase로, 무엇을 바꾸는지 드러나게 짓습니다: `AddContractWarrantyMonths`
- 배포할 때는 EF Core 마이그레이션 번들로 적용합니다. 앱이 시작될 때 자동으로 적용하지 않습니다.
- 데이터를 잃을 수 있는 변경(컬럼 삭제, 타입 축소)은 두 번의 릴리스로 나눕니다. 먼저 사용을 멈추고, 다음 릴리스에서 삭제합니다. N-1 클라이언트 호환을 위해서입니다.

## 성능

- 목록 조회는 프로젝션(`Select`)으로 필요한 컬럼만 가져오고, `AsNoTracking`을 씁니다.
- N+1 쿼리를 피합니다. 통합 테스트에서 쿼리 수를 확인하는 도우미를 만들어 씁니다.
- 큰 집계(손익, 클라우드 비용)는 미리 계산해 둔 테이블이나 인덱스가 걸린 View를 검토합니다.
- "현재 유효한 것은 하나뿐" 같은 규칙(현재 주 소속, 현재 조직장)은 **필터링된 유니크 인덱스**(`WHERE EndDate IS NULL`)로 DB에서도 보장합니다.
