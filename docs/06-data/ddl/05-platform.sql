-- =============================================================================
-- Synthetix DDL 05: platform, audit, ai, outbox
-- ERD: ../erd/platform.md
-- =============================================================================

-- 필터링된 인덱스, 임시 테이블, json 타입에 필요한 옵션 (sqlcmd 기본값은 QUOTED_IDENTIFIER OFF)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- -----------------------------------------------------------------------------
-- platform
-- -----------------------------------------------------------------------------

CREATE TABLE platform.Files (
    Id                  uniqueidentifier NOT NULL,
    OriginalName        nvarchar(260)    NOT NULL,
    ContentType         nvarchar(100)    NOT NULL,
    SizeBytes           bigint           NOT NULL,
    StorageKey          nvarchar(500)    NOT NULL,              -- IFileStorage 내부 경로
    Sha256              binary(32)       NOT NULL,
    Classification      nvarchar(15)     NOT NULL,
    OwnerModule         nvarchar(30)     NOT NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Files_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    CONSTRAINT PK_Files PRIMARY KEY (Id),
    CONSTRAINT CK_Files_Classification CHECK (Classification IN (N'Public', N'Internal', N'Confidential', N'Restricted')),
    CONSTRAINT CK_Files_SizeBytes CHECK (SizeBytes >= 0)
);
CREATE UNIQUE INDEX UX_Files_StorageKey ON platform.Files (StorageKey);
GO

CREATE TABLE platform.CodeGroups (
    GroupCode           nvarchar(50)     NOT NULL,              -- JobGrade, JobTitle, Skill ...
    Name                nvarchar(100)    NOT NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_CodeGroups_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    CONSTRAINT PK_CodeGroups PRIMARY KEY (GroupCode)
);
GO

CREATE TABLE platform.CommonCodes (
    GroupCode           nvarchar(50)     NOT NULL,
    Code                nvarchar(50)     NOT NULL,
    Name                nvarchar(100)    NOT NULL,
    SortOrder           int              NOT NULL CONSTRAINT DF_CommonCodes_SortOrder DEFAULT (0),
    IsActive            bit              NOT NULL CONSTRAINT DF_CommonCodes_IsActive DEFAULT (1),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_CommonCodes_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    CONSTRAINT PK_CommonCodes PRIMARY KEY (GroupCode, Code),
    CONSTRAINT FK_CommonCodes_CodeGroups_GroupCode FOREIGN KEY (GroupCode) REFERENCES platform.CodeGroups (GroupCode)
);
GO

CREATE TABLE platform.Holidays (
    HolidayDate         date             NOT NULL,
    Name                nvarchar(100)    NOT NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Holidays_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    CONSTRAINT PK_Holidays PRIMARY KEY (HolidayDate)
);
GO

CREATE TABLE platform.Notifications (
    Id                      uniqueidentifier NOT NULL,
    RecipientUserAccountId  uniqueidentifier NOT NULL,          -- → iam.UserAccounts
    Type                    nvarchar(50)     NOT NULL,
    Title                   nvarchar(200)    NOT NULL,
    Body                    nvarchar(1000)   NOT NULL,
    Link                    nvarchar(500)    NULL,              -- 앱 내부 경로
    ReadAt                  datetimeoffset   NULL,
    CreatedAt               datetimeoffset   NOT NULL CONSTRAINT DF_Notifications_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy               uniqueidentifier NULL,
    CONSTRAINT PK_Notifications PRIMARY KEY (Id)
);
CREATE INDEX IX_Notifications_Unread ON platform.Notifications (RecipientUserAccountId, CreatedAt DESC) WHERE ReadAt IS NULL;
GO

CREATE TABLE platform.SystemSettings (
    SettingKey          nvarchar(100)    NOT NULL,
    Value               json             NOT NULL,
    UpdatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_SystemSettings_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_SystemSettings PRIMARY KEY (SettingKey)
);
GO

-- -----------------------------------------------------------------------------
-- audit (추가만 가능. 권한은 99-security.sql)
-- -----------------------------------------------------------------------------

CREATE TABLE audit.AuditLogs (
    Id                  bigint           IDENTITY(1,1) NOT NULL,
    OccurredAt          datetimeoffset   NOT NULL,
    UserAccountId       uniqueidentifier NULL,                  -- 시스템 작업이면 NULL
    Module              nvarchar(30)     NOT NULL,
    Action              nvarchar(30)     NOT NULL,              -- Create, Update, Delete, Approve ...
    EntityType          nvarchar(100)    NOT NULL,
    EntityId            nvarchar(100)    NOT NULL,
    Changes             json             NULL,                  -- 이전 값과 새 값, 민감 필드는 가린 값
    CorrelationId       nvarchar(100)    NULL,
    IpAddress           nvarchar(45)     NULL,
    CONSTRAINT PK_AuditLogs PRIMARY KEY (Id)
);
CREATE INDEX IX_AuditLogs_Entity ON audit.AuditLogs (EntityType, EntityId);
CREATE INDEX IX_AuditLogs_OccurredAt ON audit.AuditLogs (OccurredAt);
CREATE INDEX IX_AuditLogs_UserAccountId ON audit.AuditLogs (UserAccountId, OccurredAt) WHERE UserAccountId IS NOT NULL;
GO

