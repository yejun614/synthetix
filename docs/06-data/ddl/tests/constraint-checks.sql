-- =============================================================================
-- Synthetix DDL 검증: 제약조건이 의도대로 동작하는지 확인
-- 빈 DB에 00~99 스크립트를 적용한 뒤 실행합니다. 실패하면 오류를 던지고 멈춥니다.
-- =============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE @company uniqueidentifier = NEWID(), @div uniqueidentifier = NEWID(), @team uniqueidentifier = NEWID();
DECLARE @e1 uniqueidentifier = NEWID(), @e2 uniqueidentifier = NEWID();
DECLARE @admin uniqueidentifier = NEWID();
DECLARE @failed int = 0, @name nvarchar(200);

-- 기대한 실패가 일어났는지 확인하는 패턴:
--   BEGIN TRY <위반 문장>; SET @failed += 1; PRINT 'FAIL: ...'; END TRY BEGIN CATCH PRINT 'ok  : ...'; END CATCH

------------------------------------------------------------------------------
-- 정상 데이터
------------------------------------------------------------------------------
INSERT hr.OrgUnits (Id, Code, Name, Type, ParentId, Node) VALUES
    (@company, N'C000', N'㈜예시소프트', N'Company', NULL, hierarchyid::GetRoot()),
    (@div,     N'D100', N'기술본부',     N'Division', @company, CAST(N'/1/' AS hierarchyid)),
    (@team,    N'T110', N'플랫폼팀',     N'Team',     @div,     CAST(N'/1/1/' AS hierarchyid));

INSERT hr.Employees (Id, EmployeeNumber, Name, EmploymentType, HireDate) VALUES
    (@e1, N'S2026001', N'홍길동', N'Regular', '2026-01-02'),
    (@e2, N'S2026002', N'김개발', N'Regular', '2026-01-02');

INSERT hr.OrgMemberships (Id, EmployeeId, OrgUnitId, IsPrimary, IsHead, StartDate) VALUES
    (NEWID(), @e1, @team, 1, 1, '2026-01-02'),
    (NEWID(), @e2, @team, 1, 0, '2026-01-02');
PRINT 'ok  : 정상 데이터 입력';

------------------------------------------------------------------------------
-- hr: 조직
------------------------------------------------------------------------------
SET @name = N'루트 조직은 하나뿐 (UX_OrgUnits_Root)';
BEGIN TRY
    INSERT hr.OrgUnits (Id, Code, Name, Type, ParentId, Node) VALUES (NEWID(), N'C001', N'두번째회사', N'Company', NULL, CAST(N'/9/' AS hierarchyid));
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

SET @name = N'루트가 아닌 조직은 부모가 필요 (CK_OrgUnits_RootIsCompany)';
BEGIN TRY
    INSERT hr.OrgUnits (Id, Code, Name, Type, ParentId, Node) VALUES (NEWID(), N'T999', N'고아팀', N'Team', NULL, CAST(N'/8/' AS hierarchyid));
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

SET @name = N'현재 주 소속은 하나 (UX_OrgMemberships_CurrentPrimary)';
BEGIN TRY
    INSERT hr.OrgMemberships (Id, EmployeeId, OrgUnitId, IsPrimary, IsHead, StartDate) VALUES (NEWID(), @e2, @div, 1, 0, '2026-03-01');
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

SET @name = N'겸직(주 소속 아님)은 여러 개 가능';
BEGIN TRY
    INSERT hr.OrgMemberships (Id, EmployeeId, OrgUnitId, IsPrimary, IsHead, StartDate) VALUES (NEWID(), @e2, @div, 0, 0, '2026-03-01');
    PRINT N'ok  : ' + @name;
END TRY BEGIN CATCH SET @failed += 1; PRINT N'FAIL: ' + @name + N' - ' + ERROR_MESSAGE(); END CATCH;

SET @name = N'현재 조직장은 한 명 (UX_OrgMemberships_CurrentHead)';
BEGIN TRY
    UPDATE hr.OrgMemberships SET IsHead = 1 WHERE EmployeeId = @e2 AND OrgUnitId = @team;
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

SET @name = N'이전 조직장의 소속을 끝내면 새 조직장 지정 가능';
BEGIN TRY
    UPDATE hr.OrgMemberships SET EndDate = '2026-06-30' WHERE EmployeeId = @e1 AND OrgUnitId = @team;
    UPDATE hr.OrgMemberships SET IsHead = 1 WHERE EmployeeId = @e2 AND OrgUnitId = @team;
    PRINT N'ok  : ' + @name;
END TRY BEGIN CATCH SET @failed += 1; PRINT N'FAIL: ' + @name + N' - ' + ERROR_MESSAGE(); END CATCH;

