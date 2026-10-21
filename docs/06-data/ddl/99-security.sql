-- =============================================================================
-- Synthetix DDL 99: DB 권한
-- 로그인과 사용자 생성은 설치 환경마다 다르므로 여기서 하지 않습니다.
-- 설치 스크립트에서 만든 DB 사용자를 아래 역할에 추가합니다.
--   ALTER ROLE synthetix_app ADD MEMBER [<앱 풀 계정>];
-- =============================================================================

-- 필터링된 인덱스, 임시 테이블, json 타입에 필요한 옵션 (sqlcmd 기본값은 QUOTED_IDENTIFIER OFF)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 애플리케이션 실행 계정
CREATE ROLE synthetix_app;
GO
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::iam        TO synthetix_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::hr         TO synthetix_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::projects   TO synthetix_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::accounting TO synthetix_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::platform   TO synthetix_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::ai         TO synthetix_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::outbox     TO synthetix_app;
-- 감사 로그는 추가와 조회만 가능
GRANT SELECT, INSERT ON SCHEMA::audit TO synthetix_app;
DENY  UPDATE, DELETE ON SCHEMA::audit TO synthetix_app;
GO

-- 보존 기간이 지난 감사 로그를 지우는 정리 작업 전용 계정
CREATE ROLE synthetix_audit_maintenance;
GO
GRANT SELECT, DELETE ON SCHEMA::audit TO synthetix_audit_maintenance;
GO

-- 마이그레이션(스키마 변경)은 배포 시에만 쓰는 별도 계정이 db_ddladmin 등으로 실행합니다.
