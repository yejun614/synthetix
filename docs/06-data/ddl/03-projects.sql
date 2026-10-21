-- =============================================================================
-- Synthetix DDL 03: projects (Projects 모듈)
-- ERD: ../erd/projects.md
-- =============================================================================

-- 필터링된 인덱스, 임시 테이블, json 타입에 필요한 옵션 (sqlcmd 기본값은 QUOTED_IDENTIFIER OFF)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- -----------------------------------------------------------------------------
-- 거래처
-- -----------------------------------------------------------------------------

CREATE TABLE projects.Clients (
    Id                          uniqueidentifier NOT NULL,
    Code                        nvarchar(20)     NOT NULL,
    Name                        nvarchar(200)    NOT NULL,
    BusinessRegistrationNumber  nvarchar(10)     NULL,
    Industry                    nvarchar(100)    NULL,
    IsDeleted                   bit              NOT NULL CONSTRAINT DF_Clients_IsDeleted DEFAULT (0),
    CreatedAt                   datetimeoffset   NOT NULL CONSTRAINT DF_Clients_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy                   uniqueidentifier NULL,
    UpdatedAt                   datetimeoffset   NULL,
    UpdatedBy                   uniqueidentifier NULL,
    RowVersion                  rowversion       NOT NULL,
    CONSTRAINT PK_Clients PRIMARY KEY (Id)
);
CREATE UNIQUE INDEX UX_Clients_Code ON projects.Clients (Code);
CREATE UNIQUE INDEX UX_Clients_Brn ON projects.Clients (BusinessRegistrationNumber) WHERE IsDeleted = 0 AND BusinessRegistrationNumber IS NOT NULL;
GO

CREATE TABLE projects.ClientContacts (
    Id                  uniqueidentifier NOT NULL,
    ClientId            uniqueidentifier NOT NULL,
    Name                nvarchar(50)     NOT NULL,              -- Confidential
    Title               nvarchar(50)     NULL,
    Email               nvarchar(200)    NULL,                  -- Confidential
    Phone               nvarchar(20)     NULL,                  -- Confidential
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_ClientContacts_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_ClientContacts PRIMARY KEY (Id),
    CONSTRAINT FK_ClientContacts_Clients_ClientId FOREIGN KEY (ClientId) REFERENCES projects.Clients (Id)
);
CREATE INDEX IX_ClientContacts_ClientId ON projects.ClientContacts (ClientId);
GO

CREATE TABLE projects.Partners (
    Id                          uniqueidentifier NOT NULL,
    Code                        nvarchar(20)     NOT NULL,
    Name                        nvarchar(200)    NOT NULL,
    BusinessRegistrationNumber  nvarchar(10)     NOT NULL,
    PartnerType                 nvarchar(20)     NOT NULL,
    IsDeleted                   bit              NOT NULL CONSTRAINT DF_Partners_IsDeleted DEFAULT (0),
    CreatedAt                   datetimeoffset   NOT NULL CONSTRAINT DF_Partners_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy                   uniqueidentifier NULL,
    UpdatedAt                   datetimeoffset   NULL,
    UpdatedBy                   uniqueidentifier NULL,
    RowVersion                  rowversion       NOT NULL,
    CONSTRAINT PK_Partners PRIMARY KEY (Id),
    CONSTRAINT CK_Partners_PartnerType CHECK (PartnerType IN (N'Outsourcing', N'DispatchAgency', N'Both'))
);
CREATE UNIQUE INDEX UX_Partners_Code ON projects.Partners (Code);
CREATE UNIQUE INDEX UX_Partners_Brn ON projects.Partners (BusinessRegistrationNumber) WHERE IsDeleted = 0;
GO

-- -----------------------------------------------------------------------------
-- 계약
-- -----------------------------------------------------------------------------

