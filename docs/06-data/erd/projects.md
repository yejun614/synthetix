# ERD: projects

> 상태: 초안 · 갱신: 2026-10-21 · 업무 규칙: [projects.md](../../02-domain/projects.md) · DDL: [03-projects.sql](../ddl/03-projects.sql)

## 거래처와 계약

```mermaid
erDiagram
    Clients ||--o{ ClientContacts : ""
    Contracts ||--o{ ContractAmendments : ""
    Contracts ||--o{ PaymentTerms : ""
    Contracts ||--o{ ContractDocuments : ""
    ContractDocuments ||--o{ ContractExtractions : "AI 추출 제안"
    Contracts ||--o{ ContractProjects : ""
    Projects ||--o{ ContractProjects : ""

    Clients {
        uniqueidentifier Id PK
        nvarchar Code UK "20"
        nvarchar Name "200"
        nvarchar BusinessRegistrationNumber "null, 10"
        nvarchar Industry "null"
        bit IsDeleted
    }
    ClientContacts {
        uniqueidentifier Id PK
        uniqueidentifier ClientId FK
        nvarchar Name "50, Confidential"
        nvarchar Title "null"
        nvarchar Email "null, Confidential"
        nvarchar Phone "null, Confidential"
    }
    Partners {
        uniqueidentifier Id PK
        nvarchar Code UK "20"
        nvarchar Name "200"
        nvarchar BusinessRegistrationNumber "10"
        nvarchar PartnerType "Outsourcing, DispatchAgency, Both"
        bit IsDeleted
    }
    Contracts {
        uniqueidentifier Id PK
        nvarchar ContractNumber UK "CT-2026-0012"
        nvarchar Title "200"
        nvarchar Direction "Sales, Purchase"
        nvarchar Type "Outsourcing, Service, Maintenance, Staffing"
        nvarchar Tier "Prime, Sub"
        nvarchar PrimeContractorName "null, 하도급일 때 원청사"
        nvarchar CounterpartyType "Client, Partner"
        uniqueidentifier CounterpartyId "Clients.Id 또는 Partners.Id"
        date StartDate
        date EndDate
        decimal SupplyAmount "19,4, Confidential"
        decimal VatAmount "19,4"
        nvarchar Currency "3"
        int WarrantyMonths
        date SignedDate "null"
        nvarchar Status "Draft, Signed, Active, Completed, Closed, Terminated"
    }
    ContractAmendments {
        uniqueidentifier Id PK
        uniqueidentifier ContractId FK
        int Seq
        date EffectiveDate
        date NewEndDate "null"
        decimal NewSupplyAmount "null"
        nvarchar Reason "500"
        uniqueidentifier FileId "null, → platform.Files"
    }
    PaymentTerms {
        uniqueidentifier Id PK
        uniqueidentifier ContractId FK
        int Seq
        nvarchar TermType "Advance, Interim, Final, Monthly"
        decimal Rate "null, 5,4"
        decimal Amount "null, 19,4"
        uniqueidentifier MilestoneId FK "null"
        nvarchar Condition "null, 지급 조건 원문"
    }
    ContractDocuments {
        uniqueidentifier Id PK
        uniqueidentifier ContractId FK
        int Version
        uniqueidentifier FileId "→ platform.Files"
        nvarchar ExtractionStatus "None, Pending, Done, Failed"
    }
    ContractExtractions {
        uniqueidentifier Id PK
        uniqueidentifier ContractDocumentId FK
        uniqueidentifier AiInteractionId "→ ai.Interactions"
        nvarchar ResultJson "max, 필드별 값, 신뢰도, 원문 근거"
        nvarchar Status "Proposed, Accepted, PartiallyAccepted, Rejected"
        uniqueidentifier ReviewedBy "null"
        datetimeoffset ReviewedAt "null"
    }
    ContractProjects {
        uniqueidentifier ContractId PK, FK
        uniqueidentifier ProjectId PK, FK
    }
    Projects {
        uniqueidentifier Id PK
    }
```

## 프로젝트, 일정, 투입

