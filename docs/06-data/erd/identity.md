# ERD: iam (Identity 모듈)

> 상태: 초안 · 갱신: 2026-10-21 · 업무 규칙: [authentication.md](../../03-security/authentication.md), [authorization.md](../../03-security/authorization.md) · DDL: [01-iam.sql](../ddl/01-iam.sql)

## 계정, MFA, 세션

```mermaid
erDiagram
    UserAccounts ||--o| MfaAuthenticators : ""
    UserAccounts ||--o{ RecoveryCodes : ""
    UserAccounts ||--o{ MfaChallenges : ""
    UserAccounts ||--o{ Sessions : ""
    Sessions ||--|{ RefreshTokens : "회전 체인"
    RefreshTokens |o--o| RefreshTokens : "ReplacedById"

    UserAccounts {
        uniqueidentifier Id PK
        uniqueidentifier EmployeeId UK "→ hr.Employees"
        nvarchar EmployeeNumber UK "20, 로그인 ID"
        nvarchar PasswordHash "PBKDF2"
        nvarchar SecurityStamp "바뀌면 세션 무효화"
        nvarchar Status "Pending, Active, Disabled"
        bit MustChangePassword
        int AccessFailedCount
        datetimeoffset LockoutEnd "null"
        datetimeoffset LastLoginAt "null"
    }
    MfaAuthenticators {
        uniqueidentifier Id PK
        uniqueidentifier UserAccountId FK, UK
        varbinary EncryptedSecret "Data Protection"
        bigint LastUsedTimeStep "재사용 방지"
        datetimeoffset EnrolledAt
    }
    RecoveryCodes {
        uniqueidentifier Id PK
        uniqueidentifier UserAccountId FK
        binary CodeHash "32"
        datetimeoffset UsedAt "null"
    }
    MfaChallenges {
        uniqueidentifier Id PK
        uniqueidentifier UserAccountId FK
        binary TokenHash UK "32, mfaToken 해시"
        nvarchar NextStep "MfaRequired, MfaEnrollmentRequired"
        varbinary PendingSecret "null, 등록 중 임시 비밀키"
        int FailedAttempts "최대 5"
        datetimeoffset ExpiresAt "발급 후 5분"
        datetimeoffset ConsumedAt "null"
        nvarchar IpAddress "45"
    }
    Sessions {
        uniqueidentifier Id PK "JWT sid"
        uniqueidentifier UserAccountId FK
        nvarchar ClientType "desktop, web"
        nvarchar ClientVersion "20"
        nvarchar IpAddress "45"
        datetimeoffset StartedAt
        datetimeoffset AbsoluteExpiresAt "최대 12시간"
        datetimeoffset LastSeenAt
        datetimeoffset RevokedAt "null"
        nvarchar RevokedReason "null"
    }
    RefreshTokens {
        uniqueidentifier Id PK
        uniqueidentifier SessionId FK
        binary TokenHash UK "32"
        datetimeoffset IssuedAt
        datetimeoffset IdleExpiresAt "2시간"
        datetimeoffset UsedAt "null"
        uniqueidentifier ReplacedById FK "null"
    }
```

## 역할과 권한

```mermaid
erDiagram
    Roles ||--o{ RolePermissions : ""
    Permissions ||--o{ RolePermissions : ""
    Roles ||--o{ RoleAssignments : ""
    RoleAssignments ||--o{ RoleAssignmentScopeUnits : "SpecifiedUnits 범위"
    RoleAssignments ||--o{ RoleAssignmentExclusions : "예외"
    OrgUnits ||--o{ OrgUnits : "ParentId"
    OrgUnits ||--o{ OrgMemberships : ""

    Permissions {
        nvarchar Code PK "100, 예: projects.contracts.read"
        nvarchar Module "30"
        nvarchar Description
        bit IsSensitive "특권 권한 표시"
    }
    Roles {
        uniqueidentifier Id PK
        nvarchar Name UK "50"
        nvarchar Description
        bit IsSystem "삭제 불가"
        bit IsDelegable "위임 관리자가 부여 가능"
    }
    RolePermissions {
        uniqueidentifier RoleId PK, FK
        nvarchar PermissionCode PK, FK
    }
    RoleAssignments {
        uniqueidentifier Id PK
        nvarchar SubjectType "User, OrgUnit, OrgHead"
        uniqueidentifier SubjectId "UserAccounts.Id 또는 OrgUnits.Id"
        bit IncludeDescendants
        uniqueidentifier RoleId FK
        nvarchar DataScope "All, OwnUnit, OwnUnitAndDescendants, SpecifiedUnits, AssignedProjects, Self"
        date ValidFrom
        date ValidTo "null"
        nvarchar Reason "500"
        datetimeoffset RevokedAt "null"
        uniqueidentifier RevokedBy "null"
    }
    RoleAssignmentScopeUnits {
        uniqueidentifier RoleAssignmentId PK, FK
        uniqueidentifier OrgUnitId PK
        bit IncludeDescendants
    }
    RoleAssignmentExclusions {
        uniqueidentifier RoleAssignmentId PK, FK
        uniqueidentifier UserAccountId PK
        nvarchar Reason "500"
    }
    OrgUnits {
        uniqueidentifier Id PK "hr.OrgUnits 프로젝션"
        uniqueidentifier ParentId "null"
        hierarchyid Node
        nvarchar Status
        bigint SourceVersion "마지막으로 반영한 이벤트 순번"
    }
    OrgMemberships {
        uniqueidentifier Id PK "hr.OrgMemberships 프로젝션"
        uniqueidentifier EmployeeId
        uniqueidentifier OrgUnitId "FK 없음, 이벤트 순서 보호"
        bit IsPrimary
        bit IsHead
        date StartDate
        date EndDate "null"
        bigint SourceVersion
    }
```

## 제약조건과 인덱스

| 테이블 | 내용 |
|---|---|
| `UserAccounts` | `UX(EmployeeNumber)`, `UX(EmployeeId)` |
| `MfaChallenges`, `RefreshTokens` | `UX(TokenHash)`. 만료된 행은 정리 작업이 매일 지웁니다 |
| `Sessions` | `IX(UserAccountId) WHERE RevokedAt IS NULL`: 활성 세션 조회와 일괄 폐기 |
| `RoleAssignments` | `IX(SubjectType, SubjectId) WHERE RevokedAt IS NULL`. `SubjectId`는 대상 유형에 따라 가리키는 테이블이 달라서 FK가 없습니다. 애플리케이션이 검증합니다 |
| `RoleAssignments` | CHECK: `SubjectType = 'User'`이면 `IncludeDescendants = 0` |
| `OrgUnits` (프로젝션) | `IX(Node)`: 상위·하위 조직 조회 |
| `OrgUnits`, `OrgMemberships` (프로젝션) | 이벤트 도착 순서가 어긋날 수 있어 FK를 걸지 않습니다. `SourceVersion`보다 오래된 이벤트는 무시합니다 |
| 임시 테이블 | `Roles`, `RolePermissions`, `RoleAssignments`, `RoleAssignmentScopeUnits`, `RoleAssignmentExclusions`: 과거 시점의 권한 상태 조회와 감사에 씁니다 |

## 메모

- ASP.NET Core Identity Core를 쓰면 기본 테이블(`AspNetUsers` 등)을 위 이름과 컬럼에 맞게 매핑합니다. Identity가 필요로 하는 컬럼(`NormalizedUserName`, `ConcurrencyStamp` 등)은 구현할 때 추가합니다 (미결 사항 Q11).
- 활성 사용자의 `EmployeeId`로 프로젝션 `OrgMemberships`를 조인해서 소속 조직을 구합니다.