SET @name = N'협력사 인력은 PartnerId 필수 (CK_Employees_PartnerStaff)';
BEGIN TRY
    INSERT hr.Employees (Id, EmployeeNumber, Name, EmploymentType, HireDate) VALUES (NEWID(), N'P0001', N'외주인력', N'PartnerStaff', '2026-01-02');
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

SET @name = N'임시 테이블: 조직명 변경 이력이 남음';
UPDATE hr.OrgUnits SET Name = N'플랫폼개발팀' WHERE Id = @team;
IF (SELECT COUNT(*) FROM hr.OrgUnits FOR SYSTEM_TIME ALL WHERE Id = @team) = 2
    PRINT N'ok  : ' + @name;
ELSE BEGIN SET @failed += 1; PRINT N'FAIL: ' + @name; END;

SET @name = N'hierarchyid: 기술본부의 하위 조직 조회';
IF (SELECT COUNT(*) FROM hr.OrgUnits WHERE Node.IsDescendantOf(CAST(N'/1/' AS hierarchyid)) = 1) = 2
    PRINT N'ok  : ' + @name;
ELSE BEGIN SET @failed += 1; PRINT N'FAIL: ' + @name; END;

------------------------------------------------------------------------------
-- iam
------------------------------------------------------------------------------
INSERT iam.Roles (Id, Name, IsSystem) VALUES (NEWID(), N'Employee', 1);

SET @name = N'개인 대상 부여는 하위 포함 불가 (CK_RoleAssignments_UserNoDescendants)';
BEGIN TRY
    INSERT iam.RoleAssignments (Id, SubjectType, SubjectId, IncludeDescendants, RoleId, DataScope, ValidFrom, Reason)
    SELECT NEWID(), N'User', NEWID(), 1, Id, N'Self', '2026-01-01', N'test' FROM iam.Roles WHERE Name = N'Employee';
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

SET @name = N'알 수 없는 데이터 범위 거부 (CK_RoleAssignments_DataScope)';
BEGIN TRY
    INSERT iam.RoleAssignments (Id, SubjectType, SubjectId, RoleId, DataScope, ValidFrom, Reason)
    SELECT NEWID(), N'OrgUnit', @team, Id, N'Everything', '2026-01-01', N'test' FROM iam.Roles WHERE Name = N'Employee';
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

------------------------------------------------------------------------------
-- projects
------------------------------------------------------------------------------
DECLARE @prj uniqueidentifier = NEWID();
INSERT projects.Projects (Id, ProjectCode, Name, Type, OwningUnitId, PlannedStart, PlannedEnd)
VALUES (@prj, N'PRJ-2026-0001', N'차세대 시스템 구축', N'SI', @team, '2026-01-01', '2026-12-31');

SET @name = N'투입률은 0 초과 1 이하 (CK_Assignments_AllocationRate)';
BEGIN TRY
    INSERT projects.Assignments (Id, ProjectId, EmployeeId, Role, StartDate, EndDate, AllocationRate, MonthlyRate)
    VALUES (NEWID(), @prj, @e1, N'Developer', '2026-01-01', '2026-06-30', 1.5, 8000000);
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

------------------------------------------------------------------------------
-- accounting
------------------------------------------------------------------------------
DECLARE @period uniqueidentifier = NEWID(), @acct uniqueidentifier = NEWID(), @je uniqueidentifier = NEWID();
INSERT accounting.AccountingPeriods (Id, Year, Month) VALUES (@period, 2026, 10);
INSERT accounting.Accounts (Id, Code, Name, AccountType) VALUES (@acct, N'41100', N'용역매출', N'Revenue');
INSERT accounting.JournalEntries (Id, EntryNumber, EntryDate, PeriodId, Description, CreatedBy)
VALUES (@je, N'JE-202610-00001', '2026-10-21', @period, N'테스트', @admin);

SET @name = N'한 줄에 차변과 대변을 함께 쓸 수 없음 (CK_JournalLines_DebitCredit)';
BEGIN TRY
    INSERT accounting.JournalLines (Id, JournalEntryId, LineNumber, AccountId, Debit, Credit) VALUES (NEWID(), @je, 1, @acct, 100, 100);
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

SET @name = N'금액이 0인 줄 거부 (CK_JournalLines_DebitCredit)';
BEGIN TRY
    INSERT accounting.JournalLines (Id, JournalEntryId, LineNumber, AccountId, Debit, Credit) VALUES (NEWID(), @je, 2, @acct, 0, 0);
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

SET @name = N'외화 줄은 원래 금액과 환율 필수 (CK_JournalLines_Foreign)';
BEGIN TRY
    INSERT accounting.JournalLines (Id, JournalEntryId, LineNumber, AccountId, Debit, Credit, Currency) VALUES (NEWID(), @je, 3, @acct, 1000, 0, N'USD');
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

