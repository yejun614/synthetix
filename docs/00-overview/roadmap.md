# 로드맵

> 상태: 초안 · 갱신: 2026-10-21

단계마다 **실제로 시연할 수 있는 결과**를 목표로 합니다. 범위는 [open-questions.md](open-questions.md)의 Q3에 따라 바뀔 수 있습니다.

## Phase 0: 기반

목표: 데스크톱과 웹에서 로그인(MFA 포함)하고, 자동 업데이트를 받을 수 있게 합니다.

- [ ] 솔루션 골격, 중앙 패키지 관리, `.editorconfig`, CI (빌드와 테스트)
- [ ] 서버 호스트와 모듈 등록 구조, 아키텍처 테스트
- [ ] DB 마이그레이션 체계 (모듈별 DbContext와 스키마)
- [ ] 인증: 서버 확인 → 사번·비밀번호 → TOTP 등록·검증 → JWT와 refresh 회전 ([authentication.md](../03-security/authentication.md))
- [ ] 조직 기본: 조직 단위·소속(겸직 포함), 초기 설정 마법사, CSV/Excel 가져오기 ([organization.md](../02-domain/organization.md))
- [ ] 권한 체계: 역할, 역할 부여(개인·조직·조직장 + 상속 + 예외), 데이터 범위, 유효 권한 계산과 출처 설명 ([authorization.md](../03-security/authorization.md))
- [ ] 관리 화면 v1: 조직 트리(목록형), 역할·부여 관리
- [ ] 감사 로그 기반, 로그에서 민감정보 가리기(redaction)
- [ ] Avalonia 클라이언트: 로그인 화면과 메인 셸 (Desktop, Browser)
- [ ] Velopack 자동 업데이트와 버전 호환 확인 ([client-update.md](../01-architecture/client-update.md))
- [ ] IIS 배포 문서와 설치 번들

## Phase 1: 프로젝트·계약 + AI Gateway

목표: 계약서를 올리면 AI가 주요 정보를 추출하고, 사람이 확인하면 프로젝트와 일정이 만들어집니다.

- [ ] 고객사, 계약(변경 계약 포함), 계약 문서 저장
- [ ] 프로젝트, 마일스톤, WBS, 투입(M/M)
- [ ] AI Gateway: 로컬 LLM 연결, 비식별화, 검열, 감사 로그 ([ai-gateway.md](../04-ai/ai-gateway.md))
- [ ] AI-PRJ-01 계약서 정보 추출, AI-PRJ-03 주간 보고 초안 ([use-cases.md](../04-ai/use-cases.md))
- [ ] 비식별화 평가셋 v1

## Phase 2: 인사

목표: 인력 계약 만료를 놓치지 않고, 프로젝트에 맞는 인력을 찾습니다.

- [ ] 직원과 고용 형태, 근로 계약 이력, 파견 정보, 협력사 인력
- [ ] 조직도 다이어그램: 조회, 검색, 시점 선택, 편집 모드, 권한 보기 모드, PNG 내보내기
- [ ] 조직개편 예약: 미리보기, 권한 영향 시뮬레이션, 효력 발생일 자동 적용
- [ ] 부서 관리자 권한 위임 (미결 사항 Q15)
- [ ] 기간제 2년, 파견 2년 만료 규칙과 알림
- [ ] 보유 기술과 경력기술서. AI-HR-03 경력기술서 파싱
- [ ] AI-HR-02 프로젝트 인력 추천
- [ ] 민감정보(주민번호 등) 컬럼 암호화와 열람 감사

## Phase 3: 회계·클라우드 비용

목표: 프로젝트별 손익을 클라우드 비용까지 포함해서 봅니다.

- [ ] 계정과목, 전표(승인 절차 포함), 회계 기간 마감
- [ ] 기성·청구와 매출 전표 연동
- [ ] AWS·Azure 비용 수집 (FOCUS 형식으로 정규화), 태그 기반 프로젝트 배분
- [ ] 프로젝트 손익 (매출 − 인건비 − 외주비 − 클라우드 비용)
- [ ] AI-ACC-01 비용 이상 설명, AI-ACC-02 계정과목 추천

## Phase 4: 확장

- [ ] AI-CMN-01 사내 문서 RAG 챗봇 (SQL Server 벡터 검색)
- [ ] AI-CMN-02 자연어 조회
- [ ] Azure 배포 옵션 (App Service, Azure SQL, Key Vault, Blob)
- [ ] SM 운영: SR과 SLA 관리
