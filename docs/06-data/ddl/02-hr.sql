-- =============================================================================
-- Synthetix DDL 02: hr (HR 모듈, 조직 포함)
-- ERD: ../erd/hr.md
-- =============================================================================

-- 필터링된 인덱스, 임시 테이블, json 타입에 필요한 옵션 (sqlcmd 기본값은 QUOTED_IDENTIFIER OFF)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- -----------------------------------------------------------------------------
-- 조직
-- -----------------------------------------------------------------------------

CREATE TABLE hr.OrgUnits (
    Id                  uniqueidentifier NOT NULL,
    Code                nvarchar(20)     NOT NULL,              -- 변경 불가, 코스트센터 키
    Name                nvarchar(100)    NOT NULL,
    Type                nvarchar(20)     NOT NULL,
    ParentId            uniqueidentifier NULL,
    Node                hierarchyid      NOT NULL,
    SortOrder           int              NOT NULL CONSTRAINT DF_OrgUnits_SortOrder DEFAULT (0),
    Status              nvarchar(10)     NOT NULL CONSTRAINT DF_OrgUnits_Status DEFAULT (N'Active'),
    ClosedDate          date             NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_OrgUnits_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_OrgUnits PRIMARY KEY (Id),
    CONSTRAINT FK_OrgUnits_OrgUnits_ParentId FOREIGN KEY (ParentId) REFERENCES hr.OrgUnits (Id),
    CONSTRAINT CK_OrgUnits_Type CHECK (Type IN (N'Company', N'Division', N'Department', N'Team')),
    CONSTRAINT CK_OrgUnits_Status CHECK (Status IN (N'Active', N'Closed')),
    CONSTRAINT CK_OrgUnits_RootIsCompany CHECK ((Type = N'Company' AND ParentId IS NULL) OR (Type <> N'Company' AND ParentId IS NOT NULL)),
    CONSTRAINT CK_OrgUnits_ClosedDate CHECK ((Status = N'Closed' AND ClosedDate IS NOT NULL) OR (Status = N'Active' AND ClosedDate IS NULL))
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = hr.OrgUnitsHistory));
CREATE UNIQUE INDEX UX_OrgUnits_Code ON hr.OrgUnits (Code);
CREATE UNIQUE INDEX UX_OrgUnits_Node ON hr.OrgUnits (Node);
CREATE UNIQUE INDEX UX_OrgUnits_Root ON hr.OrgUnits (ParentId) WHERE ParentId IS NULL;   -- 루트는 하나뿐
CREATE INDEX IX_OrgUnits_ParentId ON hr.OrgUnits (ParentId, SortOrder);
GO

-- -----------------------------------------------------------------------------
-- 직원 (OrgMemberships가 참조하므로 먼저 만듦)
-- -----------------------------------------------------------------------------

CREATE TABLE hr.Employees (
    Id                    uniqueidentifier NOT NULL,
    EmployeeNumber        nvarchar(20)     NOT NULL,
    Name                  nvarchar(50)     NOT NULL,            -- Confidential
    Email                 nvarchar(200)    NULL,                -- Confidential
    Phone                 nvarchar(20)     NULL,                -- Confidential
    JobGradeCode          nvarchar(50)     NULL,                -- → platform.CommonCodes (JobGrade)
    EmploymentType        nvarchar(20)     NOT NULL,
    PartnerId             uniqueidentifier NULL,                -- → projects.Partners (협력사 인력)
    HireDate              date             NOT NULL,
    TerminationDate       date             NULL,
    Status                nvarchar(20)     NOT NULL CONSTRAINT DF_Employees_Status DEFAULT (N'Active'),
    RrnEncrypted          varbinary(256)   NULL,                -- Restricted, AES-256-GCM
    RrnBlindIndex         binary(32)       NULL,                -- HMAC, 일치 검색용
    BankAccountEncrypted  varbinary(256)   NULL,                -- Restricted
    IsDeleted             bit              NOT NULL CONSTRAINT DF_Employees_IsDeleted DEFAULT (0),
    CreatedAt             datetimeoffset   NOT NULL CONSTRAINT DF_Employees_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy             uniqueidentifier NULL,
    UpdatedAt             datetimeoffset   NULL,
    UpdatedBy             uniqueidentifier NULL,
    RowVersion            rowversion       NOT NULL,
    PeriodStart           datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd             datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_Employees PRIMARY KEY (Id),
    CONSTRAINT CK_Employees_EmploymentType CHECK (EmploymentType IN (N'Regular', N'FixedTerm', N'Dispatched', N'Freelancer', N'PartnerStaff')),
    CONSTRAINT CK_Employees_Status CHECK (Status IN (N'Active', N'OnLeave', N'Terminated')),
    CONSTRAINT CK_Employees_PartnerStaff CHECK (EmploymentType <> N'PartnerStaff' OR PartnerId IS NOT NULL),
    CONSTRAINT CK_Employees_Termination CHECK (TerminationDate IS NULL OR TerminationDate >= HireDate)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = hr.EmployeesHistory));