CREATE TABLE audit.SecurityEvents (
    Id                      bigint           IDENTITY(1,1) NOT NULL,
    OccurredAt              datetimeoffset   NOT NULL,
    EventType               nvarchar(50)     NOT NULL,          -- LoginSucceeded, LoginFailed, AccountLocked ...
    UserAccountId           uniqueidentifier NULL,
    AttemptedEmployeeNumber nvarchar(20)     NULL,              -- 없는 사번으로 시도한 기록
    ClientType              nvarchar(10)     NULL,
    ClientVersion           nvarchar(20)     NULL,
    IpAddress               nvarchar(45)     NULL,
    Detail                  json             NULL,
    CONSTRAINT PK_SecurityEvents PRIMARY KEY (Id)
);
CREATE INDEX IX_SecurityEvents_OccurredAt ON audit.SecurityEvents (OccurredAt);
CREATE INDEX IX_SecurityEvents_UserAccountId ON audit.SecurityEvents (UserAccountId, OccurredAt) WHERE UserAccountId IS NOT NULL;
CREATE INDEX IX_SecurityEvents_IpAddress ON audit.SecurityEvents (IpAddress, OccurredAt) WHERE IpAddress IS NOT NULL;   -- 무차별 대입 탐지
GO

CREATE TABLE audit.SensitiveDataAccessLogs (
    Id                  bigint           IDENTITY(1,1) NOT NULL,
    OccurredAt          datetimeoffset   NOT NULL,
    UserAccountId       uniqueidentifier NOT NULL,
    EntityType          nvarchar(100)    NOT NULL,
    EntityId            nvarchar(100)    NOT NULL,
    FieldName           nvarchar(100)    NOT NULL,
    Reason              nvarchar(500)    NOT NULL,              -- 열람 사유
    CONSTRAINT PK_SensitiveDataAccessLogs PRIMARY KEY (Id)
);
CREATE INDEX IX_SensitiveDataAccessLogs_Entity ON audit.SensitiveDataAccessLogs (EntityType, EntityId);
CREATE INDEX IX_SensitiveDataAccessLogs_UserAccountId ON audit.SensitiveDataAccessLogs (UserAccountId, OccurredAt);
GO

-- -----------------------------------------------------------------------------
-- ai
-- -----------------------------------------------------------------------------

CREATE TABLE ai.GuardRules (
    Id                  uniqueidentifier NOT NULL,
    Stage               nvarchar(10)     NOT NULL,
    RuleType            nvarchar(20)     NOT NULL,
    Pattern             nvarchar(max)    NOT NULL,
    Action              nvarchar(10)     NOT NULL,
    IsActive            bit              NOT NULL CONSTRAINT DF_GuardRules_IsActive DEFAULT (1),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_GuardRules_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_GuardRules PRIMARY KEY (Id),
    CONSTRAINT CK_GuardRules_Stage CHECK (Stage IN (N'Input', N'Output')),
    CONSTRAINT CK_GuardRules_RuleType CHECK (RuleType IN (N'Keyword', N'Regex', N'Classification')),
    CONSTRAINT CK_GuardRules_Action CHECK (Action IN (N'Block', N'Mask', N'Warn'))
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = ai.GuardRulesHistory));
GO

CREATE TABLE ai.ProviderSettings (
    Id                  uniqueidentifier NOT NULL,
    Alias               nvarchar(50)     NOT NULL,              -- local-default, local-embedding ...
    Provider            nvarchar(20)     NOT NULL,              -- Ollama, vLLM, AzureOpenAI ...
    TrustLevel          nvarchar(20)     NOT NULL,
    Endpoint            nvarchar(500)    NOT NULL,
    Model               nvarchar(200)    NOT NULL,
    EncryptedApiKey     varbinary(1024)  NULL,
    IsEnabled           bit              NOT NULL CONSTRAINT DF_ProviderSettings_IsEnabled DEFAULT (0),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_ProviderSettings_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_ProviderSettings PRIMARY KEY (Id),
    CONSTRAINT CK_ProviderSettings_TrustLevel CHECK (TrustLevel IN (N'OnPremises', N'PrivateCloud', N'PublicCloud'))
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = ai.ProviderSettingsHistory));   -- 외부 공급자를 켜고 끈 이력
CREATE UNIQUE INDEX UX_ProviderSettings_Alias ON ai.ProviderSettings (Alias);
GO

