-- =============================================================================
-- Synthetix DDL 01: iam (Identity 모듈)
-- ERD: ../erd/identity.md
-- =============================================================================

-- 필터링된 인덱스, 임시 테이블, json 타입에 필요한 옵션 (sqlcmd 기본값은 QUOTED_IDENTIFIER OFF)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- -----------------------------------------------------------------------------
-- 계정, MFA, 세션
-- -----------------------------------------------------------------------------

CREATE TABLE iam.UserAccounts (
    Id                  uniqueidentifier NOT NULL,
    EmployeeId          uniqueidentifier NOT NULL,              -- → hr.Employees (값 참조)
    EmployeeNumber      nvarchar(20)     NOT NULL,              -- 로그인 ID
    PasswordHash        nvarchar(500)    NULL,                  -- 초기 비밀번호를 발급하기 전에는 NULL
    SecurityStamp       nvarchar(100)    NOT NULL,              -- 바뀌면 모든 세션이 무효화됨
    Status              nvarchar(20)     NOT NULL,
    MustChangePassword  bit              NOT NULL CONSTRAINT DF_UserAccounts_MustChangePassword DEFAULT (1),
    AccessFailedCount   int              NOT NULL CONSTRAINT DF_UserAccounts_AccessFailedCount DEFAULT (0),
    LockoutEnd          datetimeoffset   NULL,
    LastLoginAt         datetimeoffset   NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_UserAccounts_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_UserAccounts PRIMARY KEY (Id),
    CONSTRAINT CK_UserAccounts_Status CHECK (Status IN (N'Pending', N'Active', N'Disabled')),
    CONSTRAINT CK_UserAccounts_AccessFailedCount CHECK (AccessFailedCount >= 0)
);
CREATE UNIQUE INDEX UX_UserAccounts_EmployeeNumber ON iam.UserAccounts (EmployeeNumber);
CREATE UNIQUE INDEX UX_UserAccounts_EmployeeId ON iam.UserAccounts (EmployeeId);
GO

CREATE TABLE iam.MfaAuthenticators (
    Id                  uniqueidentifier NOT NULL,
    UserAccountId       uniqueidentifier NOT NULL,
    EncryptedSecret     varbinary(512)   NOT NULL,              -- Data Protection으로 암호화한 TOTP 비밀키
    LastUsedTimeStep    bigint           NULL,                  -- 코드 재사용 방지
    EnrolledAt          datetimeoffset   NOT NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_MfaAuthenticators_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_MfaAuthenticators PRIMARY KEY (Id),
    CONSTRAINT FK_MfaAuthenticators_UserAccounts_UserAccountId FOREIGN KEY (UserAccountId) REFERENCES iam.UserAccounts (Id)
);
CREATE UNIQUE INDEX UX_MfaAuthenticators_UserAccountId ON iam.MfaAuthenticators (UserAccountId);
GO

CREATE TABLE iam.RecoveryCodes (
    Id                  uniqueidentifier NOT NULL,
    UserAccountId       uniqueidentifier NOT NULL,
    CodeHash            binary(32)       NOT NULL,
    UsedAt              datetimeoffset   NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_RecoveryCodes_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    CONSTRAINT PK_RecoveryCodes PRIMARY KEY (Id),
    CONSTRAINT FK_RecoveryCodes_UserAccounts_UserAccountId FOREIGN KEY (UserAccountId) REFERENCES iam.UserAccounts (Id)
);
CREATE INDEX IX_RecoveryCodes_UserAccountId ON iam.RecoveryCodes (UserAccountId);
GO

