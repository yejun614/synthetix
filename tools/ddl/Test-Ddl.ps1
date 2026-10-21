<#
.SYNOPSIS
    docs/06-data/ddl 의 DDL을 SQL Server 2025 컨테이너에서 실행하고, 제약조건 테스트와 ERD 대조를 합니다.

.DESCRIPTION
    1. 검증용 컨테이너를 새로 띄웁니다 (같은 이름의 기존 컨테이너는 지웁니다).
    2. 빈 DB를 만들고 ddl/*.sql 을 파일 이름 순서대로 실행합니다.
    3. ddl/tests/*.sql 을 실행합니다 (제약조건이 잘못된 데이터를 거부하는지 확인).
    4. erd/*.md 의 Mermaid 테이블과 DDL의 테이블·컬럼이 일치하는지 대조합니다.
    5. 컨테이너를 지웁니다 (-KeepContainer 이면 남겨 둠).

.EXAMPLE
    ./tools/ddl/Test-Ddl.ps1
    ./tools/ddl/Test-Ddl.ps1 -KeepContainer
#>
[CmdletBinding()]
param(
    [string]$Image = 'mcr.microsoft.com/mssql/server:2025-latest',
    [string]$ContainerName = 'synthetix-ddl-check',
    [string]$Database = 'SynthetixDdlCheck',
    [switch]$KeepContainer
)

# 네이티브 명령의 stderr가 예외로 바뀌지 않도록 Continue로 두고, 종료 코드를 직접 확인합니다.
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ddlDir = Join-Path $repoRoot 'docs\06-data\ddl'
$erdDir = Join-Path $repoRoot 'docs\06-data\erd'
$sqlcmd = '/opt/mssql-tools18/bin/sqlcmd'
$password = 'Sx' + [Guid]::NewGuid().ToString('N').Substring(0, 20) + '!aA'

# sqlcmd 출력을 그대로 내보냅니다. 성공 여부는 호출한 쪽에서 $LASTEXITCODE로 확인합니다.
function Invoke-Sql {
    param([string[]]$Arguments)
    & docker exec $ContainerName $sqlcmd -C -S localhost -U sa -P $password -b @Arguments
}

function Get-ErdTables {
    # 반환: @{ 'schema.Table' = [string[]]컬럼 }
    $defaultSchema = @{ 'identity' = 'iam'; 'hr' = 'hr'; 'projects' = 'projects'; 'accounting' = 'accounting'; 'platform' = 'platform' }
    $knownSchemas = @('iam', 'hr', 'projects', 'accounting', 'platform', 'audit', 'ai', 'outbox')
    $result = @{}
    foreach ($file in Get-ChildItem $erdDir -Filter '*.md' | Where-Object Name -ne 'README.md') {
        $text = (Get-Content $file.FullName -Raw -Encoding UTF8) -replace "`r`n", "`n"
        $fileSchema = $defaultSchema[$file.BaseName]
        foreach ($section in ($text -split "`n## ")) {
            $firstWord = ($section -split '\s', 2)[0]
            $schema = $fileSchema
            if ($knownSchemas -contains $firstWord) { $schema = $firstWord }
            $blocks = [regex]::Matches($section, '(?ms)^\s{4}(\w+) \{\n(.*?)^\s{4}\}')
            foreach ($b in $blocks) {
                $cols = [regex]::Matches($b.Groups[2].Value, '(?m)^\s+\w+ (\w+)') | ForEach-Object { $_.Groups[1].Value }
                if (@($cols).Count -le 1) { continue }   # 다른 다이어그램을 가리키는 참조용 스텁
                $result["$schema.$($b.Groups[1].Value)"] = @($cols)
            }
        }
    }
    return $result
}

function Get-DdlTables {
    $result = @{}
    foreach ($file in Get-ChildItem $ddlDir -Filter '*.sql') {
        $text = (Get-Content $file.FullName -Raw -Encoding UTF8) -replace "`r`n", "`n"
        foreach ($m in [regex]::Matches($text, '(?s)CREATE TABLE (\w+)\.(\w+) \((.*?)\n\)')) {
            $cols = [regex]::Matches($m.Groups[3].Value, '(?m)^\s{4}(\w+)\s+\w') |
                ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $_ -notin @('CONSTRAINT', 'PERIOD') }
            $result["$($m.Groups[1].Value).$($m.Groups[2].Value)"] = @($cols)
        }
    }
    return $result
}

$failed = $false
try {
    # 1. 컨테이너
    Write-Host "== 컨테이너 시작: $Image"
    & docker rm -f $ContainerName 2>$null | Out-Null
    & docker run -d --name $ContainerName -e ACCEPT_EULA=Y -e "MSSQL_SA_PASSWORD=$password" -e MSSQL_PID=Developer $Image | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'docker run 실패' }

    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        & docker exec $ContainerName $sqlcmd -C -S localhost -U sa -P $password -Q 'SELECT 1' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) { throw 'SQL Server가 2분 안에 준비되지 않았습니다.' }

    # 2. DDL
    Write-Host "== DDL 실행"
    Invoke-Sql @('-Q', "CREATE DATABASE $Database COLLATE Korean_100_CI_AS_SC_UTF8;") | Write-Host
    if ($LASTEXITCODE -ne 0) { throw 'DB 생성 실패' }
    & docker exec $ContainerName mkdir -p /tmp/ddl/tests | Out-Null
    $scripts = @(Get-ChildItem $ddlDir -Filter '*.sql' | Sort-Object Name)
    $tests = @(Get-ChildItem (Join-Path $ddlDir 'tests') -Filter '*.sql' | Sort-Object Name)
    foreach ($f in $scripts) { & docker cp $f.FullName "${ContainerName}:/tmp/ddl/$($f.Name)" | Out-Null }
    foreach ($f in $tests) { & docker cp $f.FullName "${ContainerName}:/tmp/ddl/tests/$($f.Name)" | Out-Null }

    foreach ($f in $scripts) {
        $output = Invoke-Sql @('-d', $Database, '-i', "/tmp/ddl/$($f.Name)")
        if ($LASTEXITCODE -ne 0) { $output | Write-Host; throw "DDL 실패: $($f.Name)" }
        Write-Host "ok   $($f.Name)"
    }

    # 3. 제약조건 테스트
    Write-Host "== 제약조건 테스트"
    foreach ($f in $tests) {
        Invoke-Sql @('-d', $Database, '-i', "/tmp/ddl/tests/$($f.Name)") | Write-Host
        if ($LASTEXITCODE -ne 0) { throw "테스트 실패: $($f.Name)" }
    }

    # 4. ERD 대조
    Write-Host "== ERD와 DDL 대조"
    $common = @('CreatedAt', 'CreatedBy', 'UpdatedAt', 'UpdatedBy', 'RowVersion', 'PeriodStart', 'PeriodEnd')
    $erd = Get-ErdTables
    $ddl = Get-DdlTables
    $names = @($erd.Keys) + @($ddl.Keys) | Sort-Object -Unique
    foreach ($t in $names) {
        if (-not $erd.ContainsKey($t)) { Write-Host "ERD에 없음: $t"; $failed = $true; continue }
        if (-not $ddl.ContainsKey($t)) { Write-Host "DDL에 없음: $t"; $failed = $true; continue }
        $a = @($erd[$t] | Where-Object { $_ -notin $common -and $_ -notin $ddl[$t] })
        $b = @($ddl[$t] | Where-Object { $_ -notin $common -and $_ -notin $erd[$t] })
        if ($a.Count -gt 0 -or $b.Count -gt 0) {
            Write-Host "$t : ERD에만 [$($a -join ', ')] / DDL에만 [$($b -join ', ')]"
            $failed = $true
        }
    }
    if ($failed) { throw 'ERD와 DDL이 다릅니다.' }
    Write-Host "ok   테이블 $($ddl.Count)개 일치"
    Write-Host "== 전체 통과"
}
catch {
    $failed = $true
    Write-Host "!! $($_.Exception.Message)"
}
finally {
    if (-not $KeepContainer) { & docker rm -f $ContainerName 2>$null | Out-Null }
}
if ($failed) { exit 1 }