CREATE TABLE ai.Interactions (
    Id                    uniqueidentifier NOT NULL,
    Purpose               nvarchar(20)     NOT NULL,            -- AI-PRJ-01 ...
    UserAccountId         uniqueidentifier NOT NULL,            -- → iam.UserAccounts
    ProviderSettingId     uniqueidentifier NULL,                -- 정책상 차단되면 NULL
    PromptTemplateVersion nvarchar(50)     NOT NULL,
    MaskedInput           nvarchar(max)    NULL,                -- 원문은 저장하지 않음
    MaskedOutput          nvarchar(max)    NULL,
    DetectedEntities      json             NULL,                -- 유형별 개수
    PolicyDecision        nvarchar(15)     NOT NULL,
    PolicyReason          nvarchar(500)    NULL,
    InputTokens           int              NULL,
    OutputTokens          int              NULL,
    LatencyMs             int              NULL,
    Feedback              nvarchar(10)     NULL,
    CreatedAt             datetimeoffset   NOT NULL CONSTRAINT DF_Interactions_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt             datetimeoffset   NULL,                -- 피드백을 받을 때 갱신
    CONSTRAINT PK_Interactions PRIMARY KEY (Id),
    CONSTRAINT FK_Interactions_ProviderSettings_ProviderSettingId FOREIGN KEY (ProviderSettingId) REFERENCES ai.ProviderSettings (Id),
    CONSTRAINT CK_Interactions_PolicyDecision CHECK (PolicyDecision IN (N'Allowed', N'Pseudonymized', N'Blocked')),
    CONSTRAINT CK_Interactions_Feedback CHECK (Feedback IS NULL OR Feedback IN (N'Accepted', N'Edited', N'Rejected'))
);
CREATE INDEX IX_Interactions_Purpose ON ai.Interactions (Purpose, CreatedAt);
CREATE INDEX IX_Interactions_UserAccountId ON ai.Interactions (UserAccountId, CreatedAt);
GO

CREATE TABLE ai.DocumentChunks (
    Id                  uniqueidentifier NOT NULL,
    SourceType          nvarchar(20)     NOT NULL,              -- Contract, Policy, Manual ...
    SourceId            uniqueidentifier NOT NULL,
    ChunkIndex          int              NOT NULL,
    Content             nvarchar(max)    NOT NULL,
    Embedding           vector(1024)     NOT NULL,              -- 차원은 임베딩 모델에 맞춤 (가정: 1024)
    Classification      nvarchar(15)     NOT NULL,
    OwningUnitId        uniqueidentifier NULL,                  -- 권한 필터
    ProjectId           uniqueidentifier NULL,                  -- 권한 필터
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_DocumentChunks_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_DocumentChunks PRIMARY KEY (Id),
    CONSTRAINT CK_DocumentChunks_Classification CHECK (Classification IN (N'Public', N'Internal', N'Confidential'))   -- Restricted는 색인하지 않음
);
CREATE UNIQUE INDEX UX_DocumentChunks_Source ON ai.DocumentChunks (SourceType, SourceId, ChunkIndex);
-- 벡터 인덱스(CREATE VECTOR INDEX)는 Phase 4에서 SQL Server 2025의 지원 범위를 확인한 뒤 추가합니다.
GO

-- -----------------------------------------------------------------------------
-- outbox
-- -----------------------------------------------------------------------------

CREATE TABLE outbox.OutboxMessages (
    Id                  uniqueidentifier NOT NULL,
    OccurredAt          datetimeoffset   NOT NULL,
    SourceModule        nvarchar(30)     NOT NULL,
    EventType           nvarchar(200)    NOT NULL,
    Payload             json             NOT NULL,
    ProcessedAt         datetimeoffset   NULL,
    Attempts            int              NOT NULL CONSTRAINT DF_OutboxMessages_Attempts DEFAULT (0),
    LastError           nvarchar(2000)   NULL,
    CONSTRAINT PK_OutboxMessages PRIMARY KEY (Id)
);
CREATE INDEX IX_OutboxMessages_Pending ON outbox.OutboxMessages (OccurredAt) WHERE ProcessedAt IS NULL;
GO

CREATE TABLE outbox.InboxMessages (
    MessageId           uniqueidentifier NOT NULL,              -- OutboxMessages.Id
    Consumer            nvarchar(200)    NOT NULL,              -- 처리한 핸들러 이름
    ProcessedAt         datetimeoffset   NOT NULL,
    CONSTRAINT PK_InboxMessages PRIMARY KEY (MessageId, Consumer)   -- 같은 이벤트를 두 번 처리하지 않음
);
GO
