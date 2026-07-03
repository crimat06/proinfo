@echo off
setlocal enabledelayedexpansion

:: ======================================================
::  DESATIVAR SINCRONIZACAO DE REDE E RESET LOCAL
::  Objetivo: Impedir que arquivos voltem do servidor
:: ======================================================

set "USER_ALUNO=aluno"
set "USER_PROFESSOR=professor"
set "USER_ADMIN=Administrador"

net session >nul 2>&1
if %errorLevel% neq 0 (
    color cf
    echo [ERRO] Execute como ADMINISTRADOR!
    pause
    exit /b
)

cls
color 3f
title BLOQUEIO DE SINCRONIZACAO
echo ======================================================
echo   DESATIVANDO SINCRONIZACAO DE REDE / SERVIDOR
echo ======================================================
echo.
echo Se os arquivos voltam mesmo sem OneDrive, eles estao vindo
echo do servidor da rede. Vamos tentar bloquear isso localmente.
echo.

:: 1. DESATIVAR SERVICOS DE SINCRONIZACAO (Offline Files)
echo [1/4] Desativando servicos de Arquivos Offline...
sc stop CscService >nul 2>&1
sc config CscService start= disabled >nul 2>&1

:: Bloqueia via Registro
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Csc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo    - Servico de sincronizacao desabilitado.

:: 2. PREPARAR UWF
echo [2/4] Preparando UWF...
uwfmgr filter disable >nul 2>&1
net stop uwfvol /y >nul 2>&1

:: 3. EXPULSAR E DELETAR PERFIL LOCAL
echo [3/4] Limpando perfil local do aluno...
for /f "tokens=2" %%u in ('query session ^| find /i "%USER_ALUNO%"') do (
    logoff %%u >nul 2>&1
)
timeout /t 2 /nobreak >nul

:: Deleta a pasta fisica
for /d %%d in ("C:\Users\%USER_ALUNO%*") do (
    echo    - Apagando pasta local: %%d
    icacls "%%d" /grant "%USER_ADMIN%:(OI)(CI)F" /T /C /Q >nul 2>&1
    rd /s /q "%%d" >nul 2>&1
)

:: 4. REATIVAR E PROTEGER
echo [4/4] Reativando protecao local...
net start uwfvol >nul 2>&1
uwfmgr filter enable >nul 2>&1
uwfmgr volume protect c: >nul 2>&1

:: Limpar excessoes genericas
uwfmgr file remove-exclusion "C:\Users" >nul 2>&1
uwfmgr file remove-exclusion "C:\Users\%USER_ALUNO%" >nul 2>&1
uwfmgr file remove-exclusion "C:\Users\Public" >nul 2>&1

:: Liberar Admin/Prof
if exist "C:\Users\%USER_ADMIN%" uwfmgr file add-exclusion "C:\Users\%USER_ADMIN%" >nul 2>&1
if exist "C:\Users\%USER_PROFESSOR%" uwfmgr file add-exclusion "C:\Users\%USER_PROFESSOR%" >nul 2>&1

echo.
echo ======================================================
echo CONCLUIDO.
echo ======================================================
echo Foi desativada a sincronizacao de arquivos offline.
echo Reinicie o PC e teste.
echo.
echo SE OS ARQUIVOS CONTINUAREM VOLTANDO:
echo Isso significa que o TI da empresa configurou um
echo "Redirecionamento de Pasta" via Servidor (GPO).
echo Nenhum script local consegue impedir isso, pois o
echo Windows esta salvando direto no servidor, nao no C:.
echo Voce precisaria falar com o administrador da rede.
echo ======================================================
pause
shutdown /r /t 0 /f
