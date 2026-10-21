# 용어집

> 상태: 초안 · 갱신: 2026-10-21

코드의 클래스, 속성, 테이블, API 경로 이름은 아래 **영문명**을 따릅니다. 새 용어가 생기면 이 표에 먼저 추가합니다.

## 공통·조직

| 한국어 | 영문명 (코드) | 설명 |
|---|---|---|
| 사번 | `EmployeeNumber` | 로그인 ID로 쓰는 직원 고유 번호 |
| 직원 | `Employee` | 시스템에 등록된 인력. 외부 인력도 포함하며, 고용 형태로 구분합니다 |
| 사용자 계정 | `UserAccount` | 로그인 주체. `Employee`와 1:1로 연결됩니다 |
| 조직 (조직 단위) | `OrgUnit` | 회사·본부·부서·팀을 모두 포함하는 트리 노드 ([organization.md](../02-domain/organization.md)) |
| 조직 유형 | `OrgUnitType` | `Company`(회사), `Division`(본부), `Department`(부서), `Team`(팀) |
| 소속 | `OrgMembership` | 직원과 조직의 연결. 주 소속(`IsPrimary`) 하나 + 겸직 여러 개 |
| 겸직 | `OrgMembership` (`IsPrimary = false`) | |
| 조직장 | `IsHead` | 조직 하나에 최대 한 명 |
| 조직개편 | `OrgChangePlan` | 효력 발생일에 한꺼번에 적용되는 변경 묶음 |
| 조직도 | `OrgChart` | |
| 직급 | `JobGrade` | 사원·대리·과장 등 |
| 직책 | `JobTitle` | 팀장·본부장 등 |
| 고객사 | `Client` | 발주처 |
| 협력사 | `Partner` | 외주 인력을 공급하는 회사 |

## 프로젝트·계약

| 한국어 | 영문명 (코드) | 설명 |
|---|---|---|
| 계약 | `Contract` | 고객사(또는 협력사)와 맺은 계약 |
| 변경 계약 | `ContractAmendment` | 금액·기간·범위를 바꾸는 계약 |
| 도급 계약 | `ContractType.Outsourcing` | 일의 완성을 약속하는 계약. SI 구축이 대표적입니다 |
| 위임·용역 계약 | `ContractType.Service` | 업무 수행을 약속하는 계약. SM 운영이 대표적입니다 |
| 원청 / 하도급 | `ContractTier.Prime` / `Sub` | 우리 회사의 계약상 위치 |
| 프로젝트 | `Project` | 프로젝트 유형(`ProjectType`)은 SI 또는 SM |
| 마일스톤 | `Milestone` | 중간 목표 시점. 기성 청구와 연결될 수 있습니다 |
| 산출물 | `Deliverable` | 납품 문서·결과물 |
| 작업 (WBS) | `WorkItem` | 일정 관리 단위 |
| 투입 | `Assignment` | 인력을 프로젝트에 배정하는 것 (기간 + 투입률) |
| M/M (맨먼스) | `ManMonth` | 1명이 1개월 전담하면 1.0 M/M |
| 투입률 | `AllocationRate` | 0.0~1.0. 0.5면 하루 절반 투입 |
| 기성 | `ProgressBilling` | 진척에 따라 대금을 청구하는 것 |
| 검수 | `Acceptance` | 고객의 산출물 확인과 승인 |
| 하자보수 | `Warranty` | 검수 이후 무상 유지보수 기간 |
| 상주 | `OnSite` | 고객사 현장에서 근무하는 것 (근무 장소 속성) |
| SR (서비스 요청) | `ServiceRequest` | SM 운영 중 들어오는 요청 |
| SLA | `ServiceLevelAgreement` | SM 서비스 수준 협약 |

## 인사

| 한국어 | 영문명 (코드) | 설명 |
|---|---|---|
| 고용 형태 | `EmploymentType` | `Regular`(정규직), `FixedTerm`(기간제·계약직), `Dispatched`(파견 근로자), `Freelancer`(프리랜서), `PartnerStaff`(협력사 인력) |
| 근로 계약 | `EmploymentContract` | 기간이 정해진 계약은 이력을 남깁니다 |
| 파견 | `Dispatch` | 근로자파견법에 따른 파견. 상주(`OnSite`)와 다른 개념입니다 |
| 파견사업주 / 사용사업주 | `DispatchAgency` / `UserCompany` | |
| 기술 등급 | `SkillLevel` | 업계 관행상 쓰는 초급·중급·고급·특급 |
| 보유 기술 | `Skill` | |
| 경력기술서 | `CareerProfile` | |
| 퇴직 | `Termination` | |

## 회계·클라우드 비용

| 한국어 | 영문명 (코드) | 설명 |
|---|---|---|
| 계정과목 | `Account` | |
| 계정과목표 | `ChartOfAccounts` | |
| 전표 | `JournalEntry` | 전표의 각 줄은 `JournalLine`. 차변 합계와 대변 합계가 같아야 합니다 |
| 차변 / 대변 | `Debit` / `Credit` | |
| 세금계산서 | `TaxInvoice` | |
| 매출 / 매입 | `Revenue` / `Expense` | |
| 원가 | `Cost` | |
| 프로젝트 손익 | `ProjectProfitAndLoss` | |
| 회계 기간 마감 | `PeriodClose` | |
| 환율 | `ExchangeRate` | |
| 클라우드 비용 | `CloudCost` | 한 건의 비용 기록은 `CloudCostRecord` |
| 클라우드 계정 연결 | `CloudAccountConnection` | AWS 계정 또는 Azure 구독 연결 정보 |
| 비용 배분 | `CostAllocation` | 클라우드 비용을 프로젝트에 귀속시키는 것 |
| 예산 | `Budget` | |

## 보안·AI

| 한국어 | 영문명 (코드) | 설명 |
|---|---|---|
| 다중 인증 | `Mfa` | 여기서는 TOTP 방식 |
| 복구 코드 | `RecoveryCode` | |
| 데이터 분류 | `DataClassification` | `Public`, `Internal`, `Confidential`, `Restricted` |
| 비식별화 | `Deidentification` | |
| 가명화 | `Pseudonymization` | 원래 값을 `[PERSON_1]` 같은 토큰으로 바꾸는 것 |
| 재식별 (복원) | `Reidentification` | 토큰을 원래 값으로 되돌리는 것 |
| 검열 | `ContentGuard` | 입력과 출력에 정책을 적용하는 것 |
| AI 용도 | `AiPurpose` | 등록된 AI 사용 시나리오 ID |
| 감사 로그 | `AuditLog` | |
| 권한 | `Permission` | `{module}.{resource}.{action}`. 코드에서만 정의 |
| 역할 | `Role` | 권한 묶음 |
| 역할 부여 | `RoleAssignment` | 대상(`User`, `OrgUnit`, `OrgHead`) + 역할 + 데이터 범위 + 기간 |
| 하위 조직 포함 | `IncludeDescendants` | 조직 단위 부여의 상속 여부 |
| 예외 | `RoleAssignmentExclusion` | 조직 단위 부여에서 특정 구성원을 빼는 것 |
| 데이터 범위 | `DataScope` | `All`, `OwnUnit`, `OwnUnitAndDescendants`, `SpecifiedUnits`, `AssignedProjects`, `Self` |
| 근거 조직 | (계산 값) | 역할을 받게 된 소속 조직. 상대 범위의 기준 |
| 유효 권한 | `EffectivePermission` | 모든 부여를 합산한 최종 권한 |
