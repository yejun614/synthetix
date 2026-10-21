-- =============================================================================
-- Synthetix DDL 04: accounting (Accounting 모듈, 클라우드 비용 포함)
-- ERD: ../erd/accounting.md
-- =============================================================================

-- 필터링된 인덱스, 임시 테이블, json 타입에 필요한 옵션 (sqlcmd 기본값은 QUOTED_IDENTIFIER OFF)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- -----------------------------------------------------------------------------
-- 회계
-- -----------------------------------------------------------------------------

CREATE TABLE accounting.Accounts (
    Id                  uniqueidentifier NOT NULL,
    Code                nvarchar(10)     NOT NULL,
    Name                nvarchar(100)    NOT NULL,
    AccountType         nvarchar(10)     NOT NULL,
    ParentId            uniqueidentifier NULL,
    IsPostable          bit              NOT NULL CONSTRAINT DF_Accounts_IsPostable DEFAULT (1),   -- 전표에 쓸 수 있는 말단 계정
    IsActive            bit              NOT NULL CONSTRAINT DF_Accounts_IsActive DEFAULT (1),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Accounts_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_Accounts PRIMARY KEY (Id),
    CONSTRAINT FK_Accounts_Accounts_ParentId FOREIGN KEY (ParentId) REFERENCES accounting.Accounts (Id),
    CONSTRAINT CK_Accounts_AccountType CHECK (AccountType IN (N'Asset', N'Liability', N'Equity', N'Revenue', N'Expense'))
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = accounting.AccountsHistory));
CREATE UNIQUE INDEX UX_Accounts_Code ON accounting.Accounts (Code);
GO

CREATE TABLE accounting.AccountingPeriods (
    Id                  uniqueidentifier NOT NULL,
    Year                int              NOT NULL,
    Month               int              NOT NULL,
    Status              nvarchar(10)     NOT NULL CONSTRAINT DF_AccountingPeriods_Status DEFAULT (N'Open'),
    ClosedAt            datetimeoffset   NULL,
    ClosedBy            uniqueidentifier NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_AccountingPeriods_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_AccountingPeriods PRIMARY KEY (Id),
    CONSTRAINT CK_AccountingPeriods_Month CHECK (Month BETWEEN 1 AND 12),
    CONSTRAINT CK_AccountingPeriods_Status CHECK (Status IN (N'Open', N'Closed')),
    CONSTRAINT CK_AccountingPeriods_Closed CHECK (Status = N'Open' OR ClosedAt IS NOT NULL)
);
CREATE UNIQUE INDEX UX_AccountingPeriods_Year_Month ON accounting.AccountingPeriods (Year, Month);
GO

CREATE TABLE accounting.JournalEntries (
    Id                  uniqueidentifier NOT NULL,
    EntryNumber         nvarchar(20)     NOT NULL,              -- JE-202610-00001
    EntryDate           date             NOT NULL,
    PeriodId            uniqueidentifier NOT NULL,
    Description         nvarchar(500)    NOT NULL,
    Status              nvarchar(10)     NOT NULL CONSTRAINT DF_JournalEntries_Status DEFAULT (N'Draft'),
    SourceType          nvarchar(20)     NOT NULL CONSTRAINT DF_JournalEntries_SourceType DEFAULT (N'Manual'),
    SourceId            uniqueidentifier NULL,
    SubmittedBy         uniqueidentifier NULL,
    ApprovedBy          uniqueidentifier NULL,
    PostedAt            datetimeoffset   NULL,
    ReversalOfId        uniqueidentifier NULL,
    IdempotencyKey      nvarchar(100)    NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_JournalEntries_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_JournalEntries PRIMARY KEY (Id),
    CONSTRAINT FK_JournalEntries_AccountingPeriods_PeriodId FOREIGN KEY (PeriodId) REFERENCES accounting.AccountingPeriods (Id),
    CONSTRAINT FK_JournalEntries_JournalEntries_ReversalOfId FOREIGN KEY (ReversalOfId) REFERENCES accounting.JournalEntries (Id),
    CONSTRAINT CK_JournalEntries_Status CHECK (Status IN (N'Draft', N'Submitted', N'Approved', N'Posted', N'Rejected')),
    CONSTRAINT CK_JournalEntries_SourceType CHECK (SourceType IN (N'Manual', N'Milestone', N'CloudCost', N'LaborCost')),
    CONSTRAINT CK_JournalEntries_SegregationOfDuties CHECK (ApprovedBy IS NULL OR CreatedBy IS NULL OR ApprovedBy <> CreatedBy),   -- 작성자와 승인자 분리
    CONSTRAINT CK_JournalEntries_Posted CHECK (Status <> N'Posted' OR (ApprovedBy IS NOT NULL AND PostedAt IS NOT NULL))
);
CREATE UNIQUE INDEX UX_JournalEntries_EntryNumber ON accounting.JournalEntries (EntryNumber);
CREATE UNIQUE INDEX UX_JournalEntries_IdempotencyKey ON accounting.JournalEntries (IdempotencyKey) WHERE IdempotencyKey IS NOT NULL;
CREATE INDEX IX_JournalEntries_PeriodId ON accounting.JournalEntries (PeriodId, EntryDate);
CREATE INDEX IX_JournalEntries_Source ON accounting.JournalEntries (SourceType, SourceId) WHERE SourceId IS NOT NULL;
GO

