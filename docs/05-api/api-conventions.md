# API 규칙

> 상태: 초안 · 갱신: 2026-10-21

## 경로

- 형식: `/api/v1/{module}/{resource}[/{id}[/{sub-resource}]]`
  - 예: `/api/v1/projects/contracts/{id}/amendments`
- 경로는 소문자 kebab-case, 리소스 이름은 복수형을 씁니다.
- 동작이 CRUD에 맞지 않으면 하위 동작 경로를 씁니다: `POST /api/v1/accounting/journals/{id}/approve`
- 예외: `/.well-known/synthetix`, `/updates/**`, `/health`

## 형식

- JSON은 camelCase로 씁니다. 직렬화는 `Synthetix.Contracts`의 source-generated `JsonSerializerContext`로 합니다.
- enum은 문자열로 직렬화합니다.
- 날짜와 시간
  - 업무 날짜(계약 시작일 등): `DateOnly` → `"2026-10-21"`
  - 시각(생성 시각 등): `DateTimeOffset`, UTC → `"2026-10-21T01:23:45Z"`
- 금액은 JSON 숫자로 보내고, 통화는 별도 필드에 담습니다. 클라이언트도 `decimal`로 받습니다.
- ID는 GUID입니다. 사람이 읽는 코드(예: `PRJ-2026-0007`)는 별도 필드로 둡니다.

## 응답과 상태 코드

| 상황 | 상태 코드 |
|---|---|
| 조회 성공 | 200 |
| 생성 성공 | 201 + `Location` 헤더 |
| 본문 없는 성공 | 204 |
| 입력 검증 실패 | 400 (`errors`에 필드별 메시지) |
| 인증 필요, 토큰 만료 | 401 |
| 권한 없음 | 403. 단, 데이터 범위 밖의 리소스는 404 ([authorization.md](../03-security/authorization.md)) |
| 업무 규칙 위반, 상태 충돌 | 409 |
| 동시성 충돌 (ETag 불일치) | 412 |
| 요청 제한 초과 | 429 + `Retry-After` |
| 클라이언트 버전이 너무 낮음 | 426 + `X-Synthetix-Min-Client-Version` |

## 오류 형식: RFC 9457 ProblemDetails

```json
{
  "type": "https://synthetix.dev/errors/projects.contract_not_editable",
  "title": "확정된 계약은 수정할 수 없습니다.",
  "status": 409,
  "code": "projects.contract_not_editable",
  "traceId": "00-...",
  "errors": { "amount": ["금액은 0보다 커야 합니다."] }
}
```

- `code`는 `{module}.{snake_case}` 형식입니다. 클라이언트는 `title`이 아니라 `code`를 보고 분기합니다.
- 오류 메시지에 민감정보, 스택 트레이스, SQL을 넣지 않습니다.

## 목록 조회

- 페이지: `?page=1&pageSize=50` (`pageSize` 최대 200). 응답 형식은 `{ items, page, pageSize, totalCount }`입니다.
- 정렬: `?sort=-startDate,name` (`-`는 내림차순). 허용하는 필드는 엔드포인트마다 정해 둡니다.
- 필터: `?status=Active&from=2026-01-01`처럼 명시적인 쿼리 매개변수만 씁니다. 범용 필터 문법은 만들지 않습니다.

## 동시성과 멱등성

- 수정할 수 있는 리소스는 `rowversion`을 ETag로 내보냅니다. 수정 요청에는 `If-Match`가 꼭 있어야 합니다.
- 돈이 오가는 생성 요청(전표, 청구)은 `Idempotency-Key` 헤더를 받습니다. 같은 키로 다시 요청하면 처음 결과를 그대로 돌려줍니다.

## 문서화

- 개발 환경에서만 OpenAPI 문서(`/openapi/v1.json`)와 Scalar UI를 엽니다.
- 각 엔드포인트에는 `.WithName()`, `.WithSummary()`, `.Produces<T>()`, `.RequirePermission()`을 붙입니다.

## 실시간 응답

- AI 스트리밍은 SSE(`text/event-stream`)로 보냅니다. IIS에서는 이 경로의 응답 버퍼링과 압축을 끕니다.