CREATE UNIQUE INDEX UX_Employees_EmployeeNumber ON hr.Employees (EmployeeNumber);
CREATE INDEX IX_Employees_RrnBlindIndex ON hr.Employees (RrnBlindIndex) WHERE RrnBlindIndex IS NOT NULL;
CREATE INDEX IX_Employees_PartnerId ON hr.Employees (PartnerId) WHERE PartnerId IS NOT NULL;
GO

CREATE TABLE hr.OrgMemberships (
    Id                  uniqueidentifier NOT NULL,
    EmployeeId          uniqueidentifier NOT NULL,
    OrgUnitId           uniqueidentifier NOT NULL,
    IsPrimary           bit              NOT NULL,
    JobTitleCode        nvarchar(50)     NULL,                  -- → platform.CommonCodes (JobTitle)
    IsHead              bit              NOT NULL CONSTRAINT DF_OrgMemberships_IsHead DEFAULT (0),
    StartDate           date             NOT NULL,
    EndDate             date             NULL,                  -- NULL이면 현재 소속
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_OrgMemberships_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_OrgMemberships PRIMARY KEY (Id),
    CONSTRAINT FK_OrgMemberships_Employees_EmployeeId FOREIGN KEY (EmployeeId) REFERENCES hr.Employees (Id),
    CONSTRAINT FK_OrgMemberships_OrgUnits_OrgUnitId FOREIGN KEY (OrgUnitId) REFERENCES hr.OrgUnits (Id),
    CONSTRAINT CK_OrgMemberships_Period CHECK (EndDate IS NULL OR EndDate >= StartDate)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = hr.OrgMembershipsHistory));
CREATE UNIQUE INDEX UX_OrgMemberships_CurrentPrimary ON hr.OrgMemberships (EmployeeId) WHERE IsPrimary = 1 AND EndDate IS NULL;  -- 현재 주 소속은 하나
CREATE UNIQUE INDEX UX_OrgMemberships_CurrentHead ON hr.OrgMemberships (OrgUnitId) WHERE IsHead = 1 AND EndDate IS NULL;        -- 현재 조직장은 한 명
CREATE INDEX IX_OrgMemberships_OrgUnitId ON hr.OrgMemberships (OrgUnitId) INCLUDE (EmployeeId, IsPrimary, IsHead) WHERE EndDate IS NULL;
GO

-- -----------------------------------------------------------------------------
-- 조직개편
-- -----------------------------------------------------------------------------

CREATE TABLE hr.OrgChangePlans (
    Id                  uniqueidentifier NOT NULL,
    Title               nvarchar(200)    NOT NULL,
    EffectiveDate       date             NOT NULL,
    Status              nvarchar(20)     NOT NULL CONSTRAINT DF_OrgChangePlans_Status DEFAULT (N'Draft'),
    AppliedAt           datetimeoffset   NULL,
    FailureReason       nvarchar(1000)   NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_OrgChangePlans_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_OrgChangePlans PRIMARY KEY (Id),
    CONSTRAINT CK_OrgChangePlans_Status CHECK (Status IN (N'Draft', N'Scheduled', N'Applied', N'Cancelled', N'Failed'))
);
CREATE INDEX IX_OrgChangePlans_Scheduled ON hr.OrgChangePlans (EffectiveDate) WHERE Status = N'Scheduled';
GO

