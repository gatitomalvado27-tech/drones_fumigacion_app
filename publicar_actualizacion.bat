@echo off
title Publicador Automatico de Actualizaciones - Icaro Proagro
echo ========================================================
echo   Iniciando Publicador Automatico de Actualizaciones
echo ========================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\publicar_actualizacion.ps1"
echo.
pause