CREATE TABLE projects.Contracts (
    Id                  uniqueidentifier NOT NULL,
    ContractNumber      nvarchar(20)     NOT NULL,              -- CT-2026-0012
    Title               nvarchar(200)    NOT NULL,
    Direction           nvarchar(10)     NOT NULL,
    Type                nvarchar(20)     NOT NULL,
    Tier                nvarchar(10)     NOT NULL,
    PrimeContractorName nvarchar(200)    NULL,                  -- 하도급일 때 원청사
    CounterpartyType    nvarchar(10)     NOT NULL,
    CounterpartyId      uniqueidentifier NOT NULL,              -- Clients.Id 또는 Partners.Id (유형에 따라 다르므로 FK 없음)
    StartDate           date             NOT NULL,
    EndDate             date             NOT NULL,
    SupplyAmount        decimal(19,4)    NOT NULL,              -- Confidential
    VatAmount           decimal(19,4)    NOT NULL,
    Currency            nvarchar(3)      NOT NULL CONSTRAINT DF_Contracts_Currency DEFAULT (N'KRW'),
    WarrantyMonths      int              NOT NULL CONSTRAINT DF_Contracts_WarrantyMonths DEFAULT (0),
    SignedDate          date             NULL,
    Status              nvarchar(20)     NOT NULL CONSTRAINT DF_Contracts_Status DEFAULT (N'Draft'),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Contracts_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_Contracts PRIMARY KEY (Id),
    CONSTRAINT CK_Contracts_Direction CHECK (Direction IN (N'Sales', N'Purchase')),
    CONSTRAINT CK_Contracts_Type CHECK (Type IN (N'Outsourcing', N'Service', N'Maintenance', N'Staffing')),
    CONSTRAINT CK_Contracts_Tier CHECK (Tier IN (N'Prime', N'Sub')),
    CONSTRAINT CK_Contracts_CounterpartyType CHECK (CounterpartyType IN (N'Client', N'Partner')),
    CONSTRAINT CK_Contracts_Status CHECK (Status IN (N'Draft', N'Signed', N'Active', N'Completed', N'Closed', N'Terminated')),
    CONSTRAINT CK_Contracts_Period CHECK (EndDate >= StartDate),
    CONSTRAINT CK_Contracts_Amounts CHECK (SupplyAmount >= 0 AND VatAmount >= 0),
    CONSTRAINT CK_Contracts_WarrantyMonths CHECK (WarrantyMonths >= 0)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = projects.ContractsHistory));
CREATE UNIQUE INDEX UX_Contracts_ContractNumber ON projects.Contracts (ContractNumber);
CREATE INDEX IX_Contracts_Counterparty ON projects.Contracts (CounterpartyType, CounterpartyId);
GO

CREATE TABLE projects.ContractAmendments (
    Id                  uniqueidentifier NOT NULL,
    ContractId          uniqueidentifier NOT NULL,
    Seq                 int              NOT NULL,
    EffectiveDate       date             NOT NULL,
    NewEndDate          date             NULL,
    NewSupplyAmount     decimal(19,4)    NULL,
    Reason              nvarchar(500)    NOT NULL,
    FileId              uniqueidentifier NULL,                  -- → platform.Files
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_ContractAmendments_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_ContractAmendments PRIMARY KEY (Id),
    CONSTRAINT FK_ContractAmendments_Contracts_ContractId FOREIGN KEY (ContractId) REFERENCES projects.Contracts (Id),
    CONSTRAINT CK_ContractAmendments_Amount CHECK (NewSupplyAmount IS NULL OR NewSupplyAmount >= 0)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = projects.ContractAmendmentsHistory));
CREATE UNIQUE INDEX UX_ContractAmendments_ContractId_Seq ON projects.ContractAmendments (ContractId, Seq);
GO

CREATE TABLE projects.ContractDocuments (
    Id                  uniqueidentifier NOT NULL,
    ContractId          uniqueidentifier NOT NULL,
    Version             int              NOT NULL,
    FileId              uniqueidentifier NOT NULL,              -- → platform.Files
    ExtractionStatus    nvarchar(10)     NOT NULL CONSTRAINT DF_ContractDocuments_ExtractionStatus DEFAULT (N'None'),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_ContractDocuments_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_ContractDocuments PRIMARY KEY (Id),
    CONSTRAINT FK_ContractDocuments_Contracts_ContractId FOREIGN KEY (ContractId) REFERENCES projects.Contracts (Id),
    CONSTRAINT CK_ContractDocuments_ExtractionStatus CHECK (ExtractionStatus IN (N'None', N'Pending', N'Done', N'Failed'))
);
CREATE UNIQUE INDEX UX_ContractDocuments_ContractId_Version ON projects.ContractDocuments (ContractId, Version);
GO

