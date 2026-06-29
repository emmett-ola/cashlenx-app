param(
    [int]$ServerPort = 18081,
    [string]$MongoImage = "mongo:7.0",
    [string]$Device = "windows"
)

$ErrorActionPreference = "Continue"
$appRoot = Split-Path -Parent $PSScriptRoot
$serverRoot = Resolve-Path (Join-Path $appRoot "..\cashlenx-server")
$runId = "$(Get-Date -Format yyyyMMddHHmmss)-$PID"
$container = "cashlenx-flutter-smoke-mongodb-$runId"
$dbName = "cashlenx_flutter_smoke_$($runId -replace '-', '_')"
$username = "flutter_smoke_$($runId -replace '-', '_')"
$email = "$username@example.test"
$signupCode = "abc123"
$resetCode = "def456"
$password = "SmokePass123!"
$newPassword = "SmokePass456!"
$tempDir = Join-Path $env:TEMP "cashlenx-flutter-smoke-$runId"
$serverExe = Join-Path $tempDir "cashlenx-server.exe"
$stdoutLog = Join-Path $tempDir "server.out.log"
$stderrLog = Join-Path $tempDir "server.err.log"
$server = $null

New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    Push-Location $serverRoot
    try {
        go build -o $serverExe .
        if ($LASTEXITCODE -ne 0) { throw "server build failed" }
    } finally {
        Pop-Location
    }

    docker run -d --name $container -p 127.0.0.1::27017 `
        -e MONGO_INITDB_ROOT_USERNAME=cashlenx `
        -e MONGO_INITDB_ROOT_PASSWORD=cashlenx123 `
        -e MONGO_INITDB_DATABASE=$dbName $MongoImage | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "MongoDB container failed to start" }

    $mongoPort = ((docker port $container 27017/tcp) -split ':')[-1].Trim()
    $mongoUri = "mongodb://cashlenx:cashlenx123@localhost:27017/admin?authSource=admin"
    $mongoReady = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        docker exec $container mongosh $mongoUri --quiet `
            --eval 'db.adminCommand({ ping: 1 }).ok' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $mongoReady = $true
            break
        }
        Start-Sleep -Seconds 1
    }
    if (-not $mongoReady) { throw "MongoDB authenticated readiness timed out" }

    $seedScript = "db = db.getSiblingDB('$dbName'); const now = new Date(); " +
        "const expires = new Date(Date.now() + 3600000); " +
        "db.operation_confirm_codes.insertMany([" +
        "{_id:ObjectId(),user_id:'',code:'$signupCode',verification_token:'',operation_type:'signup',payload:'$email',expires_time:expires,used_time:null,create_time:now,update_time:now,is_delete:false}," +
        "{_id:ObjectId(),user_id:'',code:'$resetCode',verification_token:'',operation_type:'password_reset',payload:'$email',expires_time:expires,used_time:null,create_time:now,update_time:now,is_delete:false}" +
        "]);"
    docker exec $container mongosh $mongoUri --quiet --eval $seedScript | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "verification seed failed" }

    $env:ENV = "test"
    $env:SERVER_HOST = "127.0.0.1"
    $env:SERVER_PORT = "$ServerPort"
    $env:API_VERSION = "v0"
    $env:SCHEMA_VALIDATION = "true"
    $env:JWT_SECRET = "flutter-smoke-test-secret"
    $env:AUTH_REGISTRATION_ENABLED = "true"
    $env:ADMIN_USERNAME = "admin"
    $env:ADMIN_PASSWORD = "admin"
    $env:DB_TYPE = "mongodb"
    $env:DB_NAME = $dbName
    $env:MONGO_DB_URI = "mongodb://cashlenx:cashlenx123@localhost:$mongoPort/${dbName}?authSource=admin&retryWrites=false"

    $server = Start-Process -FilePath $serverExe `
        -ArgumentList @("open", "start", "-p", "$ServerPort") `
        -WorkingDirectory $serverRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

    $serverReady = $false
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing `
                -Uri "http://127.0.0.1:$ServerPort/api/v0/open/health" -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                $serverReady = $true
                break
            }
        } catch {}
        if ($server.HasExited) {
            throw "API server exited: $([IO.File]::ReadAllText($stderrLog))"
        }
        Start-Sleep -Seconds 1
    }
    if (-not $serverReady) { throw "API server readiness timed out" }

    Push-Location $appRoot
    try {
        flutter test integration_test/api_smoke_test.dart -d $Device `
            --dart-define="CASHLENX_SMOKE_BASE_URL=http://127.0.0.1:$ServerPort/api/v0" `
            --dart-define="CASHLENX_SIGNUP_EMAIL=$email" `
            --dart-define="CASHLENX_SIGNUP_CODE=$signupCode" `
            --dart-define="CASHLENX_RESET_CODE=$resetCode" `
            --dart-define="CASHLENX_SMOKE_USERNAME=$username" `
            --dart-define="CASHLENX_SMOKE_PASSWORD=$password" `
            --dart-define="CASHLENX_SMOKE_NEW_PASSWORD=$newPassword" `
            --dart-define=CASHLENX_ADMIN_USERNAME=admin `
            --dart-define=CASHLENX_ADMIN_PASSWORD=admin
        if ($LASTEXITCODE -ne 0) { throw "Flutter integration smoke failed" }
    } finally {
        Pop-Location
    }
} finally {
    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    }
    docker rm -f $container 2>$null | Out-Null
    if (Test-Path $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