```mermaid
erDiagram
    Projects ||--o{ Milestones : ""
    Milestones ||--o{ Deliverables : ""
    Milestones ||--o| ProgressBillings : ""
    Projects ||--o{ WorkItems : ""
    WorkItems ||--o{ WorkItems : "ParentId"
    Projects ||--o{ Assignments : ""

    Projects {
        uniqueidentifier Id PK
        nvarchar ProjectCode UK "PRJ-2026-0007, 클라우드 태그 키"
        nvarchar Name "200"
        nvarchar Type "SI, SM"
        nvarchar Status "Proposal, Contracted, InProgress, Accepted, Warranty, Closed, Dropped"
        uniqueidentifier OwningUnitId "→ hr.OrgUnits, 데이터 범위 기준"
        uniqueidentifier PmEmployeeId "null, → hr.Employees"
        date PlannedStart
        date PlannedEnd
        date ActualStart "null"
        date ActualEnd "null"
        decimal BudgetManMonths "9,2"
        decimal BudgetAmount "19,4, Confidential"
    }
    Milestones {
        uniqueidentifier Id PK
        uniqueidentifier ProjectId FK
        nvarchar Name "200"
        date DueDate
        nvarchar Status "Planned, Submitted, Accepted, Rejected"
        date AcceptedDate "null"
    }
    Deliverables {
        uniqueidentifier Id PK
        uniqueidentifier MilestoneId FK
        nvarchar Name "200"
        uniqueidentifier FileId "null, → platform.Files"
        nvarchar Status "Draft, Submitted, Accepted"
    }
    ProgressBillings {
        uniqueidentifier Id PK
        uniqueidentifier MilestoneId FK, UK
        uniqueidentifier ContractId FK
        decimal Amount "19,4"
        date BilledDate "null"
        nvarchar Status "Planned, Billed, Paid"
    }
    WorkItems {
        uniqueidentifier Id PK
        uniqueidentifier ProjectId FK
        uniqueidentifier ParentId FK "null"
        nvarchar WbsCode "1.2.3"
        nvarchar Name "200"
        date PlannedStart
        date PlannedEnd
        date ActualStart "null"
        date ActualEnd "null"
        decimal PlannedEffortDays "9,2"
        decimal Progress "5,4, 0~1"
        uniqueidentifier AssigneeEmployeeId "null, → hr.Employees"
        int SortOrder
    }
    Assignments {
        uniqueidentifier Id PK
        uniqueidentifier ProjectId FK
        uniqueidentifier EmployeeId "→ hr.Employees"
        nvarchar Role "PM, PL, Developer, Designer, QA ..."
        date StartDate
        date EndDate
        decimal AllocationRate "5,4, 0~1"
        nvarchar WorkLocation "Office, OnSite, Remote"
        decimal MonthlyRate "19,4, 기본값은 hr.CostRates"
        uniqueidentifier PurchaseContractId FK "null, 협력사 인력의 매입 계약"
    }
```

## 제약조건과 인덱스

| 테이블 | 내용 |
|---|---|
| `Clients`, `Partners` | `UX(Code)`. 사업자등록번호는 `UX(BusinessRegistrationNumber) WHERE IsDeleted = 0` (값이 있을 때) |
| `Contracts` | `UX(ContractNumber)`, `IX(CounterpartyType, CounterpartyId)` |
| `ContractAmendments` | `UX(ContractId, Seq)` |
| `ContractDocuments` | `UX(ContractId, Version)` |
| `Projects` | `UX(ProjectCode)`, `IX(OwningUnitId)` (데이터 범위 필터) |
| `WorkItems` | `UX(ProjectId, WbsCode)` |
| `Assignments` | `IX(EmployeeId, StartDate, EndDate)` (투입률 중복 검사, 가동 현황) |
| `Assignments` | CHECK: `AllocationRate > 0 AND AllocationRate <= 1`, `EndDate >= StartDate` |
| 임시 테이블 | `Contracts`, `ContractAmendments`, `PaymentTerms`, `Projects`, `Assignments` |