SET @name = N'작성자가 직접 승인할 수 없음 (CK_JournalEntries_SegregationOfDuties)';
BEGIN TRY
    UPDATE accounting.JournalEntries SET Status = N'Approved', ApprovedBy = @admin WHERE Id = @je;
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

------------------------------------------------------------------------------
-- json, vector (SQL Server 2025)
------------------------------------------------------------------------------
SET @name = N'json 타입은 잘못된 JSON을 거부';
BEGIN TRY
    INSERT outbox.OutboxMessages (Id, OccurredAt, SourceModule, EventType, Payload) VALUES (NEWID(), SYSUTCDATETIME(), N'hr', N'Test', N'{not json');
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

SET @name = N'vector(1024) 저장과 VECTOR_DISTANCE 조회';
BEGIN TRY
    DECLARE @v1 nvarchar(max) = (SELECT N'[' + STRING_AGG(CAST(N'0.1' AS nvarchar(max)), N',') + N']' FROM GENERATE_SERIES(1, 1024));
    DECLARE @v2 nvarchar(max) = (SELECT N'[' + STRING_AGG(CAST(IIF(value % 2 = 0, N'0.1', N'0.2') AS nvarchar(max)), N',') + N']' FROM GENERATE_SERIES(1, 1024));
    INSERT ai.DocumentChunks (Id, SourceType, SourceId, ChunkIndex, Content, Embedding, Classification)
    VALUES (NEWID(), N'Policy', NEWID(), 0, N'휴가 규정', CAST(@v1 AS vector(1024)), N'Internal');
    DECLARE @d float = (SELECT TOP (1) VECTOR_DISTANCE('cosine', Embedding, CAST(@v2 AS vector(1024))) FROM ai.DocumentChunks);
    IF @d > 0 AND @d < 1 PRINT N'ok  : ' + @name + N' (cosine distance = ' + CAST(@d AS nvarchar(30)) + N')';
    ELSE BEGIN SET @failed += 1; PRINT N'FAIL: ' + @name; END;
END TRY BEGIN CATCH SET @failed += 1; PRINT N'FAIL: ' + @name + N' - ' + ERROR_MESSAGE(); END CATCH;

SET @name = N'Restricted 문서는 색인하지 않음 (CK_DocumentChunks_Classification)';
BEGIN TRY
    INSERT ai.DocumentChunks (Id, SourceType, SourceId, ChunkIndex, Content, Embedding, Classification)
    VALUES (NEWID(), N'Policy', NEWID(), 0, N'x', CAST(@v1 AS vector(1024)), N'Restricted');
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

------------------------------------------------------------------------------
-- outbox, audit 권한
------------------------------------------------------------------------------
DECLARE @msg uniqueidentifier = NEWID();
INSERT outbox.InboxMessages (MessageId, Consumer, ProcessedAt) VALUES (@msg, N'Projects.EmployeeTerminatedHandler', SYSUTCDATETIME());
SET @name = N'같은 이벤트를 같은 핸들러가 두 번 처리할 수 없음 (PK_InboxMessages)';
BEGIN TRY
    INSERT outbox.InboxMessages (MessageId, Consumer, ProcessedAt) VALUES (@msg, N'Projects.EmployeeTerminatedHandler', SYSUTCDATETIME());
    SET @failed += 1; PRINT N'FAIL: ' + @name;
END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

CREATE USER ddl_check_app WITHOUT LOGIN;
ALTER ROLE synthetix_app ADD MEMBER ddl_check_app;
EXECUTE AS USER = N'ddl_check_app';
    SET @name = N'앱 계정은 감사 로그를 추가할 수 있음';
    BEGIN TRY
        INSERT audit.AuditLogs (OccurredAt, Module, Action, EntityType, EntityId) VALUES (SYSUTCDATETIME(), N'hr', N'Update', N'OrgUnit', N'x');
        PRINT N'ok  : ' + @name;
    END TRY BEGIN CATCH SET @failed += 1; PRINT N'FAIL: ' + @name + N' - ' + ERROR_MESSAGE(); END CATCH;

    SET @name = N'앱 계정은 감사 로그를 고칠 수 없음 (DENY UPDATE)';
    BEGIN TRY
        UPDATE audit.AuditLogs SET Action = N'Tampered';
        SET @failed += 1; PRINT N'FAIL: ' + @name;
    END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;

    SET @name = N'앱 계정은 감사 로그를 지울 수 없음 (DENY DELETE)';
    BEGIN TRY
        DELETE audit.AuditLogs;
        SET @failed += 1; PRINT N'FAIL: ' + @name;
    END TRY BEGIN CATCH PRINT N'ok  : ' + @name; END CATCH;
REVERT;

------------------------------------------------------------------------------
IF @failed > 0
    THROW 50000, N'제약조건 검증 실패. 위의 FAIL 항목을 확인하세요.', 1;
PRINT N'== 모든 제약조건 검증 통과 ==';
