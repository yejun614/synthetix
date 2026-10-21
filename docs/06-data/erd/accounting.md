# ERD: accounting

> 상태: 초안 · 갱신: 2026-10-21 · 업무 규칙: [accounting.md](../../02-domain/accounting.md), [cloud-cost.md](../../02-domain/cloud-cost.md) · DDL: [04-accounting.sql](../ddl/04-accounting.sql)

## 회계

```mermaid
erDiagram
    Accounts ||--o{ Accounts : "ParentId"
    AccountingPeriods ||--o{ JournalEntries : ""
    JournalEntries ||--|{ JournalLines : ""
    JournalLines }o--|| Accounts : ""
    JournalEntries |o--o| JournalEntries : "ReversalOfId"
    TaxInvoices }o--o| JournalEntries : ""
    BillingSchedules }o--o| JournalEntries : ""

    Accounts {
        uniqueidentifier Id PK
        nvarchar Code UK "10"
        nvarchar Name "100"
        nvarchar AccountType "Asset, Liability, Equity, Revenue, Expense"
        uniqueidentifier ParentId FK "null"
        bit IsPostable "전표에 쓸 수 있는 말단 계정"
        bit IsActive
    }
    AccountingPeriods {
        uniqueidentifier Id PK
        int Year
        int Month
        nvarchar Status "Open, Closed"
        datetimeoffset ClosedAt "null"
        uniqueidentifier ClosedBy "null"
    }
    JournalEntries {
        uniqueidentifier Id PK
        nvarchar EntryNumber UK "JE-202610-00001"
        date EntryDate
        uniqueidentifier PeriodId FK
        nvarchar Description "500"
        nvarchar Status "Draft, Submitted, Approved, Posted, Rejected"
        nvarchar SourceType "Manual, Milestone, CloudCost, LaborCost"
        uniqueidentifier SourceId "null"
        uniqueidentifier SubmittedBy "null"
        uniqueidentifier ApprovedBy "null, 작성자와 달라야 함"
        datetimeoffset PostedAt "null"
        uniqueidentifier ReversalOfId FK "null"
        nvarchar IdempotencyKey UK "null, 100"
    }
    JournalLines {
        uniqueidentifier Id PK
        uniqueidentifier JournalEntryId FK
        int LineNumber
        uniqueidentifier AccountId FK
        decimal Debit "19,4"
        decimal Credit "19,4"
        uniqueidentifier ProjectId "null, → projects.Projects"
        uniqueidentifier CostCenterUnitId "null, → hr.OrgUnits"
        nvarchar Currency "3, 원래 통화"
        decimal ForeignAmount "null, 19,4"
        decimal ExchangeRate "null, 19,6"
        nvarchar Description "null"
    }
    TaxInvoices {
        uniqueidentifier Id PK
        nvarchar Direction "Sales, Purchase"
        date IssueDate
        nvarchar ApprovalNumber UK "국세청 승인번호"
        nvarchar CounterpartyName "200"
        nvarchar CounterpartyBrn "10"
        decimal SupplyAmount "19,4"
        decimal VatAmount "19,4"
        uniqueidentifier JournalEntryId FK "null"
    }
    BillingSchedules {
        uniqueidentifier Id PK
        uniqueidentifier ProjectId "→ projects.Projects"
        uniqueidentifier ContractId "→ projects.Contracts"
        uniqueidentifier MilestoneId "null, → projects.Milestones"
        date PlannedDate
        decimal Amount "19,4"
        nvarchar Status "Planned, Invoiced, Collected"
        uniqueidentifier JournalEntryId FK "null"
    }
    ExchangeRates {
        date RateDate PK
        nvarchar Currency PK "3"
        decimal Rate "19,6, 1 단위당 KRW"
        nvarchar Source "50"
    }
    LaborCostSnapshots {
        uniqueidentifier Id PK
        int Year
        int Month
        uniqueidentifier ProjectId "→ projects.Projects"
        uniqueidentifier EmployeeId "→ hr.Employees"
        decimal ManMonth "9,4"
        decimal MonthlyRate "19,4"
        decimal Amount "19,4"
    }
```

## 클라우드 비용

