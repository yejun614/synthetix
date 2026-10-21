# 데이터 보호

> 상태: 초안 · 갱신: 2026-10-21 · 관련: [deidentification.md](../04-ai/deidentification.md), [authorization.md](authorization.md), [ADR-0006](../adr/0006-application-level-field-encryption.md)

## 데이터 분류

모든 엔티티 속성은 아래 네 등급 중 하나에 속합니다. 따로 표시하지 않으면 `Internal`로 봅니다.

| 등급 | 의미 | 예 |
|---|---|---|
| `Public` | 공개되어도 괜찮음 | 회사명, 공통 코드 |
| `Internal` | 사내용 | 프로젝트명, 부서, 직급, 일정 |
| `Confidential` | 업무상 기밀 | 계약 금액, 단가, 고객사 담당자 연락처, 손익, 직원 이름·연락처 |
| `Restricted` | 법적으로 보호되는 정보이거나, 유출 시 피해가 큰 정보 | 주민등록번호, 계좌번호, 급여, 건강 정보, 인증 비밀값 |

엔티티 속성에는 특성(attribute)으로 등급을 표시합니다.

```csharp
public sealed class Employee : Entity
{
    [Classified(DataClassification.Confidential, PiiType.PersonName)]
    public string Name { get; private set; }

    [Classified(DataClassification.Restricted, PiiType.ResidentRegistrationNumber)]
    public EncryptedString ResidentRegistrationNumber { get; private set; }
}
```

이 메타데이터 하나를 여러 곳에서 씁니다.

- **저장:** `Restricted` 필드는 컬럼 단위로 암호화합니다.
- **응답:** 권한이 없으면 가린 값을 내보냅니다 ([authorization.md](authorization.md)).
- **로그:** 해당 필드는 자동으로 가립니다.
- **AI:** 구조화된 데이터를 프롬프트에 넣을 때 등급에 따라 가명화하거나 제외합니다 ([deidentification.md](../04-ai/deidentification.md)).

등급이 표시되지 않은 `string` 속성 중 이름이 의심스러운 것(`*Phone*`, `*Email*`, `*Account*`, `*Rrn*` 등)이 있으면 아키텍처 테스트가 실패합니다.

## 저장 시 암호화

| 계층 | 방식 |
|---|---|
| DB 전체 | SQL Server TDE (지원하는 에디션에서) |
| `Restricted` 필드 | 애플리케이션에서 AES-256-GCM으로 암호화합니다(EF Core ValueConverter). 키는 서버의 키 저장소에 둡니다 ([ADR-0006](../adr/0006-application-level-field-encryption.md)) |
| 암호화 필드 검색 | 정확히 일치하는 값을 찾아야 하면 HMAC 기반 **블라인드 인덱스** 컬럼을 따로 둡니다 |
| 비밀번호, 토큰, 복구 코드 | 되돌릴 수 없는 해시로 저장합니다 |
| TOTP 비밀키, 클라우드 자격 증명 | Data Protection 또는 필드 암호화로 저장합니다 |

## 주민등록번호

- 개인정보 보호법상 주민번호는 **법령에 근거가 있을 때만 처리**할 수 있고, **암호화가 의무**입니다.
- Synthetix에서는 인사 업무(4대보험, 원천징수 연계 등)에 필요한 경우에만 저장합니다. 본인 확인 같은 다른 용도로는 쓰지 않습니다.
- 저장할 때는 암호화합니다. 화면에는 기본적으로 가려서 보여줍니다. 원문을 볼 때는 권한이 필요하고 열람 감사 로그가 남습니다. **AI로는 어떤 경우에도 보내지 않습니다.**

## 로그와 감사

- 다음 값은 어떤 로그에도 원문으로 남기지 않습니다: 비밀번호, OTP, 복구 코드, access·refresh·mfa 토큰, `Authorization` 헤더, 쿠키, `Restricted` 필드
- Serilog에 다음을 적용합니다.
  - 분류 메타데이터 기반 가림(destructuring policy)
  - 요청 로그에서 헤더와 본문 제외
  - 정규식 기반 가림(주민번호·카드번호 패턴)을 마지막 방어선으로 둠
- 감사 로그는 다음을 기록합니다: 누가, 언제, 어떤 엔티티의 어떤 필드를 바꿨는지(이전 값과 새 값, 민감 필드는 가린 값), 민감정보 열람, 권한 변경, AI 사용
- 감사 로그는 애플리케이션 계정이 **추가만** 할 수 있게 DB 권한을 설정합니다(수정과 삭제 불가).

## 보존과 파기 (초안)

| 데이터 | 보존 기간 | 비고 |
|---|---|---|
| 퇴직자 인사 정보 | 법정 보존 기간 이후 파기 | 기간은 업무별로 확인 필요 |
| 회계 전표 | 법정 보존 기간 | |
| AI 감사 로그 (가명화된 상태) | 1년 (가정) | |
| 로그인 감사 로그 | 1년 이상 (가정) | |

> 법정 보존 기간은 실제 법령을 확인한 뒤 확정합니다 (확인 필요).

## 전송 구간

- HTTPS(TLS 1.2 이상)만 사용합니다.
- 서버에서 외부로 나가는 통신은 방화벽 허용 목록으로 제한합니다 ([deployment.md](../01-architecture/deployment.md)).
- AI 외부 전송은 AI Gateway의 정책을 따릅니다 ([ai-gateway.md](../04-ai/ai-gateway.md)).
