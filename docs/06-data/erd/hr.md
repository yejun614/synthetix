# ERD: hr

> 상태: 초안 · 갱신: 2026-10-21 · 업무 규칙: [organization.md](../../02-domain/organization.md), [hr.md](../../02-domain/hr.md) · DDL: [02-hr.sql](../ddl/02-hr.sql)

## 조직

```mermaid
erDiagram
    OrgUnits ||--o{ OrgUnits : "ParentId"
    OrgUnits ||--o{ OrgMemberships : ""
    Employees ||--|{ OrgMemberships : ""
    OrgChangePlans ||--|{ OrgChangeItems : ""

    OrgUnits {
        uniqueidentifier Id PK
        nvarchar Code UK "20, 변경 불가"
        nvarchar Name "100"
        nvarchar Type "Company, Division, Department, Team"
        uniqueidentifier ParentId FK "null은 루트만"
        hierarchyid Node UK
        int SortOrder
        nvarchar Status "Active, Closed"
        date ClosedDate "null"
    }
    OrgMemberships {
        uniqueidentifier Id PK
        uniqueidentifier EmployeeId FK
        uniqueidentifier OrgUnitId FK
        bit IsPrimary
        nvarchar JobTitleCode "null, → platform.CommonCodes"
        bit IsHead
        date StartDate
        date EndDate "null이면 현재 소속"
    }
    OrgChangePlans {
        uniqueidentifier Id PK
        nvarchar Title "200"
        date EffectiveDate
        nvarchar Status "Draft, Scheduled, Applied, Cancelled, Failed"
        datetimeoffset AppliedAt "null"
        nvarchar FailureReason "null"
    }
    OrgChangeItems {
        uniqueidentifier Id PK
        uniqueidentifier PlanId FK
        int Seq
        nvarchar ItemType "CreateUnit, RenameUnit, MoveUnit, CloseUnit, MoveMember, AddConcurrent, EndConcurrent, SetHead, UnsetHead"
        uniqueidentifier TargetUnitId "null"
        uniqueidentifier TargetEmployeeId "null"
        nvarchar Payload "JSON, 항목별 매개변수"
    }
```

## 직원

```mermaid
erDiagram
    Employees ||--o{ EmploymentContracts : ""
    EmploymentContracts |o--o| EmploymentContracts : "RenewalOfId"
    Employees ||--o| DispatchInfos : ""
    Employees ||--o{ EmployeeSkills : ""
    Employees ||--o{ CareerHistories : ""
    Employees ||--o{ CostRates : ""
    Employees ||--o{ ExpiryAlerts : ""

    Employees {
        uniqueidentifier Id PK
        nvarchar EmployeeNumber UK "20"
        nvarchar Name "50, Confidential"
        nvarchar Email "200, Confidential"
        nvarchar Phone "20, Confidential"
        nvarchar JobGradeCode "→ platform.CommonCodes"
        nvarchar EmploymentType "Regular, FixedTerm, Dispatched, Freelancer, PartnerStaff"
        uniqueidentifier PartnerId "null, → projects.Partners"
        date HireDate
        date TerminationDate "null"
        nvarchar Status "Active, OnLeave, Terminated"
        varbinary RrnEncrypted "null, Restricted"
        binary RrnBlindIndex "null, 32"
        varbinary BankAccountEncrypted "null, Restricted"
        bit IsDeleted
    }
    EmploymentContracts {
        uniqueidentifier Id PK
        uniqueidentifier EmployeeId FK
        nvarchar ContractType "Regular, FixedTerm, Freelance"
        date StartDate
        date EndDate "null"
        uniqueidentifier RenewalOfId FK "null, 갱신 이전 계약"
        uniqueidentifier FileId "null, → platform.Files"
    }
    DispatchInfos {
        uniqueidentifier EmployeeId PK, FK
        uniqueidentifier DispatchAgencyId "→ projects.Partners"
        nvarchar JobCategory "파견 허용 업무"
        date StartDate
        date PlannedEndDate
        date ExtendedEndDate "null"
    }
    EmployeeSkills {
        uniqueidentifier EmployeeId PK, FK
        nvarchar SkillCode PK "→ platform.CommonCodes"
        tinyint Proficiency "1~5"
        decimal Years "4,1"
    }
    CareerHistories {
        uniqueidentifier Id PK
        uniqueidentifier EmployeeId FK
        nvarchar ProjectName "200"
        nvarchar ClientName "200"
        nvarchar Role "50"
        date StartDate
        date EndDate "null"
        nvarchar Description "max"
        nvarchar Source "Manual, AiExtracted"
    }
    CostRates {
        uniqueidentifier Id PK
        uniqueidentifier EmployeeId FK
        decimal MonthlyRate "19,4, Confidential"
        nvarchar Currency "3"
        date ValidFrom
        date ValidTo "null"
    }
    ExpiryAlerts {
        uniqueidentifier Id PK
        uniqueidentifier EmployeeId FK
        nvarchar RuleId "HR-R01 ~ HR-R04"
        date DueDate "만료일 또는 제한 도달일"
        int StageDays "90, 60, 30, 14, 0"
        nvarchar Status "Open, Acknowledged, Resolved"
    }
```

## 제약조건과 인덱스

| 테이블 | 내용 |
|---|---|
| `OrgUnits` | `UX(Code)`, `UX(Node)`, `UX(ParentId) WHERE ParentId IS NULL` (루트는 하나뿐) |
| `OrgMemberships` | `UX(EmployeeId) WHERE IsPrimary = 1 AND EndDate IS NULL` (현재 주 소속은 하나) |
| `OrgMemberships` | `UX(OrgUnitId) WHERE IsHead = 1 AND EndDate IS NULL` (현재 조직장은 한 명) |
| `OrgMemberships` | CHECK: `EndDate IS NULL OR EndDate >= StartDate` |
| `Employees` | `UX(EmployeeNumber)`, `IX(RrnBlindIndex)` |
| `CostRates` | 같은 직원의 기간이 겹치면 안 됩니다. 이 검사는 애플리케이션이 합니다 |
| `ExpiryAlerts` | `UX(EmployeeId, RuleId, DueDate, StageDays)`: 매일 실행해도 중복으로 만들어지지 않게 |
| 임시 테이블 | `OrgUnits`, `OrgMemberships`, `Employees`, `CostRates`, `EmploymentContracts` |

## 메모

- 순환 구조 금지와 계층 순서는 `hierarchyid`만으로 보장되지 않습니다. 도메인 규칙으로 검사합니다 ([organization.md](../../02-domain/organization.md)).
- 조직을 이동하면 하위 조직 전체의 `Node`를 다시 계산합니다(`GetReparentedValue`). 이 작업은 개편 적용 트랜잭션 안에서 합니다.