CREATE TABLE iam.MfaChallenges (
    Id                  uniqueidentifier NOT NULL,
    UserAccountId       uniqueidentifier NOT NULL,
    TokenHash           binary(32)       NOT NULL,              -- mfaToken의 SHA-256
    NextStep            nvarchar(30)     NOT NULL,
    PendingSecret       varbinary(512)   NULL,                  -- TOTP 등록 중 임시 비밀키 (암호화)
    FailedAttempts      int              NOT NULL CONSTRAINT DF_MfaChallenges_FailedAttempts DEFAULT (0),
    ExpiresAt           datetimeoffset   NOT NULL,              -- 발급 후 5분
    ConsumedAt          datetimeoffset   NULL,
    IpAddress           nvarchar(45)     NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_MfaChallenges_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_MfaChallenges PRIMARY KEY (Id),
    CONSTRAINT FK_MfaChallenges_UserAccounts_UserAccountId FOREIGN KEY (UserAccountId) REFERENCES iam.UserAccounts (Id),
    CONSTRAINT CK_MfaChallenges_NextStep CHECK (NextStep IN (N'MfaRequired', N'MfaEnrollmentRequired')),
    CONSTRAINT CK_MfaChallenges_FailedAttempts CHECK (FailedAttempts BETWEEN 0 AND 5)
);
CREATE UNIQUE INDEX UX_MfaChallenges_TokenHash ON iam.MfaChallenges (TokenHash);
CREATE INDEX IX_MfaChallenges_ExpiresAt ON iam.MfaChallenges (ExpiresAt);   -- 만료 데이터 정리
GO

CREATE TABLE iam.Sessions (
    Id                  uniqueidentifier NOT NULL,              -- JWT의 sid
    UserAccountId       uniqueidentifier NOT NULL,
    ClientType          nvarchar(10)     NOT NULL,
    ClientVersion       nvarchar(20)     NOT NULL,
    IpAddress           nvarchar(45)     NULL,
    StartedAt           datetimeoffset   NOT NULL,
    AbsoluteExpiresAt   datetimeoffset   NOT NULL,              -- 세션 시작 후 최대 12시간
    LastSeenAt          datetimeoffset   NOT NULL,
    RevokedAt           datetimeoffset   NULL,
    RevokedReason       nvarchar(100)    NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Sessions_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_Sessions PRIMARY KEY (Id),
    CONSTRAINT FK_Sessions_UserAccounts_UserAccountId FOREIGN KEY (UserAccountId) REFERENCES iam.UserAccounts (Id),
    CONSTRAINT CK_Sessions_ClientType CHECK (ClientType IN (N'desktop', N'web')),
    CONSTRAINT CK_Sessions_Expiry CHECK (AbsoluteExpiresAt > StartedAt)
);
CREATE INDEX IX_Sessions_UserAccountId_Active ON iam.Sessions (UserAccountId) WHERE RevokedAt IS NULL;
GO

CREATE TABLE iam.RefreshTokens (
    Id                  uniqueidentifier NOT NULL,
    SessionId           uniqueidentifier NOT NULL,
    TokenHash           binary(32)       NOT NULL,
    IssuedAt            datetimeoffset   NOT NULL,
    IdleExpiresAt       datetimeoffset   NOT NULL,              -- 발급 후 2시간
    UsedAt              datetimeoffset   NULL,                  -- 회전되면 채워짐. 다시 들어오면 재사용 탐지
    ReplacedById        uniqueidentifier NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_RefreshTokens_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion          rowversion       NOT NULL,
    CONSTRAINT PK_RefreshTokens PRIMARY KEY (Id),
    CONSTRAINT FK_RefreshTokens_Sessions_SessionId FOREIGN KEY (SessionId) REFERENCES iam.Sessions (Id),
    CONSTRAINT FK_RefreshTokens_RefreshTokens_ReplacedById FOREIGN KEY (ReplacedById) REFERENCES iam.RefreshTokens (Id)
);
CREATE UNIQUE INDEX UX_RefreshTokens_TokenHash ON iam.RefreshTokens (TokenHash);
CREATE INDEX IX_RefreshTokens_SessionId ON iam.RefreshTokens (SessionId);
GO

-- -----------------------------------------------------------------------------
-- 역할과 권한
-- -----------------------------------------------------------------------------

