# 설계 결정 기록 (ADR)

되돌리기 어렵거나 여러 모듈에 영향을 주는 결정은 이곳에 기록합니다. ADR은 **고치지 않습니다.** 결정이 바뀌면 새 ADR을 쓰고, 이전 ADR의 상태를 `대체됨(ADR-XXXX)`으로 바꿉니다.

## 목록

| 번호 | 제목 | 상태 |
|---|---|---|
| [0001](0001-modular-monolith.md) | 모듈형 모놀리스 아키텍처 | 제안 |
| [0002](0002-single-tenant-deployment.md) | 회사별 설치형 (단일 테넌트) 배포 | 제안 |
| [0003](0003-authentication-mfa-jwt.md) | 사번·비밀번호 + TOTP MFA + JWT·refresh 회전 | 제안 |
| [0004](0004-velopack-auto-update.md) | Velopack 기반 데스크톱 자동 업데이트 | 제안 |
| [0005](0005-ai-gateway-local-llm.md) | AI Gateway를 통한 단일 출구와 로컬 LLM | 제안 |
| [0006](0006-application-level-field-encryption.md) | 민감 필드는 애플리케이션 계층에서 암호화 | 제안 |
| [0007](0007-org-based-access-control.md) | 조직 기반 역할 부여 (상속 + 허용 합산 + 예외) | 승인 |

상태 값: `제안` → `승인` / `거절`, 나중에 `대체됨`

## 템플릿

```markdown
# ADR-XXXX: 제목

- 상태: 제안
- 날짜: YYYY-MM-DD

## 배경
어떤 문제가 있고, 어떤 제약이 있는가.

## 결정
무엇을 하기로 했는가.

## 검토한 대안
| 대안 | 장점 | 단점 |

## 결과
이 결정으로 좋아지는 것, 감수해야 하는 것, 이후에 해야 할 일.
```