CREATE TABLE projects.ContractExtractions (
    Id                  uniqueidentifier NOT NULL,
    ContractDocumentId  uniqueidentifier NOT NULL,
    AiInteractionId     uniqueidentifier NOT NULL,              -- → ai.Interactions
    ResultJson          json             NOT NULL,              -- 필드별 값, 신뢰도, 원문 근거
    Status              nvarchar(20)     NOT NULL CONSTRAINT DF_ContractExtractions_Status DEFAULT (N'Proposed'),
    ReviewedBy          uniqueidentifier NULL,
    ReviewedAt          datetimeoffset   NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_ContractExtractions_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_ContractExtractions PRIMARY KEY (Id),
    CONSTRAINT FK_ContractExtractions_ContractDocuments_ContractDocumentId FOREIGN KEY (ContractDocumentId) REFERENCES projects.ContractDocuments (Id),
    CONSTRAINT CK_ContractExtractions_Status CHECK (Status IN (N'Proposed', N'Accepted', N'PartiallyAccepted', N'Rejected'))
);
CREATE INDEX IX_ContractExtractions_ContractDocumentId ON projects.ContractExtractions (ContractDocumentId);
GO

-- -----------------------------------------------------------------------------
-- 프로젝트와 일정
-- -----------------------------------------------------------------------------

CREATE TABLE projects.Projects (
    Id                  uniqueidentifier NOT NULL,
    ProjectCode         nvarchar(20)     NOT NULL,              -- PRJ-2026-0007, 클라우드 태그 키
    Name                nvarchar(200)    NOT NULL,
    Type                nvarchar(5)      NOT NULL,
    Status              nvarchar(20)     NOT NULL CONSTRAINT DF_Projects_Status DEFAULT (N'Proposal'),
    OwningUnitId        uniqueidentifier NOT NULL,              -- → hr.OrgUnits, 데이터 범위 기준
    PmEmployeeId        uniqueidentifier NULL,                  -- → hr.Employees
    PlannedStart        date             NOT NULL,
    PlannedEnd          date             NOT NULL,
    ActualStart         date             NULL,
    ActualEnd           date             NULL,
    BudgetManMonths     decimal(9,2)     NOT NULL CONSTRAINT DF_Projects_BudgetManMonths DEFAULT (0),
    BudgetAmount        decimal(19,4)    NOT NULL CONSTRAINT DF_Projects_BudgetAmount DEFAULT (0),   -- Confidential
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Projects_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_Projects PRIMARY KEY (Id),
    CONSTRAINT CK_Projects_Type CHECK (Type IN (N'SI', N'SM')),
    CONSTRAINT CK_Projects_Status CHECK (Status IN (N'Proposal', N'Contracted', N'InProgress', N'Accepted', N'Warranty', N'Closed', N'Dropped')),
    CONSTRAINT CK_Projects_PlannedPeriod CHECK (PlannedEnd >= PlannedStart),
    CONSTRAINT CK_Projects_ActualPeriod CHECK (ActualEnd IS NULL OR (ActualStart IS NOT NULL AND ActualEnd >= ActualStart)),
    CONSTRAINT CK_Projects_Budget CHECK (BudgetManMonths >= 0 AND BudgetAmount >= 0)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = projects.ProjectsHistory));
CREATE UNIQUE INDEX UX_Projects_ProjectCode ON projects.Projects (ProjectCode);
CREATE INDEX IX_Projects_OwningUnitId ON projects.Projects (OwningUnitId);
CREATE INDEX IX_Projects_PmEmployeeId ON projects.Projects (PmEmployeeId) WHERE PmEmployeeId IS NOT NULL;
GO

CREATE TABLE projects.ContractProjects (
    ContractId          uniqueidentifier NOT NULL,
    ProjectId           uniqueidentifier NOT NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_ContractProjects_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    CONSTRAINT PK_ContractProjects PRIMARY KEY (ContractId, ProjectId),
    CONSTRAINT FK_ContractProjects_Contracts_ContractId FOREIGN KEY (ContractId) REFERENCES projects.Contracts (Id),
    CONSTRAINT FK_ContractProjects_Projects_ProjectId FOREIGN KEY (ProjectId) REFERENCES projects.Projects (Id)
);
CREATE INDEX IX_ContractProjects_ProjectId ON projects.ContractProjects (ProjectId);
GO