CREATE TABLE iam.Permissions (
    Code                nvarchar(100)    NOT NULL,              -- 예: projects.contracts.read (코드에서 동기화)
    Module              nvarchar(30)     NOT NULL,
    Description         nvarchar(500)    NOT NULL,
    IsSensitive         bit              NOT NULL CONSTRAINT DF_Permissions_IsSensitive DEFAULT (0),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Permissions_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt           datetimeoffset   NULL,
    CONSTRAINT PK_Permissions PRIMARY KEY (Code)
);
GO

CREATE TABLE iam.Roles (
    Id                  uniqueidentifier NOT NULL,
    Name                nvarchar(50)     NOT NULL,
    Description         nvarchar(500)    NULL,
    IsSystem            bit              NOT NULL CONSTRAINT DF_Roles_IsSystem DEFAULT (0),
    IsDelegable         bit              NOT NULL CONSTRAINT DF_Roles_IsDelegable DEFAULT (0),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_Roles_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_Roles PRIMARY KEY (Id)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = iam.RolesHistory));
CREATE UNIQUE INDEX UX_Roles_Name ON iam.Roles (Name);
GO

CREATE TABLE iam.RolePermissions (
    RoleId              uniqueidentifier NOT NULL,
    PermissionCode      nvarchar(100)    NOT NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_RolePermissions_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_RolePermissions PRIMARY KEY (RoleId, PermissionCode),
    CONSTRAINT FK_RolePermissions_Roles_RoleId FOREIGN KEY (RoleId) REFERENCES iam.Roles (Id),
    CONSTRAINT FK_RolePermissions_Permissions_PermissionCode FOREIGN KEY (PermissionCode) REFERENCES iam.Permissions (Code)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = iam.RolePermissionsHistory));
CREATE INDEX IX_RolePermissions_PermissionCode ON iam.RolePermissions (PermissionCode);
GO

CREATE TABLE iam.RoleAssignments (
    Id                  uniqueidentifier NOT NULL,
    SubjectType         nvarchar(10)     NOT NULL,
    SubjectId           uniqueidentifier NOT NULL,              -- UserAccounts.Id 또는 OrgUnits.Id (대상에 따라 다르므로 FK 없음)
    IncludeDescendants  bit              NOT NULL CONSTRAINT DF_RoleAssignments_IncludeDescendants DEFAULT (0),
    RoleId              uniqueidentifier NOT NULL,
    DataScope           nvarchar(30)     NOT NULL,
    ValidFrom           date             NOT NULL,
    ValidTo             date             NULL,
    Reason              nvarchar(500)    NOT NULL,
    RevokedAt           datetimeoffset   NULL,
    RevokedBy           uniqueidentifier NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_RoleAssignments_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,                  -- 부여자 (GrantedBy)
    UpdatedAt           datetimeoffset   NULL,
    UpdatedBy           uniqueidentifier NULL,
    RowVersion          rowversion       NOT NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_RoleAssignments PRIMARY KEY (Id),
    CONSTRAINT FK_RoleAssignments_Roles_RoleId FOREIGN KEY (RoleId) REFERENCES iam.Roles (Id),
    CONSTRAINT CK_RoleAssignments_SubjectType CHECK (SubjectType IN (N'User', N'OrgUnit', N'OrgHead')),
    CONSTRAINT CK_RoleAssignments_DataScope CHECK (DataScope IN (N'All', N'OwnUnit', N'OwnUnitAndDescendants', N'SpecifiedUnits', N'AssignedProjects', N'Self')),
    CONSTRAINT CK_RoleAssignments_UserNoDescendants CHECK (SubjectType <> N'User' OR IncludeDescendants = 0),
    CONSTRAINT CK_RoleAssignments_ValidPeriod CHECK (ValidTo IS NULL OR ValidTo >= ValidFrom)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = iam.RoleAssignmentsHistory));
CREATE INDEX IX_RoleAssignments_Subject_Active ON iam.RoleAssignments (SubjectType, SubjectId) WHERE RevokedAt IS NULL;
CREATE INDEX IX_RoleAssignments_RoleId ON iam.RoleAssignments (RoleId);
GO

