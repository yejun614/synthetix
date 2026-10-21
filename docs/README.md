# Synthetix 지식저장소

이 폴더는 Synthetix 개발에 필요한 설계 지식을 모아 두는 곳입니다. 사람과 AI 에이전트가 같은 기준으로 작업할 수 있도록 하는 것이 목적입니다.
에이전트용 진입점은 저장소 루트의 [AGENTS.md](../AGENTS.md)입니다.

## 처음 읽는 순서

1. [00-overview/vision.md](00-overview/vision.md): 무엇을, 왜 만드는가
2. [00-overview/glossary.md](00-overview/glossary.md): 업무 용어와 코드에서 쓰는 영문 이름
3. [01-architecture/system-overview.md](01-architecture/system-overview.md): 전체 구조
4. [00-overview/roadmap.md](00-overview/roadmap.md): 개발 단계
5. [00-overview/open-questions.md](00-overview/open-questions.md): 아직 확정되지 않은 결정

## 목차

| 폴더 | 내용 |
|---|---|
| [00-overview](00-overview/) | 비전, 용어집, 로드맵, 미결 사항 |
| [01-architecture](01-architecture/) | 시스템 구조, 솔루션 구조, 기술 스택, 배포, 클라이언트 자동 업데이트 |
| [02-domain](02-domain/) | 업무 도메인: 프로젝트·계약, 인사, 회계, 클라우드 비용 |
| [03-security](03-security/) | 인증(로그인·MFA·JWT), 인가(권한), 데이터 보호 |
| [04-ai](04-ai/) | AI Gateway, 비식별화·검열, AI 활용 시나리오 |
| [05-api](05-api/) | HTTP API 규칙 |
| [06-data](06-data/) | 데이터베이스 규칙, 모듈별 ERD, 실행 가능한 DDL과 검증 스크립트 |
| [07-client](07-client/) | Avalonia 클라이언트 규칙, 화면 흐름 |
| [conventions](conventions/) | 코딩, Git, 테스트 규칙 |
| [adr](adr/) | 설계 결정 기록(Architecture Decision Records) |

## 문서 작성 규칙

- 문서 첫 부분에 상태를 적습니다: `> 상태: 초안 | 확정 | 폐기 · 갱신: YYYY-MM-DD`
  - **초안**: 논의 중이라 바뀔 수 있습니다.
  - **확정**: 구현의 기준입니다. 바꾸려면 ADR이 필요합니다.
- **문서 하나에 주제 하나**를 다룹니다. 다른 문서에 있는 내용은 복사하지 않고 링크합니다. 같은 내용이 두 곳에 있으면 결국 서로 어긋나기 때문입니다.
- 설계가 바뀌면 **코드보다 문서를 먼저** 고칩니다. 되돌리기 어렵거나 여러 모듈에 영향을 주는 결정은 `adr/`에 기록합니다.
- 다이어그램은 Mermaid로 그려 GitHub에서 바로 보이게 합니다.
- 확인되지 않은 사실이나 가정은 `(가정)` 또는 `(확인 필요)`로 표시하고, [open-questions.md](00-overview/open-questions.md)에 등록합니다.