CREATE TABLE projects.Milestones (
    Id                  uniqueidentifier NOT NULL,
    ProjectId           uniqueidentifier NOT NULL,
    Name                nvarchar(200)    NOT NULL,
    DueDate             date             NOT NULL,
    Status              nvarchar(20)     NOT NULL CONSTRAINT DF_Milestones_Status DEFAULT (N'Planned'),
    AcceptedDate        date             NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Milestones_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_Milestones PRIMARY KEY (Id),
    CONSTRAINT FK_Milestones_Projects_ProjectId FOREIGN KEY (ProjectId) REFERENCES projects.Projects (Id),
    CONSTRAINT CK_Milestones_Status CHECK (Status IN (N'Planned', N'Submitted', N'Accepted', N'Rejected')),
    CONSTRAINT CK_Milestones_Accepted CHECK (Status <> N'Accepted' OR AcceptedDate IS NOT NULL)
);
CREATE INDEX IX_Milestones_ProjectId ON projects.Milestones (ProjectId, DueDate);
GO

CREATE TABLE projects.PaymentTerms (
    Id                  uniqueidentifier NOT NULL,
    ContractId          uniqueidentifier NOT NULL,
    Seq                 int              NOT NULL,
    TermType            nvarchar(10)     NOT NULL,
    Rate                decimal(5,4)     NULL,
    Amount              decimal(19,4)    NULL,
    MilestoneId         uniqueidentifier NULL,
    Condition           nvarchar(500)    NULL,                  -- 지급 조건 원문
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_PaymentTerms_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_PaymentTerms PRIMARY KEY (Id),
    CONSTRAINT FK_PaymentTerms_Contracts_ContractId FOREIGN KEY (ContractId) REFERENCES projects.Contracts (Id),
    CONSTRAINT FK_PaymentTerms_Milestones_MilestoneId FOREIGN KEY (MilestoneId) REFERENCES projects.Milestones (Id),
    CONSTRAINT CK_PaymentTerms_TermType CHECK (TermType IN (N'Advance', N'Interim', N'Final', N'Monthly')),
    CONSTRAINT CK_PaymentTerms_RateOrAmount CHECK (Rate IS NOT NULL OR Amount IS NOT NULL),
    CONSTRAINT CK_PaymentTerms_Rate CHECK (Rate IS NULL OR (Rate > 0 AND Rate <= 1))
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = projects.PaymentTermsHistory));
CREATE UNIQUE INDEX UX_PaymentTerms_ContractId_Seq ON projects.PaymentTerms (ContractId, Seq);
GO

CREATE TABLE projects.Deliverables (
    Id                  uniqueidentifier NOT NULL,
    MilestoneId         uniqueidentifier NOT NULL,
    Name                nvarchar(200)    NOT NULL,
    FileId              uniqueidentifier NULL,                  -- → platform.Files
    Status              nvarchar(20)     NOT NULL CONSTRAINT DF_Deliverables_Status DEFAULT (N'Draft'),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Deliverables_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_Deliverables PRIMARY KEY (Id),
    CONSTRAINT FK_Deliverables_Milestones_MilestoneId FOREIGN KEY (MilestoneId) REFERENCES projects.Milestones (Id),
    CONSTRAINT CK_Deliverables_Status CHECK (Status IN (N'Draft', N'Submitted', N'Accepted'))
);
CREATE INDEX IX_Deliverables_MilestoneId ON projects.Deliverables (MilestoneId);
GO

CREATE TABLE projects.ProgressBillings (
    Id                  uniqueidentifier NOT NULL,
    MilestoneId         uniqueidentifier NOT NULL,
    ContractId          uniqueidentifier NOT NULL,
    Amount              decimal(19,4)    NOT NULL,
    BilledDate          date             NULL,
    Status              nvarchar(10)     NOT NULL CONSTRAINT DF_ProgressBillings_Status DEFAULT (N'Planned'),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_ProgressBillings_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_ProgressBillings PRIMARY KEY (Id),
    CONSTRAINT FK_ProgressBillings_Milestones_MilestoneId FOREIGN KEY (MilestoneId) REFERENCES projects.Milestones (Id),
    CONSTRAINT FK_ProgressBillings_Contracts_ContractId FOREIGN KEY (ContractId) REFERENCES projects.Contracts (Id),
    CONSTRAINT CK_ProgressBillings_Status CHECK (Status IN (N'Planned', N'Billed', N'Paid')),
    CONSTRAINT CK_ProgressBillings_Amount CHECK (Amount >= 0)
);
CREATE UNIQUE INDEX UX_ProgressBillings_MilestoneId ON projects.ProgressBillings (MilestoneId);
CREATE INDEX IX_ProgressBillings_ContractId ON projects.ProgressBillings (ContractId);
GO