CREATE TABLE iam.RoleAssignmentScopeUnits (
    RoleAssignmentId    uniqueidentifier NOT NULL,
    OrgUnitId           uniqueidentifier NOT NULL,              -- → hr.OrgUnits (값 참조)
    IncludeDescendants  bit              NOT NULL CONSTRAINT DF_RoleAssignmentScopeUnits_IncludeDescendants DEFAULT (1),
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_RoleAssignmentScopeUnits_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_RoleAssignmentScopeUnits PRIMARY KEY (RoleAssignmentId, OrgUnitId),
    CONSTRAINT FK_RoleAssignmentScopeUnits_RoleAssignments_RoleAssignmentId FOREIGN KEY (RoleAssignmentId) REFERENCES iam.RoleAssignments (Id)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = iam.RoleAssignmentScopeUnitsHistory));
GO

CREATE TABLE iam.RoleAssignmentExclusions (
    RoleAssignmentId    uniqueidentifier NOT NULL,
    UserAccountId       uniqueidentifier NOT NULL,
    Reason              nvarchar(500)    NOT NULL,
    CreatedAt           datetimeoffset   NOT NULL CONSTRAINT DF_RoleAssignmentExclusions_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy           uniqueidentifier NULL,
    PeriodStart         datetime2        GENERATED ALWAYS AS ROW START NOT NULL,
    PeriodEnd           datetime2        GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (PeriodStart, PeriodEnd),
    CONSTRAINT PK_RoleAssignmentExclusions PRIMARY KEY (RoleAssignmentId, UserAccountId),
    CONSTRAINT FK_RoleAssignmentExclusions_RoleAssignments_RoleAssignmentId FOREIGN KEY (RoleAssignmentId) REFERENCES iam.RoleAssignments (Id),
    CONSTRAINT FK_RoleAssignmentExclusions_UserAccounts_UserAccountId FOREIGN KEY (UserAccountId) REFERENCES iam.UserAccounts (Id)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = iam.RoleAssignmentExclusionsHistory));
CREATE INDEX IX_RoleAssignmentExclusions_UserAccountId ON iam.RoleAssignmentExclusions (UserAccountId);
GO

-- -----------------------------------------------------------------------------
-- 조직 프로젝션 (hr 통합 이벤트로 갱신. 원본은 hr.OrgUnits, hr.OrgMemberships)
-- 이벤트 도착 순서가 어긋날 수 있으므로 FK를 걸지 않습니다.
-- -----------------------------------------------------------------------------

CREATE TABLE iam.OrgUnits (
    Id                  uniqueidentifier NOT NULL,
    ParentId            uniqueidentifier NULL,
    Node                hierarchyid      NOT NULL,
    Status              nvarchar(10)     NOT NULL,
    SourceVersion       bigint           NOT NULL,              -- 마지막으로 반영한 이벤트 순번 (오래된 이벤트 무시)
    CONSTRAINT PK_OrgUnits PRIMARY KEY (Id),
    CONSTRAINT CK_OrgUnits_Status CHECK (Status IN (N'Active', N'Closed'))
);
CREATE INDEX IX_OrgUnits_Node ON iam.OrgUnits (Node);
GO

CREATE TABLE iam.OrgMemberships (
    Id                  uniqueidentifier NOT NULL,
    EmployeeId          uniqueidentifier NOT NULL,
    OrgUnitId           uniqueidentifier NOT NULL,
    IsPrimary           bit              NOT NULL,
    IsHead              bit              NOT NULL,
    StartDate           date             NOT NULL,
    EndDate             date             NULL,
    SourceVersion       bigint           NOT NULL,
    CONSTRAINT PK_OrgMemberships PRIMARY KEY (Id)
);
CREATE INDEX IX_OrgMemberships_EmployeeId ON iam.OrgMemberships (EmployeeId);
CREATE INDEX IX_OrgMemberships_OrgUnitId ON iam.OrgMemberships (OrgUnitId);
GO
