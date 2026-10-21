# 미결 사항

> 상태: 초안 · 갱신: 2026-10-21

아직 사용자가 확정하지 않은 결정들입니다. 설계는 **현재 가정**을 기준으로 진행하고, 결정이 나면 상태를 바꾼 뒤 관련 문서(필요하면 ADR)에 반영합니다.

| ID | 질문 | 현재 가정 | 영향 받는 문서 | 상태 |
|---|---|---|---|---|
| Q1 | 배포 모델: 회사별 설치형인가, 멀티테넌트 SaaS인가? | 회사별 설치형(단일 테넌트) | [ADR-0002](../adr/0002-single-tenant-deployment.md), [deployment.md](../01-architecture/deployment.md) | 가정 |
| Q2 | 웹 클라이언트도 Base URL을 입력하는가? | 입력하지 않고 접속한 출처(origin)를 그대로 사용 | [authentication.md](../03-security/authentication.md) | 가정 |
| Q3 | MVP 범위와 순서 | 인증 → 프로젝트·계약 + AI Gateway → 인사 → 회계 | [roadmap.md](roadmap.md) | 가정 |
| Q4 | 로컬 LLM 실행 환경 (GPU 유무, 모델 크기) | Ollama + 한국어 지원 7~14B급 모델. 하드웨어 확인 필요 | [ai-gateway.md](../04-ai/ai-gateway.md) | 가정 |
| Q5 | 문서와 코드의 언어 | 문서·주석은 한국어, 식별자·커밋은 영어 | [AGENTS.md](../../AGENTS.md) | 가정 |
| Q6 | 코드 서명 인증서 | 개발 중에는 자체 서명. 서명 단계만 파이프라인에 넣어 둠 | [client-update.md](../01-architecture/client-update.md) | 가정 |
| Q7 | 데스크톱 대상 OS | Windows만 | [client-update.md](../01-architecture/client-update.md) | 가정 |
| Q8 | "파견"의 의미: 법적 파견 근로자인가, 고객사 상주 근무인가? | 둘 다 모델링. 고용 형태 `Dispatched`와 근무 장소 `OnSite`로 구분 | [hr.md](../02-domain/hr.md) | 가정 |
| Q9 | 클라우드 비용을 고객사에 재청구하는가(MSP 모델)? | 아니오. 회사 내부 원가 배분만 함. 재청구는 확장 항목 | [cloud-cost.md](../02-domain/cloud-cost.md) | 가정 |
| Q10 | 세션 유지 기간 | refresh 토큰 최대 12시간(업무일 하루). 매일 MFA를 다시 거침 | [authentication.md](../03-security/authentication.md) | 가정 |
| Q11 | TOTP 구현: ASP.NET Core Identity 내장 기능인가, 직접 구현인가? | Identity Core를 쓰고, 코드 재사용 방지와 키 암호화는 확장해서 구현. 안 되면 Otp.NET으로 직접 구현 | [ADR-0003](../adr/0003-authentication-mfa-jwt.md) | 검토 중 |
| Q12 | 급여 기능 범위 | 급여 계산은 하지 않음. 인건비 원가 계산용 표준 단가만 관리 | [hr.md](../02-domain/hr.md), [accounting.md](../02-domain/accounting.md) | 가정 |
| Q13 | 대상 회사 규모 | 50~500명. 동시 접속 수백 명 수준 | [deployment.md](../01-architecture/deployment.md) | 가정 |
| Q14 | 구성원 단위로 권한을 "빼는" 방식 | 일반 Deny는 두지 않음. 조직 부여에서 특정 구성원을 빼는 Exclusion만 | [authorization.md](../03-security/authorization.md), [ADR-0007](../adr/0007-org-based-access-control.md) | 확정 (2026-10-21) |
| Q15 | 부서 관리자에게 권한 관리 위임 | Phase 2 이후. 위임 가능 역할만, 자기 범위 안에서만 | [authorization.md](../03-security/authorization.md) | 확정 (2026-10-21) |
| Q16 | 조직도 공개 범위 | 전 직원이 구조·이름·직급·직책을 봄. 연락처와 고용 정보는 권한에 따라 | [organization.md](../02-domain/organization.md) | 확정 (2026-10-21) |
| Q17 | 협력사·파견 인력의 조직도 표시 | 표시하되 배지로 구분, 필터로 숨길 수 있음 | [organization.md](../02-domain/organization.md) | 확정 (2026-10-21) |
| Q18 | 조직 계층 | 회사 > 본부 > 부서 > 팀 고정 순서, 중간 단계 생략 허용 | [organization.md](../02-domain/organization.md) | 가정 |