CREATE TABLE projects.WorkItems (
    Id                  uniqueidentifier NOT NULL,
    ProjectId           uniqueidentifier NOT NULL,
    ParentId            uniqueidentifier NULL,
    WbsCode             nvarchar(30)     NOT NULL,              -- 1.2.3
    Name                nvarchar(200)    NOT NULL,
    PlannedStart        date             NOT NULL,
    PlannedEnd          date             NOT NULL,
    ActualStart         date             NULL,
    ActualEnd           date             NULL,
    PlannedEffortDays   decimal(9,2)     NOT NULL CONSTRAINT DF_WorkItems_PlannedEffortDays DEFAULT (0),
    Progress            decimal(5,4)     NOT NULL CONSTRAINT DF_WorkItems_Progress DEFAULT (0),
    AssigneeEmployeeId  uniqueidentifier NULL,                  -- → hr.Employees
    SortOrder           int              NOT NULL CONSTRAINT DF_WorkItems_SortOrder DEFAULT (0),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_WorkItems_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_WorkItems PRIMARY KEY (Id),
    CONSTRAINT FK_WorkItems_Projects_ProjectId FOREIGN KEY (ProjectId) REFERENCES projects.Projects (Id),
    CONSTRAINT FK_WorkItems_WorkItems_ParentId FOREIGN KEY (ParentId) REFERENCES projects.WorkItems (Id),
    CONSTRAINT CK_WorkItems_PlannedPeriod CHECK (PlannedEnd >= PlannedStart),
    CONSTRAINT CK_WorkItems_Progress CHECK (Progress BETWEEN 0 AND 1),
    CONSTRAINT CK_WorkItems_Effort CHECK (PlannedEffortDays >= 0)
);
CREATE UNIQUE INDEX UX_WorkItems_ProjectId_WbsCode ON projects.WorkItems (ProjectId, WbsCode);
CREATE INDEX IX_WorkItems_ParentId ON projects.WorkItems (ParentId);
CREATE INDEX IX_WorkItems_AssigneeEmployeeId ON projects.WorkItems (AssigneeEmployeeId) WHERE AssigneeEmployeeId IS NOT NULL;
GO

-- -----------------------------------------------------------------------------
-- 투입
-- -----------------------------------------------------------------------------

CREATE TABLE projects.Assignments (
    Id                  uniqueidentifier NOT NULL,
    ProjectId           uniqueidentifier NOT NULL,
    EmployeeId          uniqueidentifier NOT NULL,              -- → hr.Employees
    Role                nvarchar(20)     NOT NULL,              -- PM, PL, Developer, Designer, QA ...
    StartDate           date             NOT NULL,
    EndDate             date             NOT NULL,
    AllocationRate      decimal(5,4)     NOT NULL,
    WorkLocation        nvarchar(10)     NOT NULL CONSTRAINT DF_Assignments_WorkLocation DEFAULT (N'Office'),
    MonthlyRate         decimal(19,4)    NOT NULL,              -- 기본값은 hr.CostRates
    PurchaseContractId  uniqueidentifier NULL,                  -- 협력사 인력의 매입 계약
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Assignments_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_Assignments PRIMARY KEY (Id),
    CONSTRAINT FK_Assignments_Projects_ProjectId FOREIGN KEY (ProjectId) REFERENCES projects.Projects (Id),
    CONSTRAINT FK_Assignments_Contracts_PurchaseContractId FOREIGN KEY (PurchaseContractId) REFERENCES projects.Contracts (Id),
    CONSTRAINT CK_Assignments_AllocationRate CHECK (AllocationRate > 0 AND AllocationRate <= 1),
    CONSTRAINT CK_Assignments_Period CHECK (EndDate >= StartDate),
    CONSTRAINT CK_Assignments_WorkLocation CHECK (WorkLocation IN (N'Office', N'OnSite', N'Remote')),
    CONSTRAINT CK_Assignments_MonthlyRate CHECK (MonthlyRate >= 0)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = projects.AssignmentsHistory));
CREATE INDEX IX_Assignments_ProjectId ON projects.Assignments (ProjectId);
CREATE INDEX IX_Assignments_Employee_Period ON projects.Assignments (EmployeeId, StartDate, EndDate) INCLUDE (AllocationRate);   -- 투입률 중복 검사, 가동 현황
GO
