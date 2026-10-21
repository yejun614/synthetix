# 코딩 규칙

> 상태: 초안 · 갱신: 2026-10-21

## 공통 설정 (`Directory.Build.props`)

- `Nullable` 켜기, `ImplicitUsings` 켜기, `TreatWarningsAsErrors` 켜기
- `AnalysisLevel`은 `latest-recommended`로 설정합니다.
- 패키지 버전은 `Directory.Packages.props`에서만 관리합니다(중앙 패키지 관리).

## 스타일

- 네임스페이스는 파일 범위(file-scoped)로 쓰고, 폴더 구조와 맞춥니다.
- 클래스는 기본적으로 `sealed`로 만듭니다. 모듈 구현 타입은 `internal`입니다.
- DI는 주 생성자(primary constructor)로 받습니다.
- 비동기 메서드 이름 끝에는 `Async`를 붙이고, `CancellationToken`을 마지막 매개변수로 받아서 끝까지 넘깁니다.
- `var`는 오른쪽 식에서 타입이 분명할 때만 씁니다.
- 컬렉션 식(`[]`), 패턴 매칭, `required`, `init` 같은 최신 C# 문법을 씁니다.
- 주석은 한국어로, **"왜"**를 설명할 때만 씁니다. 코드를 그대로 다시 말하는 주석은 쓰지 않습니다.

## 도메인 코드

- 엔티티 속성의 setter는 `private`입니다. 상태는 의미 있는 메서드로만 바꿉니다: `contract.Sign(...)`, `entry.Approve(...)`
- 값 객체(Money, DateRange, AllocationRate 등)는 `record` 또는 `readonly record struct`로 만들고, 생성할 때 유효성을 검사합니다.
- 업무 규칙 위반은 `Result<T>`와 `Error(code, message)`로 돌려줍니다. 예외는 예상하지 못한 오류에만 씁니다.
- 오류 코드 상수는 모듈마다 `{Module}Errors` 클래스에 모읍니다.

## 시간과 문화권

- `TimeProvider`를 주입받아 씁니다. `DateTime.Now`, `DateTime.UtcNow`, `DateTimeOffset.Now`를 직접 쓰지 않습니다(분석기로 금지).
- 문자열을 비교할 때는 `StringComparison`을 명시합니다. 형식을 만들 때는 `CultureInfo`를 명시합니다.

## 보안 코딩

- SQL은 EF Core LINQ나 매개변수화된 쿼리로만 씁니다. 문자열을 이어 붙여 SQL을 만들지 않습니다.
- 민감정보는 로그와 예외 메시지에 넣지 않습니다 ([data-protection.md](../03-security/data-protection.md)).
- 비밀 값 비교는 `CryptographicOperations.FixedTimeEquals`로 합니다(시간 차이로 정보가 새지 않게).
- 난수는 `RandomNumberGenerator`로 만듭니다. `System.Random`은 보안 용도로 쓰지 않습니다.

## 금지 사항 요약

| 금지 | 대신 쓸 것 |
|---|---|
| `DateTime.Now` | `TimeProvider` |
| `.Result`, `.Wait()` | `await` |
| 다른 모듈의 구현이나 DbContext 참조 | `.Public` 인터페이스, 통합 이벤트 |
| LLM SDK 직접 호출 | `IAiGateway` |
| `float` 또는 `double`로 금액 다루기 | `decimal` |
| 리플렉션 기반 JSON (클라이언트) | `JsonSerializerContext` |
