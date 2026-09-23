param(
    [string]$Notas = ""
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  PUBLICADOR AUTOMATICO DE ACTUALIZACIONES - ICARO PROAGRO " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

# 1. Leer version actual en pubspec.yaml
$pubspecPath = ".\pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
    $pubspecPath = "$PSScriptRoot\..\pubspec.yaml"
}

$content = Get-Content $pubspecPath -Raw
if ($content -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)') {
    $currentVersion = $Matches[1]
    $currentBuild = [int]$Matches[2]
} else {
    Write-Error "No se pudo leer la versión en pubspec.yaml"
    exit 1
}

$newBuild = $currentBuild + 1
$vParts = $currentVersion.Split('.')
$newVersion = "$($vParts[0]).$($vParts[1]).$([int]$vParts[2] + 1)"
$newVersionTag = "v$newVersion"

Write-Host "`n[1/5] Version actual detectada: $currentVersion+$currentBuild" -ForegroundColor Cyan
Write-Host "      Nueva version a publicar: $newVersion+$newBuild" -ForegroundColor Yellow

if ([string]::IsNullOrWhiteSpace($Notas)) {
    $NotasInput = Read-Host "Ingresa las notas de la version (o presiona ENTER para texto por defecto)"
    if (-not [string]::IsNullOrWhiteSpace($NotasInput)) {
        $Notas = $NotasInput
    } else {
        $Notas = "• Nuevo módulo de Bodega de insumos y repuestos con fotos`n• Filtros contables avanzados y turnos de jornada`n• Cierres y balances mensuales archivables`n• Agenda con ordenamiento inteligente y cuenta regresiva para deudores`n• Mejoras de estabilidad y diseño de pilotos"
    }
}

# Actualizar pubspec.yaml
$updatedContent = $content -replace "version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+", "version: $newVersion+$newBuild"
Set-Content $pubspecPath $updatedContent -NoNewline
Write-Host "OK -> pubspec.yaml actualizado a $newVersion+$newBuild" -ForegroundColor Green

# 2. Compilar APK Release
Write-Host "`n[2/5] Compilando APK Release para Android..." -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Fallo en la compilación de Flutter"
    exit 1
}

$apkPath = ".\build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Error "No se encontro el archivo APK generado en $apkPath"
    exit 1
}

# 3. Subir a GitHub Releases con gh
Write-Host "`n[3/5] Publicando Release en GitHub..." -ForegroundColor Cyan

# Verificar estado de gh
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "No has iniciado sesion en GitHub CLI (gh)." -ForegroundColor Yellow
    Write-Host "Iniciando proceso de autenticacion..." -ForegroundColor Cyan
    gh auth login -w -p https
}
gh auth setup-git

# Obtener o configurar repositorio remoto
$remoteUrl = git config --get remote.origin.url
if (-not $remoteUrl) {
    Write-Host "Creando repositorio en GitHub para gatitomalvado27-tech..." -ForegroundColor Yellow
    git branch -M main
    git add .
    git commit -m "Inicializar proyecto Icaro Proagro"
    gh repo create drones_fumigacion_app --public --source=. --remote=origin --push
    $remoteUrl = git config --get remote.origin.url
} else {
    git add .
    git commit -m "Release $newVersionTag (Build $newBuild)"
    git push origin HEAD
}

# Crear el release en GitHub con el APK adjunto
gh release create $newVersionTag $apkPath --title "Icaro Proagro $newVersionTag" --notes "$Notas"

# Extraer el nombre del repositorio para la URL directa
if ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
    $owner = $Matches[1]
    $repo = $Matches[2]
} else {
    $owner = "gatitomalvado27-tech"
    $repo = "drones_fumigacion_app"
}

$downloadUrl = "https://github.com/$owner/$repo/releases/download/$newVersionTag/app-release.apk"
Write-Host "OK -> APK publicado en GitHub Releases:" -ForegroundColor Green
Write-Host "   $downloadUrl" -ForegroundColor White

# 4. Actualizar Firestore en la nube
Write-Host "`n[4/5] Actualizando Firestore en tiempo real..." -ForegroundColor Cyan
$firestoreApiKey = "AIzaSyCXhC02lkkYwooAxYM0Tz3jL8Jbp3mOwnI"
$firestoreUrl = "https://firestore.googleapis.com/v1/projects/icaroproagro-612d3/databases/(default)/documents/app_config/actualizacion?key=$firestoreApiKey"

$body = @{
    fields = @{
        version = @{ stringValue = $newVersion }
        buildNumber = @{ integerValue = $newBuild }
        apkUrl = @{ stringValue = $downloadUrl }
        novedades = @{ stringValue = $Notas }
        obligatoria = @{ booleanValue = $false }
        habilitada = @{ booleanValue = $true }
        fecha = @{ timestampValue = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
    }
} | ConvertTo-Json -Depth 5

$response = Invoke-RestMethod -Uri $firestoreUrl -Method Patch -Body $body -ContentType "application/json"
Write-Host "OK -> Firestore actualizado con la version $newVersion ($newBuild)" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " ¡LISTO! LA ACTUALIZACION YA ESTA EN VIVO PARA TODOS! " -ForegroundColor Green
Write-Host " En cuanto los pilotos abran la app, veran el aviso para actualizar." -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