CREATE TABLE accounting.JournalLines (
    Id                  uniqueidentifier NOT NULL,
    JournalEntryId      uniqueidentifier NOT NULL,
    LineNumber          int              NOT NULL,
    AccountId           uniqueidentifier NOT NULL,
    Debit               decimal(19,4)    NOT NULL CONSTRAINT DF_JournalLines_Debit DEFAULT (0),
    Credit              decimal(19,4)    NOT NULL CONSTRAINT DF_JournalLines_Credit DEFAULT (0),
    ProjectId           uniqueidentifier NULL,                  -- → projects.Projects
    CostCenterUnitId    uniqueidentifier NULL,                  -- → hr.OrgUnits
    Currency            nvarchar(3)      NOT NULL CONSTRAINT DF_JournalLines_Currency DEFAULT (N'KRW'),   -- 원래 통화
    ForeignAmount       decimal(19,4)    NULL,
    ExchangeRate        decimal(19,6)    NULL,
    Description         nvarchar(500)    NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_JournalLines_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_JournalLines PRIMARY KEY (Id),
    CONSTRAINT FK_JournalLines_JournalEntries_JournalEntryId FOREIGN KEY (JournalEntryId) REFERENCES accounting.JournalEntries (Id),
    CONSTRAINT FK_JournalLines_Accounts_AccountId FOREIGN KEY (AccountId) REFERENCES accounting.Accounts (Id),
    CONSTRAINT CK_JournalLines_DebitCredit CHECK (Debit >= 0 AND Credit >= 0 AND (Debit = 0 OR Credit = 0) AND (Debit + Credit) > 0),   -- 한 줄에는 차변 또는 대변 하나만
    CONSTRAINT CK_JournalLines_Foreign CHECK ((Currency = N'KRW' AND ForeignAmount IS NULL AND ExchangeRate IS NULL) OR (Currency <> N'KRW' AND ForeignAmount IS NOT NULL AND ExchangeRate IS NOT NULL))
);
CREATE UNIQUE INDEX UX_JournalLines_JournalEntryId_LineNumber ON accounting.JournalLines (JournalEntryId, LineNumber);
CREATE INDEX IX_JournalLines_ProjectId ON accounting.JournalLines (ProjectId) INCLUDE (AccountId, Debit, Credit) WHERE ProjectId IS NOT NULL;   -- 프로젝트 손익
CREATE INDEX IX_JournalLines_CostCenterUnitId ON accounting.JournalLines (CostCenterUnitId) WHERE CostCenterUnitId IS NOT NULL;           -- 데이터 범위
CREATE INDEX IX_JournalLines_AccountId ON accounting.JournalLines (AccountId);
GO

