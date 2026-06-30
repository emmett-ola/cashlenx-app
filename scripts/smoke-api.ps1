param(
    [int]$ServerPort = 18081,
    [ValidateSet("mongodb", "mysql")]
    [string]$Database = "mongodb",
    [string]$MongoImage = "mongo:7.0",
    [string]$MySqlImage = "mysql:8.0",
    [string]$Device = "windows"
)

$ErrorActionPreference = "Continue"
$appRoot = Split-Path -Parent $PSScriptRoot
$serverRoot = Resolve-Path (Join-Path $appRoot "..\cashlenx-server")
$runId = "$(Get-Date -Format yyyyMMddHHmmss)-$PID"
$container = "cashlenx-flutter-smoke-$Database-$runId"
$dbName = if ($Database -eq "mongodb") {
    "cashlenx_flutter_smoke_$($runId -replace '-', '_')"
} else {
    "cashlenx"
}
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

    if ($Database -eq "mongodb") {
        docker run -d --name $container -p 127.0.0.1::27017 `
            -e MONGO_INITDB_ROOT_USERNAME=cashlenx `
            -e MONGO_INITDB_ROOT_PASSWORD=cashlenx123 `
            -e MONGO_INITDB_DATABASE=$dbName $MongoImage | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "MongoDB container failed to start" }

        $mongoPort = ((docker port $container 27017/tcp) -split ':')[-1].Trim()
        $mongoUri = "mongodb://cashlenx:cashlenx123@localhost:27017/admin?authSource=admin"
        $databaseReady = $false
        for ($attempt = 0; $attempt -lt 60; $attempt++) {
            docker exec $container mongosh $mongoUri --quiet `
                --eval 'db.adminCommand({ ping: 1 }).ok' 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $databaseReady = $true; break }
            Start-Sleep -Seconds 1
        }
        if (-not $databaseReady) { throw "MongoDB authenticated readiness timed out" }

        $seedScript = "db = db.getSiblingDB('$dbName'); const now = new Date(); " +
            "const expires = new Date(Date.now() + 3600000); " +
            "db.operation_confirm_codes.insertMany([" +
            "{_id:ObjectId(),user_id:'',code:'$signupCode',verification_token:'',operation_type:'signup',payload:'$email',expires_time:expires,used_time:null,create_time:now,update_time:now,is_delete:false}," +
            "{_id:ObjectId(),user_id:'',code:'$resetCode',verification_token:'',operation_type:'password_reset',payload:'$email',expires_time:expires,used_time:null,create_time:now,update_time:now,is_delete:false}" +
            "]);"
        docker exec $container mongosh $mongoUri --quiet --eval $seedScript | Out-Null
    } else {
        docker run -d --name $container -p 127.0.0.1::3306 `
            -e MYSQL_ROOT_PASSWORD=cashlenx123 -e MYSQL_DATABASE=$dbName `
            -e MYSQL_USER=cashlenx -e MYSQL_PASSWORD=cashlenx123 $MySqlImage | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "MySQL container failed to start" }

        $mysqlPort = ((docker port $container 3306/tcp) -split ':')[-1].Trim()
        $databaseReady = $false
        for ($attempt = 0; $attempt -lt 90; $attempt++) {
            docker exec $container mysql -uroot -pcashlenx123 `
                -e 'SELECT 1' 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $databaseReady = $true; break }
            Start-Sleep -Seconds 1
        }
        if (-not $databaseReady) { throw "MySQL authenticated readiness timed out" }

        $schemaPath = Resolve-Path (Join-Path $serverRoot "docker\mysql\init-mysql.sql")
        docker cp $schemaPath "${container}:/tmp/init-mysql.sql" | Out-Null
        docker exec $container sh -c `
            'mysql -uroot -pcashlenx123 cashlenx < /tmp/init-mysql.sql' 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "MySQL schema initialization failed" }

        $seedScript = "INSERT INTO operation_confirm_codes " +
            "(id,user_id,token,verification_token,operation_type,payload,expires_at,used_at,create_user_id,create_time,update_user_id,update_time,is_delete) VALUES " +
            "('111111111111111111111111',NULL,'$signupCode',NULL,'signup','$email',DATE_ADD(NOW(), INTERVAL 1 HOUR),NULL,NULL,NOW(),NULL,NOW(),FALSE)," +
            "('222222222222222222222222',NULL,'$resetCode',NULL,'password_reset','$email',DATE_ADD(NOW(), INTERVAL 1 HOUR),NULL,NULL,NOW(),NULL,NOW(),FALSE);"
        docker exec $container mysql -uroot -pcashlenx123 $dbName `
            -e $seedScript 2>$null | Out-Null
    }
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
    $env:DB_TYPE = $Database
    $env:DB_NAME = $dbName
    if ($Database -eq "mongodb") {
        $env:MONGO_DB_URI = "mongodb://cashlenx:cashlenx123@localhost:$mongoPort/${dbName}?authSource=admin&retryWrites=false"
    } else {
        $env:MYSQL_DB_URI = "cashlenx:cashlenx123@tcp(localhost:$mysqlPort)"
    }

    $server = Start-Process -FilePath $serverExe `
        -ArgumentList @("open", "start", "-p", "$ServerPort") `
        -WorkingDirectory $serverRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

    $serverReady = $false
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        if (Test-Path $stdoutLog) {
            $serverOutput = Get-Content $stdoutLog -Raw
            if ($serverOutput -match "API server is running") {
                $serverReady = $true
                break
            }
        }
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