CREATE TABLE hr.OrgChangeItems (
    Id                  uniqueidentifier NOT NULL,
    PlanId              uniqueidentifier NOT NULL,
    Seq                 int              NOT NULL,
    ItemType            nvarchar(20)     NOT NULL,
    TargetUnitId        uniqueidentifier NULL,
    TargetEmployeeId    uniqueidentifier NULL,
    Payload             json             NOT NULL,              -- 항목별 매개변수
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_OrgChangeItems_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    CONSTRAINT PK_OrgChangeItems PRIMARY KEY (Id),
    CONSTRAINT FK_OrgChangeItems_OrgChangePlans_PlanId FOREIGN KEY (PlanId) REFERENCES hr.OrgChangePlans (Id) ON DELETE CASCADE,
    CONSTRAINT CK_OrgChangeItems_ItemType CHECK (ItemType IN (N'CreateUnit', N'RenameUnit', N'MoveUnit', N'CloseUnit', N'MoveMember', N'AddConcurrent', N'EndConcurrent', N'SetHead', N'UnsetHead'))
);
CREATE UNIQUE INDEX UX_OrgChangeItems_PlanId_Seq ON hr.OrgChangeItems (PlanId, Seq);
GO

-- -----------------------------------------------------------------------------
-- 직원 부속 정보
-- -----------------------------------------------------------------------------

CREATE TABLE hr.EmploymentContracts (
    Id                  uniqueidentifier NOT NULL,
    EmployeeId          uniqueidentifier NOT NULL,
    ContractType        nvarchar(20)     NOT NULL,
    StartDate           date             NOT NULL,
    EndDate             date             NULL,
    RenewalOfId         uniqueidentifier NULL,                  -- 갱신 이전 계약 (기간제 누적 기간 계산)
    FileId              uniqueidentifier NULL,                  -- → platform.Files
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_EmploymentContracts_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_EmploymentContracts PRIMARY KEY (Id),
    CONSTRAINT FK_EmploymentContracts_Employees_EmployeeId FOREIGN KEY (EmployeeId) REFERENCES hr.Employees (Id),
    CONSTRAINT FK_EmploymentContracts_EmploymentContracts_RenewalOfId FOREIGN KEY (RenewalOfId) REFERENCES hr.EmploymentContracts (Id),
    CONSTRAINT CK_EmploymentContracts_ContractType CHECK (ContractType IN (N'Regular', N'FixedTerm', N'Freelance')),
    CONSTRAINT CK_EmploymentContracts_Period CHECK (EndDate IS NULL OR EndDate >= StartDate)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = hr.EmploymentContractsHistory));
CREATE INDEX IX_EmploymentContracts_EmployeeId ON hr.EmploymentContracts (EmployeeId, StartDate);
GO

CREATE TABLE hr.DispatchInfos (
    EmployeeId          uniqueidentifier NOT NULL,
    DispatchAgencyId    uniqueidentifier NOT NULL,              -- → projects.Partners
    JobCategory         nvarchar(100)    NOT NULL,              -- 파견 허용 업무
    StartDate           date             NOT NULL,
    PlannedEndDate      date             NOT NULL,
    ExtendedEndDate     date             NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_DispatchInfos_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_DispatchInfos PRIMARY KEY (EmployeeId),
    CONSTRAINT FK_DispatchInfos_Employees_EmployeeId FOREIGN KEY (EmployeeId) REFERENCES hr.Employees (Id),
    CONSTRAINT CK_DispatchInfos_Period CHECK (PlannedEndDate >= StartDate AND (ExtendedEndDate IS NULL OR ExtendedEndDate >= PlannedEndDate))
);
GO

CREATE TABLE hr.EmployeeSkills (
    EmployeeId          uniqueidentifier NOT NULL,
    SkillCode           nvarchar(50)     NOT NULL,              -- → platform.CommonCodes (Skill)
    Proficiency         tinyint          NOT NULL,
    Years               decimal(4,1)     NOT NULL CONSTRAINT DF_EmployeeSkills_Years DEFAULT (0),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_EmployeeSkills_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    CONSTRAINT PK_EmployeeSkills PRIMARY KEY (EmployeeId, SkillCode),
    CONSTRAINT FK_EmployeeSkills_Employees_EmployeeId FOREIGN KEY (EmployeeId) REFERENCES hr.Employees (Id),
    CONSTRAINT CK_EmployeeSkills_Proficiency CHECK (Proficiency BETWEEN 1 AND 5),
    CONSTRAINT CK_EmployeeSkills_Years CHECK (Years >= 0)
);
CREATE INDEX IX_EmployeeSkills_SkillCode ON hr.EmployeeSkills (SkillCode, Proficiency);   -- 인력 추천 검색
GO