CREATE TABLE accounting.TaxInvoices (
    Id                  uniqueidentifier NOT NULL,
    Direction           nvarchar(10)     NOT NULL,
    IssueDate           date             NOT NULL,
    ApprovalNumber      nvarchar(30)     NULL,                  -- 국세청 승인번호 (전자세금계산서)
    CounterpartyName    nvarchar(200)    NOT NULL,
    CounterpartyBrn     nvarchar(10)     NOT NULL,
    SupplyAmount        decimal(19,4)    NOT NULL,
    VatAmount           decimal(19,4)    NOT NULL,
    JournalEntryId      uniqueidentifier NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_TaxInvoices_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_TaxInvoices PRIMARY KEY (Id),
    CONSTRAINT FK_TaxInvoices_JournalEntries_JournalEntryId FOREIGN KEY (JournalEntryId) REFERENCES accounting.JournalEntries (Id),
    CONSTRAINT CK_TaxInvoices_Direction CHECK (Direction IN (N'Sales', N'Purchase'))
);
CREATE UNIQUE INDEX UX_TaxInvoices_ApprovalNumber ON accounting.TaxInvoices (ApprovalNumber) WHERE ApprovalNumber IS NOT NULL;
CREATE INDEX IX_TaxInvoices_IssueDate ON accounting.TaxInvoices (IssueDate);
GO

CREATE TABLE accounting.BillingSchedules (
    Id                  uniqueidentifier NOT NULL,
    ProjectId           uniqueidentifier NOT NULL,              -- → projects.Projects
    ContractId          uniqueidentifier NOT NULL,              -- → projects.Contracts
    MilestoneId         uniqueidentifier NULL,                  -- → projects.Milestones
    PlannedDate         date             NOT NULL,
    Amount              decimal(19,4)    NOT NULL,
    Status              nvarchar(10)     NOT NULL CONSTRAINT DF_BillingSchedules_Status DEFAULT (N'Planned'),
    JournalEntryId      uniqueidentifier NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_BillingSchedules_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_BillingSchedules PRIMARY KEY (Id),
    CONSTRAINT FK_BillingSchedules_JournalEntries_JournalEntryId FOREIGN KEY (JournalEntryId) REFERENCES accounting.JournalEntries (Id),
    CONSTRAINT CK_BillingSchedules_Status CHECK (Status IN (N'Planned', N'Invoiced', N'Collected')),
    CONSTRAINT CK_BillingSchedules_Amount CHECK (Amount >= 0)
);
CREATE INDEX IX_BillingSchedules_ProjectId ON accounting.BillingSchedules (ProjectId, PlannedDate);
CREATE UNIQUE INDEX UX_BillingSchedules_MilestoneId ON accounting.BillingSchedules (MilestoneId) WHERE MilestoneId IS NOT NULL;   -- MilestoneAccepted 이벤트 중복 처리 방지
GO

CREATE TABLE accounting.ExchangeRates (
    RateDate            date             NOT NULL,
    Currency            nvarchar(3)      NOT NULL,
    Rate                decimal(19,6)    NOT NULL,              -- 1 단위당 KRW
    Source              nvarchar(50)     NOT NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_ExchangeRates_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    CONSTRAINT PK_ExchangeRates PRIMARY KEY (RateDate, Currency),
    CONSTRAINT CK_ExchangeRates_Rate CHECK (Rate > 0)
);
GO

CREATE TABLE accounting.LaborCostSnapshots (
    Id                  uniqueidentifier NOT NULL,
    Year                int              NOT NULL,
    Month               int              NOT NULL,
    ProjectId           uniqueidentifier NOT NULL,              -- → projects.Projects
    EmployeeId          uniqueidentifier NOT NULL,              -- → hr.Employees
    ManMonth            decimal(9,4)     NOT NULL,
    MonthlyRate         decimal(19,4)    NOT NULL,
    Amount              decimal(19,4)    NOT NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_LaborCostSnapshots_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    CONSTRAINT PK_LaborCostSnapshots PRIMARY KEY (Id),
    CONSTRAINT CK_LaborCostSnapshots_Month CHECK (Month BETWEEN 1 AND 12),
    CONSTRAINT CK_LaborCostSnapshots_Values CHECK (ManMonth >= 0 AND MonthlyRate >= 0 AND Amount >= 0)
);
CREATE UNIQUE INDEX UX_LaborCostSnapshots_Key ON accounting.LaborCostSnapshots (Year, Month, ProjectId, EmployeeId);
CREATE INDEX IX_LaborCostSnapshots_ProjectId ON accounting.LaborCostSnapshots (ProjectId, Year, Month) INCLUDE (Amount);
GO

