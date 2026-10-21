# 기술 스택

> 상태: 초안 · 갱신: 2026-10-21

라이브러리를 추가하기 전에 이 문서를 확인하고, 추가했다면 이 표도 갱신합니다. **구체적인 버전은 구현을 시작할 때 최신 안정판을 확인해서 `Directory.Packages.props`에 고정합니다.**

## 런타임과 플랫폼

| 영역 | 선택 | 비고 |
|---|---|---|
| 런타임 | .NET 10 (LTS) | 서버와 클라이언트 모두 |
| 서버 | ASP.NET Core Minimal APIs | IIS In-Process 호스팅 |
| DB | SQL Server 2025 | 벡터 검색(`VECTOR` 타입)을 RAG에 사용. 2022를 써야 하면 벡터 기능만 대체합니다 |
| ORM | EF Core 10 | 모듈마다 DbContext 하나 |
| 클라이언트 | Avalonia (최신 안정판) | Desktop(Windows)과 Browser(WASM) |
| 웹 서버 | IIS (Windows Server) | Azure 확장 시 App Service |

## 서버 라이브러리

| 용도 | 선택 | 대안과 비고 |
|---|---|---|
| 인증 | ASP.NET Core Identity Core + JwtBearer | TOTP 구현 방식은 미결 사항 Q11 |
| API 문서 | Microsoft.AspNetCore.OpenApi + Scalar | Swashbuckle은 쓰지 않습니다 |
| 검증 | Contracts에 직접 작성한 검증기 (의존성 없음) | 클라이언트와 공유해야 하므로 외부 라이브러리를 피합니다. FluentValidation도 후보 |
| 객체 매핑 | 직접 작성하거나 Mapperly(소스 생성) | AutoMapper는 쓰지 않습니다 |
| 로깅 | Serilog | 민감정보 가리기 기능을 추가로 구현 |
| 백그라운드 작업 | Hangfire + SQL Server 저장소 | 대시보드는 관리자만 접근 |
| AI 추상화 | Microsoft.Extensions.AI | |
| LLM 연결 | Microsoft.Extensions.AI.OpenAI (OpenAI 호환 API) | Ollama, vLLM, llama.cpp, Azure OpenAI를 같은 코드로 호출 |
| 문서 텍스트 추출 | PdfPig 등 (확인 필요) | 스캔본 OCR은 Phase 4 |
| 클라우드 비용 | AWSSDK.CostExplorer, Azure.ResourceManager.CostManagement | |
| 요청 제한 | ASP.NET Core Rate Limiting (내장) | |
| 트리 계층 | Microsoft.EntityFrameworkCore.SqlServer.HierarchyId | 조직 구조 |
| Excel 가져오기 | ClosedXML (MIT) | 조직·직원 초기 가져오기. CSV는 직접 파싱하거나 CsvHelper |

## 클라이언트 라이브러리

| 용도 | 선택 |
|---|---|
| MVVM | CommunityToolkit.Mvvm (소스 생성기) |
| DI | Microsoft.Extensions.DependencyInjection |
| 표(그리드) | Avalonia.Controls.DataGrid |
| 자동 업데이트 | Velopack (Desktop만) |
| QR 코드 | QRCoder (TOTP 등록 화면) |
| 확대·축소, 화면 이동 | Avalonia.Controls.PanAndZoom (조직도). 라이선스와 WASM 동작 확인 필요 |
| 토큰 저장 | System.Security.Cryptography.ProtectedData (DPAPI, Desktop) |

## 테스트

| 용도 | 선택 | 비고 |
|---|---|---|
| 테스트 프레임워크 | xUnit v3 | |
| 단언 | Shouldly | FluentAssertions는 v8부터 상용 라이선스라서 쓰지 않습니다 |
| DB 통합 테스트 | Testcontainers (SQL Server) | |
| API 통합 테스트 | WebApplicationFactory | |
| 아키텍처 테스트 | ArchUnitNET 또는 NetArchTest | |
| UI 테스트 | Avalonia.Headless | |
| 시간 | Microsoft.Extensions.TimeProvider.Testing (`FakeTimeProvider`) | TOTP와 토큰 만료 테스트에 사용 |

## 쓰지 않는 라이브러리

| 라이브러리 | 이유 |
|---|---|
| MediatR, AutoMapper | 2025년에 상용 라이선스로 전환 |
| FluentAssertions (v8 이상) | 상용 라이선스 |
| MassTransit (v9 이상) | 상용 라이선스. 지금 규모에서는 메시지 브로커도 필요 없습니다 |

> 라이선스 정책은 바뀔 수 있습니다. 새 라이브러리를 들이기 전에 라이선스를 확인합니다.

## 개발 환경

- Visual Studio 2026 또는 Rider, .NET 10 SDK
- 로컬 개발에서 SQL Server는 Docker 컨테이너나 Developer Edition을 씁니다
- 로컬 LLM은 Ollama를 씁니다 (미결 사항 Q4)