CREATE TABLE hr.CareerHistories (
    Id                  uniqueidentifier NOT NULL,
    EmployeeId          uniqueidentifier NOT NULL,
    ProjectName         nvarchar(200)    NOT NULL,
    ClientName          nvarchar(200)    NULL,
    Role                nvarchar(50)     NULL,
    StartDate           date             NOT NULL,
    EndDate             date             NULL,
    Description         nvarchar(max)    NULL,
    Source              nvarchar(20)     NOT NULL CONSTRAINT DF_CareerHistories_Source DEFAULT (N'Manual'),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_CareerHistories_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_CareerHistories PRIMARY KEY (Id),
    CONSTRAINT FK_CareerHistories_Employees_EmployeeId FOREIGN KEY (EmployeeId) REFERENCES hr.Employees (Id),
    CONSTRAINT CK_CareerHistories_Source CHECK (Source IN (N'Manual', N'AiExtracted')),
    CONSTRAINT CK_CareerHistories_Period CHECK (EndDate IS NULL OR EndDate >= StartDate)
);
CREATE INDEX IX_CareerHistories_EmployeeId ON hr.CareerHistories (EmployeeId);
GO

CREATE TABLE hr.CostRates (
    Id                  uniqueidentifier NOT NULL,
    EmployeeId          uniqueidentifier NOT NULL,
    MonthlyRate         decimal(19,4)    NOT NULL,              -- Confidential
    Currency            nvarchar(3)      NOT NULL CONSTRAINT DF_CostRates_Currency DEFAULT (N'KRW'),
    ValidFrom           date             NOT NULL,
    ValidTo             date             NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_CostRates_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_CostRates PRIMARY KEY (Id),
    CONSTRAINT FK_CostRates_Employees_EmployeeId FOREIGN KEY (EmployeeId) REFERENCES hr.Employees (Id),
    CONSTRAINT CK_CostRates_MonthlyRate CHECK (MonthlyRate >= 0),
    CONSTRAINT CK_CostRates_Period CHECK (ValidTo IS NULL OR ValidTo >= ValidFrom)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = hr.CostRatesHistory));
CREATE INDEX IX_CostRates_EmployeeId ON hr.CostRates (EmployeeId, ValidFrom);   -- 기간 겹침 검사는 애플리케이션에서
GO

CREATE TABLE hr.ExpiryAlerts (
    Id                  uniqueidentifier NOT NULL,
    EmployeeId          uniqueidentifier NOT NULL,
    RuleId              nvarchar(10)     NOT NULL,
    DueDate             date             NOT NULL,              -- 만료일 또는 법정 제한 도달일
    StageDays           int              NOT NULL,              -- 90, 60, 30, 14, 0
    Status              nvarchar(20)     NOT NULL CONSTRAINT DF_ExpiryAlerts_Status DEFAULT (N'Open'),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_ExpiryAlerts_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_ExpiryAlerts PRIMARY KEY (Id),
    CONSTRAINT FK_ExpiryAlerts_Employees_EmployeeId FOREIGN KEY (EmployeeId) REFERENCES hr.Employees (Id),
    CONSTRAINT CK_ExpiryAlerts_RuleId CHECK (RuleId IN (N'HR-R01', N'HR-R02', N'HR-R03', N'HR-R04')),
    CONSTRAINT CK_ExpiryAlerts_Status CHECK (Status IN (N'Open', N'Acknowledged', N'Resolved'))
);
CREATE UNIQUE INDEX UX_ExpiryAlerts_Stage ON hr.ExpiryAlerts (EmployeeId, RuleId, DueDate, StageDays);   -- 매일 실행해도 중복 생성 방지
CREATE INDEX IX_ExpiryAlerts_Open ON hr.ExpiryAlerts (DueDate) WHERE Status = N'Open';
GO