-- -----------------------------------------------------------------------------
-- 클라우드 비용
-- -----------------------------------------------------------------------------

CREATE TABLE accounting.CloudAccountConnections (
    Id                  uniqueidentifier NOT NULL,
    Provider            nvarchar(10)     NOT NULL,
    DisplayName         nvarchar(100)    NOT NULL,
    ExternalAccountId   nvarchar(100)    NOT NULL,              -- AWS 계정 ID, Azure 구독 ID
    EncryptedCredential varbinary(4000)  NOT NULL,              -- Restricted
    Status              nvarchar(10)     NOT NULL CONSTRAINT DF_CloudAccountConnections_Status DEFAULT (N'Active'),
    LastSyncedAt        datetimeoffset   NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_CloudAccountConnections_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_CloudAccountConnections PRIMARY KEY (Id),
    CONSTRAINT CK_CloudAccountConnections_Provider CHECK (Provider IN (N'AWS', N'Azure')),
    CONSTRAINT CK_CloudAccountConnections_Status CHECK (Status IN (N'Active', N'Error', N'Disabled'))
);
CREATE UNIQUE INDEX UX_CloudAccountConnections_External ON accounting.CloudAccountConnections (Provider, ExternalAccountId);
GO

CREATE TABLE accounting.CloudSyncRuns (
    Id                  uniqueidentifier NOT NULL,
    ConnectionId        uniqueidentifier NOT NULL,
    RangeStart          date             NOT NULL,
    RangeEnd            date             NOT NULL,
    Status              nvarchar(10)     NOT NULL,
    RecordCount         int              NOT NULL CONSTRAINT DF_CloudSyncRuns_RecordCount DEFAULT (0),
    Error               nvarchar(2000)   NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_CloudSyncRuns_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt           datetimeoffset   NULL,
    CONSTRAINT PK_CloudSyncRuns PRIMARY KEY (Id),
    CONSTRAINT FK_CloudSyncRuns_CloudAccountConnections_ConnectionId FOREIGN KEY (ConnectionId) REFERENCES accounting.CloudAccountConnections (Id),
    CONSTRAINT CK_CloudSyncRuns_Status CHECK (Status IN (N'Running', N'Succeeded', N'Failed')),
    CONSTRAINT CK_CloudSyncRuns_Range CHECK (RangeEnd >= RangeStart)
);
CREATE INDEX IX_CloudSyncRuns_ConnectionId ON accounting.CloudSyncRuns (ConnectionId, CreatedAt DESC);
GO

CREATE TABLE accounting.CostAllocationRules (
    Id                  uniqueidentifier NOT NULL,
    Priority            int              NOT NULL,
    RuleType            nvarchar(10)     NOT NULL,
    MatchKey            nvarchar(128)    NULL,                  -- 예: synthetix:project
    MatchValue          nvarchar(256)    NULL,
    ProjectId           uniqueidentifier NULL,                  -- → projects.Projects
    Ratio               decimal(5,4)     NULL,
    IsActive            bit              NOT NULL CONSTRAINT DF_CostAllocationRules_IsActive DEFAULT (1),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_CostAllocationRules_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_CostAllocationRules PRIMARY KEY (Id),
    CONSTRAINT CK_CostAllocationRules_RuleType CHECK (RuleType IN (N'Tag', N'Account', N'Ratio')),
    CONSTRAINT CK_CostAllocationRules_Ratio CHECK ((RuleType = N'Ratio' AND Ratio IS NOT NULL AND Ratio > 0 AND Ratio <= 1) OR (RuleType <> N'Ratio' AND Ratio IS NULL))
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = accounting.CostAllocationRulesHistory));
CREATE INDEX IX_CostAllocationRules_Active ON accounting.CostAllocationRules (Priority) WHERE IsActive = 1;
GO

