# ==============================================================================
# Script de Publicación Automática de Actualizaciones - Icaro Proagro
# ==============================================================================
# Este script:
# 1. Lee la versión de pubspec.yaml
# 2. Compila el APK Release
# 3. Lo publica en GitHub Releases (icaro-proagro-releases) - 100% Gratuito
# 4. Actualiza Firestore automáticamente para alertar a todos los celulares
# ==============================================================================

param(
    [string]$Notas = "Mejoras generales y optimizaciones de rendimiento."
)

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "   PUBLICADOR AUTOMATICO DE ICARO PROAGRO APK" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

# 1. Leer versión actual de pubspec.yaml
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "version:\s*([0-9\.]+)\+([0-9]+)") {
    $versionName = $Matches[1]
    $buildNumber = [int]$Matches[2]
} else {
    Write-Host "Error: No se pudo leer la versión en pubspec.yaml" -ForegroundColor Red
    exit 1
}

Write-Host "`n[1/4] Versión detectada: v$versionName+$buildNumber" -ForegroundColor Cyan

# 2. Compilar APK en modo Release
Write-Host "`n[2/4] Compilando APK Release (puede tardar unos minutos)..." -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "`nError durante la compilación del APK." -ForegroundColor Red
    exit 1
}

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (!(Test-Path $apkPath)) {
    Write-Host "`nNo se encontró el APK generado en $apkPath" -ForegroundColor Red
    exit 1
}

# 3. Publicar Release en GitHub
$tag = "v$versionName"
$repoReleases = "gatitomalvado27-tech/icaro-proagro-releases"

Write-Host "`n[3/4] Publicando $tag en GitHub Releases ($repoReleases)..." -ForegroundColor Cyan
gh release create $tag $apkPath --repo $repoReleases --title "Icaro Proagro $tag" --notes "$Notas" --clobber

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nError subiendo la Release a GitHub." -ForegroundColor Red
    exit 1
}

$downloadUrl = "https://github.com/$repoReleases/releases/download/$tag/app-release.apk"

# 4. Actualizar Firestore en la nube
Write-Host "`n[4/4] Notificando actualización a Firebase Firestore..." -ForegroundColor Cyan
try {
    $body = @{
        fields = @{
            version = @{ stringValue = $versionName }
            buildNumber = @{ integerValue = $buildNumber }
            apkUrl = @{ stringValue = $downloadUrl }
            novedades = @{ stringValue = $Notas }
            habilitada = @{ booleanValue = $true }
            obligatoria = @{ booleanValue = $false }
            fecha = @{ timestampValue = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
        }
    } | ConvertTo-Json -Depth 5

    Invoke-RestMethod -Uri "https://firestore.googleapis.com/v1/projects/icaroproagro-612d3/databases/(default)/documents/app_config/actualizacion" -Method PATCH -Body $body -ContentType "application/json; charset=utf-8" | Out-Null
    Write-Host "✅ Firestore actualizado con éxito. Todos los celulares recibirán el aviso." -ForegroundColor Green
} catch {
    Write-Host "Aviso: No se pudo actualizar Firestore automáticamente: $_" -ForegroundColor Yellow
}

# 5. Resumen
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   ¡ACTUALIZACION COMPLETADA EXITOSAMENTE!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Versión:     $versionName (Build $buildNumber)" -ForegroundColor Yellow
Write-Host "Enlace APK:  $downloadUrl" -ForegroundColor Yellow
Write-Host "Repositorio: https://github.com/$repoReleases" -ForegroundColor Yellow
Write-Host "==========================================================`n" -ForegroundColor Green
