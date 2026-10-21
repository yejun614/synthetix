-- =============================================================================
-- Synthetix DDL 00: 스키마
-- 대상: SQL Server 2025 (호환성 수준 170)
-- 설명: ../ddl/README.md
-- =============================================================================

-- 필터링된 인덱스, 임시 테이블, json 타입에 필요한 옵션 (sqlcmd 기본값은 QUOTED_IDENTIFIER OFF)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE SCHEMA iam;        -- Identity 모듈 (IDENTITY는 T-SQL 예약어라서 iam을 씀)
GO
CREATE SCHEMA hr;         -- HR 모듈 (조직 포함)
GO
CREATE SCHEMA projects;   -- Projects 모듈
GO
CREATE SCHEMA accounting; -- Accounting 모듈 (클라우드 비용 포함)
GO
CREATE SCHEMA platform;   -- Platform 모듈
GO
CREATE SCHEMA audit;      -- 감사 로그 (추가만 가능)
GO
CREATE SCHEMA ai;         -- AI 모듈
GO
CREATE SCHEMA outbox;     -- 모듈 사이 통합 이벤트
GO
-- hangfire 스키마는 Hangfire가 처음 실행될 때 스스로 만듭니다.