```mermaid
erDiagram
    CloudAccountConnections ||--o{ CloudCostRecords : ""
    CloudAccountConnections ||--o{ CloudSyncRuns : ""
    CostAllocationRules ||--o{ CloudCostRecords : "적용된 규칙"
    CloudAccountConnections ||--o{ CloudCostAnomalies : ""

    CloudAccountConnections {
        uniqueidentifier Id PK
        nvarchar Provider "AWS, Azure"
        nvarchar DisplayName "100"
        nvarchar ExternalAccountId UK "AWS 계정 ID, Azure 구독 ID"
        varbinary EncryptedCredential "Restricted"
        nvarchar Status "Active, Error, Disabled"
        datetimeoffset LastSyncedAt "null"
    }
    CloudSyncRuns {
        uniqueidentifier Id PK
        uniqueidentifier ConnectionId FK
        date RangeStart
        date RangeEnd
        nvarchar Status "Running, Succeeded, Failed"
        int RecordCount
        nvarchar Error "null"
    }
    CloudCostRecords {
        bigint Id PK "identity, 대용량"
        uniqueidentifier ConnectionId FK
        date ChargeDate
        nvarchar ServiceName "100"
        nvarchar ServiceCategory "50"
        nvarchar RegionId "null"
        nvarchar ResourceId "null, 500"
        decimal BilledCost "19,6"
        decimal EffectiveCost "19,6"
        nvarchar BillingCurrency "3"
        nvarchar Tags "JSON"
        uniqueidentifier AllocatedProjectId "null, → projects.Projects"
        uniqueidentifier AllocationRuleId FK "null"
    }
    CostAllocationRules {
        uniqueidentifier Id PK
        int Priority
        nvarchar RuleType "Tag, Account, Ratio"
        nvarchar MatchKey "null, 예: synthetix:project"
        nvarchar MatchValue "null"
        uniqueidentifier ProjectId "null, → projects.Projects"
        decimal Ratio "null, 5,4"
        bit IsActive
    }
    Budgets {
        uniqueidentifier Id PK
        nvarchar ScopeType "Project, Connection"
        uniqueidentifier ScopeId
        int Year
        int Month
        decimal Amount "19,4"
        nvarchar Currency "3"
    }
    CloudCostAnomalies {
        uniqueidentifier Id PK
        uniqueidentifier ConnectionId FK
        date ChargeDate
        nvarchar ServiceName
        decimal ExpectedCost "19,6"
        decimal ActualCost "19,6"
        decimal Score "9,4"
        uniqueidentifier AiInteractionId "null, → ai.Interactions"
        nvarchar Status "Open, Acknowledged, Dismissed"
    }
```

## 제약조건과 인덱스

| 테이블 | 내용 |
|---|---|
| `AccountingPeriods` | `UX(Year, Month)` |
| `CloudAccountConnections` | `UX(Provider, ExternalAccountId)` |
| `JournalEntries` | `UX(EntryNumber)`, `UX(IdempotencyKey) WHERE IdempotencyKey IS NOT NULL` |
| `JournalLines` | CHECK: `Debit >= 0 AND Credit >= 0 AND (Debit = 0 OR Credit = 0) AND Debit + Credit > 0`. 컬럼 이름이 `LineNo`가 아닌 `LineNumber`인 이유: `LINENO`는 T-SQL 예약어입니다. 차변 합계 = 대변 합계 검사는 도메인에서 합니다 |
| `JournalLines` | `IX(ProjectId)`, `IX(CostCenterUnitId)`: 손익 집계와 데이터 범위 |
| `LaborCostSnapshots` | `UX(Year, Month, ProjectId, EmployeeId)` |
| `CloudCostRecords` | 다시 수집할 때는 `(ConnectionId, ChargeDate)` 범위를 지우고 다시 넣습니다. 분석 쿼리용 **클러스터형 columnstore 인덱스**를 검토합니다 |
| `CostAllocationRules` | `IX(Priority) WHERE IsActive = 1` |
| `Budgets` | `UX(ScopeType, ScopeId, Year, Month)` |
| 임시 테이블 | `Accounts`, `CostAllocationRules` |

## 메모

- `Posted` 상태의 전표와 줄은 수정과 삭제를 막습니다. 애플리케이션에서 검사하고, DB 트리거로 한 번 더 막는 방안을 검토합니다.
- `CloudCostRecords`는 GUID 대신 `bigint identity`를 씁니다. 대용량으로 추가만 하는 테이블이기 때문입니다 ([db-conventions.md](../db-conventions.md)의 키 규칙 예외).
