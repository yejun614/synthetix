# ERD: platform, audit, ai, outbox

> 상태: 초안 · 갱신: 2026-10-21 · 관련: [system-overview.md](../../01-architecture/system-overview.md), [data-protection.md](../../03-security/data-protection.md), [ai-gateway.md](../../04-ai/ai-gateway.md) · DDL: [05-platform.sql](../ddl/05-platform.sql)

## platform

```mermaid
erDiagram
    CodeGroups ||--o{ CommonCodes : ""

    Files {
        uniqueidentifier Id PK
        nvarchar OriginalName "260"
        nvarchar ContentType "100"
        bigint SizeBytes
        nvarchar StorageKey "IFileStorage 내부 경로"
        binary Sha256 "32"
        nvarchar Classification "Internal, Confidential, Restricted"
        nvarchar OwnerModule "projects, hr ..."
    }
    CodeGroups {
        nvarchar GroupCode PK "JobGrade, JobTitle, Skill ..."
        nvarchar Name "100"
    }
    CommonCodes {
        nvarchar GroupCode PK, FK
        nvarchar Code PK "50"
        nvarchar Name "100"
        int SortOrder
        bit IsActive
    }
    Holidays {
        date HolidayDate PK
        nvarchar Name "100"
    }
    Notifications {
        uniqueidentifier Id PK
        uniqueidentifier RecipientUserAccountId "→ iam.UserAccounts"
        nvarchar Type "50"
        nvarchar Title "200"
        nvarchar Body "1000"
        nvarchar Link "null, 앱 내부 경로"
        datetimeoffset ReadAt "null"
    }
    SystemSettings {
        nvarchar SettingKey PK "100"
        nvarchar Value "max, JSON"
    }
```

## audit (추가만 가능)

```mermaid
erDiagram
    AuditLogs {
        bigint Id PK "identity"
        datetimeoffset OccurredAt
        uniqueidentifier UserAccountId "null, 시스템 작업이면 null"
        nvarchar Module "30"
        nvarchar Action "Create, Update, Delete, Approve ..."
        nvarchar EntityType "100"
        nvarchar EntityId "100"
        nvarchar Changes "JSON, 이전 값과 새 값, 민감 필드는 가린 값"
        nvarchar CorrelationId "100"
        nvarchar IpAddress "45"
    }
    SecurityEvents {
        bigint Id PK "identity"
        datetimeoffset OccurredAt
        nvarchar EventType "LoginSucceeded, LoginFailed, AccountLocked, MfaFailed, RefreshTokenReuseDetected ..."
        uniqueidentifier UserAccountId "null"
        nvarchar AttemptedEmployeeNumber "null, 없는 사번 시도 기록"
        nvarchar ClientType "desktop, web"
        nvarchar ClientVersion "20"
        nvarchar IpAddress "45"
        nvarchar Detail "JSON"
    }
    SensitiveDataAccessLogs {
        bigint Id PK "identity"
        datetimeoffset OccurredAt
        uniqueidentifier UserAccountId
        nvarchar EntityType "100"
        nvarchar EntityId "100"
        nvarchar FieldName "100"
        nvarchar Reason "500, 열람 사유"
    }
```

## ai

```mermaid
erDiagram
    ProviderSettings ||--o{ Interactions : ""
    GuardRules {
        uniqueidentifier Id PK
        nvarchar Stage "Input, Output"
        nvarchar RuleType "Keyword, Regex, Classification"
        nvarchar Pattern "max"
        nvarchar Action "Block, Mask, Warn"
        bit IsActive
    }
    ProviderSettings {
        uniqueidentifier Id PK
        nvarchar Alias UK "local-default, local-embedding ..."
        nvarchar Provider "Ollama, vLLM, AzureOpenAI ..."
        nvarchar TrustLevel "OnPremises, PrivateCloud, PublicCloud"
        nvarchar Endpoint "500"
        nvarchar Model "200"
        varbinary EncryptedApiKey "null"
        bit IsEnabled "외부 공급자는 기본 false"
    }
    Interactions {
        uniqueidentifier Id PK
        nvarchar Purpose "AI-PRJ-01 ..."
        uniqueidentifier UserAccountId "→ iam.UserAccounts"
        uniqueidentifier ProviderSettingId FK
        nvarchar PromptTemplateVersion "50"
        nvarchar MaskedInput "max"
        nvarchar MaskedOutput "max"
        nvarchar DetectedEntities "JSON, 유형별 개수"
        nvarchar PolicyDecision "Allowed, Pseudonymized, Blocked"
        nvarchar PolicyReason "null"
        int InputTokens
        int OutputTokens
        int LatencyMs
        nvarchar Feedback "null, Accepted, Edited, Rejected"
    }
    DocumentChunks {
        uniqueidentifier Id PK
        nvarchar SourceType "Contract, Policy, Manual ..."
        uniqueidentifier SourceId
        int ChunkIndex
        nvarchar Content "max"
        vector Embedding "차원은 모델에 맞춤"
        nvarchar Classification "Internal, Confidential"
        uniqueidentifier OwningUnitId "null, 권한 필터"
        uniqueidentifier ProjectId "null, 권한 필터"
    }
```

## outbox (모듈 사이 통합 이벤트)

```mermaid
erDiagram
    OutboxMessages {
        uniqueidentifier Id PK
        datetimeoffset OccurredAt
        nvarchar SourceModule "30"
        nvarchar EventType "200"
        nvarchar Payload "max, JSON"
        datetimeoffset ProcessedAt "null"
        int Attempts
        nvarchar LastError "null"
    }
    InboxMessages {
        uniqueidentifier MessageId PK "OutboxMessages.Id"
        nvarchar Consumer PK "처리한 핸들러 이름"
        datetimeoffset ProcessedAt
    }
```

## 제약조건과 인덱스

| 테이블 | 내용 |
|---|---|
| `Notifications` | `IX(RecipientUserAccountId) WHERE ReadAt IS NULL` |
| `audit.*` | 애플리케이션 DB 계정에는 `INSERT`와 `SELECT`만 허용합니다(`UPDATE`, `DELETE` 거부). 보존 기간이 지난 데이터는 별도 계정으로 실행하는 정리 작업이 지웁니다 |
| `AuditLogs` | `IX(EntityType, EntityId)`, `IX(OccurredAt)` |
| `Interactions` | `IX(Purpose, CreatedAt)`, `IX(UserAccountId, CreatedAt)` |
| `DocumentChunks` | `UX(SourceType, SourceId, ChunkIndex)`. 벡터 인덱스는 SQL Server 2025의 벡터 인덱스 지원 범위를 확인한 뒤 정합니다 |
| `OutboxMessages` | `IX(OccurredAt) WHERE ProcessedAt IS NULL` |
| `InboxMessages` | PK `(MessageId, Consumer)`: 같은 이벤트를 다시 받아도 한 번만 처리합니다(멱등성) |

## 메모

- `DocumentChunks.Content`에 원문을 저장할지, 가명화한 텍스트를 저장할지는 RAG를 설계할 때(Phase 4) 정합니다. 어느 경우든 검색 결과는 요청한 사용자의 데이터 범위로 거릅니다.
- `Interactions`에는 원문을 저장하지 않습니다 ([ai-gateway.md](../../04-ai/ai-gateway.md)).