CREATE TABLE accounting.CloudCostRecords (
    Id                  bigint           IDENTITY(1,1) NOT NULL,   -- 대용량 추가 전용이라 GUID 대신 bigint
    ConnectionId        uniqueidentifier NOT NULL,
    ChargeDate          date             NOT NULL,
    ServiceName         nvarchar(100)    NOT NULL,
    ServiceCategory     nvarchar(50)     NOT NULL,
    RegionId            nvarchar(50)     NULL,
    ResourceId          nvarchar(500)    NULL,
    BilledCost          decimal(19,6)    NOT NULL,
    EffectiveCost       decimal(19,6)    NOT NULL,
    BillingCurrency     nvarchar(3)      NOT NULL,
    Tags                json             NULL,
    AllocatedProjectId  uniqueidentifier NULL,                  -- → projects.Projects
    AllocationRuleId    uniqueidentifier NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_CloudCostRecords_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_CloudCostRecords PRIMARY KEY (Id),
    CONSTRAINT FK_CloudCostRecords_CloudAccountConnections_ConnectionId FOREIGN KEY (ConnectionId) REFERENCES accounting.CloudAccountConnections (Id),
    CONSTRAINT FK_CloudCostRecords_CostAllocationRules_AllocationRuleId FOREIGN KEY (AllocationRuleId) REFERENCES accounting.CostAllocationRules (Id)
);
CREATE INDEX IX_CloudCostRecords_Connection_Date ON accounting.CloudCostRecords (ConnectionId, ChargeDate);   -- 재수집 시 범위 삭제
CREATE INDEX IX_CloudCostRecords_Project_Date ON accounting.CloudCostRecords (AllocatedProjectId, ChargeDate) INCLUDE (EffectiveCost, BillingCurrency) WHERE AllocatedProjectId IS NOT NULL;
-- 데이터가 많아지면 분석용 비클러스터형 columnstore 인덱스를 검토합니다.
GO

CREATE TABLE accounting.Budgets (
    Id                  uniqueidentifier NOT NULL,
    ScopeType           nvarchar(10)     NOT NULL,
    ScopeId             uniqueidentifier NOT NULL,              -- 프로젝트 ID 또는 연결 ID
    Year                int              NOT NULL,
    Month               int              NOT NULL,
    Amount              decimal(19,4)    NOT NULL,
    Currency            nvarchar(3)      NOT NULL CONSTRAINT DF_Budgets_Currency DEFAULT (N'KRW'),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Budgets_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_Budgets PRIMARY KEY (Id),
    CONSTRAINT CK_Budgets_ScopeType CHECK (ScopeType IN (N'Project', N'Connection')),
    CONSTRAINT CK_Budgets_Month CHECK (Month BETWEEN 1 AND 12),
    CONSTRAINT CK_Budgets_Amount CHECK (Amount >= 0)
);
CREATE UNIQUE INDEX UX_Budgets_Key ON accounting.Budgets (ScopeType, ScopeId, Year, Month);
GO

CREATE TABLE accounting.CloudCostAnomalies (
    Id                  uniqueidentifier NOT NULL,
    ConnectionId        uniqueidentifier NOT NULL,
    ChargeDate          date             NOT NULL,
    ServiceName         nvarchar(100)    NOT NULL,
    ExpectedCost        decimal(19,6)    NOT NULL,
    ActualCost          decimal(19,6)    NOT NULL,
    Score               decimal(9,4)     NOT NULL,
    AiInteractionId     uniqueidentifier NULL,                  -- → ai.Interactions (AI-ACC-01 설명)
    Status              nvarchar(15)     NOT NULL CONSTRAINT DF_CloudCostAnomalies_Status DEFAULT (N'Open'),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_CloudCostAnomalies_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_CloudCostAnomalies PRIMARY KEY (Id),
    CONSTRAINT FK_CloudCostAnomalies_CloudAccountConnections_ConnectionId FOREIGN KEY (ConnectionId) REFERENCES accounting.CloudAccountConnections (Id),
    CONSTRAINT CK_CloudCostAnomalies_Status CHECK (Status IN (N'Open', N'Acknowledged', N'Dismissed'))
);
CREATE UNIQUE INDEX UX_CloudCostAnomalies_Key ON accounting.CloudCostAnomalies (ConnectionId, ChargeDate, ServiceName);
GO
