@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

:: ======================================================
::  SCRIPT COMPLETO - CONFIGURACAO ESTACAO ALUNO
::  Etapa 1: Filtro de Wi-Fi (esconder redes, exceto uma)
::  Etapa 2: Restricoes de acesso (Painel/Rede) do aluno
::  Etapa 3: Limpeza do perfil aluno + bloqueio de sincronizacao
:: ======================================================

set "SSID_PERMITIDO=Tecnico.Neusa"
set "USER_ALUNO=aluno"
set "USER_PROFESSOR=professor"
set "USER_ADMIN=Administrador"

:: --- Checagem de administrador (feita uma unica vez) ---
net session >nul 2>&1
if %errorLevel% neq 0 (
    color cf
    echo [ERRO] Execute este script como ADMINISTRADOR!
    pause
    exit /b
)

cls
color 3f
title CONFIGURACAO COMPLETA - ESTACAO ALUNO
echo ======================================================
echo   CONFIGURACAO COMPLETA DA ESTACAO (ALUNO)
echo ======================================================
echo.
echo Este script vai executar, em sequencia:
echo  [1] Filtro de Wi-Fi (permitir somente "%SSID_PERMITIDO%")
echo  [2] Bloqueio do Painel de Controle e Config. de Rede
echo  [3] Limpeza do perfil do aluno + bloqueio de sincronizacao
echo.
echo O PC sera REINICIADO automaticamente ao final.
echo.
pause

:: ======================================================
:: ETAPA 1 - FILTRO DE REDE WI-FI
:: ======================================================
echo.
echo ======================================================
echo   ETAPA 1/3 - CONFIGURANDO FILTRO DE REDE WI-FI
echo ======================================================
echo [1] Limpando filtros antigos...
netsh wlan delete filter permission=denyall networktype=infrastructure >nul 2>&1
netsh wlan delete filter permission=allow ssid="%SSID_PERMITIDO%" networktype=infrastructure >nul 2>&1

echo [2] Permitindo APENAS a rede: %SSID_PERMITIDO%
netsh wlan add filter permission=allow ssid="%SSID_PERMITIDO%" networktype=infrastructure

echo [3] Bloqueando todas as outras redes vizinhas...
netsh wlan add filter permission=denyall networktype=infrastructure

echo.
echo Etapa 1 concluida! O notebook so enxergara a rede %SSID_PERMITIDO%.
echo.

:: ======================================================
:: ETAPA 2 - RESTRICOES DE ACESSO (USUARIO)
:: ======================================================
echo ======================================================
echo   ETAPA 2/3 - APLICANDO RESTRICOES DE ACESSO (ALUNO)
echo ======================================================
echo.
echo Bloqueando Painel de Controle e propriedades de Rede...
echo AVISO: O UWF sera desativado momentaneamente para salvar as mudancas.
echo.

echo [1/4] Desativando UWF para gravar politicas...
uwfmgr filter disable >nul 2>&1
net stop uwfvol /y >nul 2>&1

echo [2/4] Aplicando bloqueios no Perfil Padrao...
reg load "HKLM\TEMP_DEFAULT" "C:\Users\Default\NTUSER.DAT" >nul 2>&1
if %errorLevel% equ 0 (
    echo    - Bloqueando Painel de Controle...
    reg add "HKLM\TEMP_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoControlPanel /t REG_DWORD /d 1 /f >nul
    reg add "HKLM\TEMP_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoSettingsPage /t REG_DWORD /d 1 /f >nul

    echo    - Bloqueando Configuracoes de Rede...
    reg add "HKLM\TEMP_DEFAULT\Software\Policies\Microsoft\Windows\Network Connections" /v NC_LanProperties /t REG_DWORD /d 1 /f >nul
    reg add "HKLM\TEMP_DEFAULT\Software\Policies\Microsoft\Windows\Network Connections" /v NC_NoSetup /t REG_DWORD /d 1 /f >nul

    reg unload "HKLM\TEMP_DEFAULT" >nul 2>&1
    echo    [OK] Perfil Padrao vacinado.
) else (
    echo    [ERRO] Nao foi possivel carregar perfil padrao.
)

echo [3/4] Verificando perfil atual do aluno...
for /d %%d in ("C:\Users\%USER_ALUNO%*") do (
    if exist "%%d\NTUSER.DAT" (
        echo    - Encontrado perfil em: %%d
        echo    - Aplicando bloqueios...
        reg load "HKU\Temp_Aluno" "%%d\NTUSER.DAT" >nul 2>&1
        if !errorLevel! equ 0 (
            reg add "HKU\Temp_Aluno\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoControlPanel /t REG_DWORD /d 1 /f >nul
            reg add "HKU\Temp_Aluno\Software\Policies\Microsoft\Windows\Network Connections" /v NC_LanProperties /t REG_DWORD /d 1 /f >nul
            reg add "HKU\Temp_Aluno\Software\Policies\Microsoft\Windows\Network Connections" /v NC_NoSetup /t REG_DWORD /d 1 /f >nul
            reg unload "HKU\Temp_Aluno" >nul 2>&1
            echo    [OK] Perfil atual atualizado.
        )
    )
)

echo [4/4] Reativando UWF...
net start uwfvol >nul 2>&1
uwfmgr filter enable >nul 2>&1
uwfmgr volume protect c: >nul 2>&1

:: Limpeza de seguranca (Remover travas globais para liberar Admin/Prof)
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Network Connections" /v NC_LanProperties /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Network Connections" /v NC_NoSetup /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoControlPanel /f >nul 2>&1

echo.
echo Etapa 2 concluida! Restricoes de acesso aplicadas.
echo.

:: ======================================================
:: ETAPA 3 - LIMPEZA DE PERFIL E BLOQUEIO DE SINCRONIZACAO
:: ======================================================
echo ======================================================
echo   ETAPA 3/3 - LIMPANDO PERFIL E BLOQUEANDO SINCRONIZACAO
echo ======================================================
echo.

echo [1/4] Desativando servicos de Arquivos Offline...
sc stop CscService >nul 2>&1
sc config CscService start= disabled >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Csc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo    - Servico de sincronizacao desabilitado.

echo [2/4] Preparando UWF...
uwfmgr filter disable >nul 2>&1
net stop uwfvol /y >nul 2>&1

echo [3/4] Limpando perfil local do aluno...
for /f "tokens=2" %%u in ('query session ^| find /i "%USER_ALUNO%"') do (
    logoff %%u >nul 2>&1
)
timeout /t 2 /nobreak >nul

for /d %%d in ("C:\Users\%USER_ALUNO%*") do (
    echo    - Apagando pasta local: %%d
    icacls "%%d" /grant "%USER_ADMIN%:(OI)(CI)F" /T /C /Q >nul 2>&1
    rd /s /q "%%d" >nul 2>&1
)

echo [4/4] Reativando protecao local...
net start uwfvol >nul 2>&1
uwfmgr filter enable >nul 2>&1
uwfmgr volume protect c: >nul 2>&1

uwfmgr file remove-exclusion "C:\Users" >nul 2>&1
uwfmgr file remove-exclusion "C:\Users\%USER_ALUNO%" >nul 2>&1
uwfmgr file remove-exclusion "C:\Users\Public" >nul 2>&1

if exist "C:\Users\%USER_ADMIN%" uwfmgr file add-exclusion "C:\Users\%USER_ADMIN%" >nul 2>&1
if exist "C:\Users\%USER_PROFESSOR%" uwfmgr file add-exclusion "C:\Users\%USER_PROFESSOR%" >nul 2>&1

echo.
echo ======================================================
echo TODAS AS ETAPAS FORAM CONCLUIDAS.
echo ======================================================
echo  [1] Wi-Fi restrito a "%SSID_PERMITIDO%"
echo  [2] Restricoes de acesso aplicadas ao usuario aluno
echo  [3] Perfil do aluno limpo e sincronizacao desativada
echo.
echo SE OS ARQUIVOS CONTINUAREM VOLTANDO:
echo Isso significa que o TI da empresa configurou um
echo "Redirecionamento de Pasta" via Servidor (GPO).
echo Nenhum script local consegue impedir isso, pois o
echo Windows esta salvando direto no servidor, nao no C:.
echo Voce precisaria falar com o administrador da rede.
echo ======================================================
echo O PC sera reiniciado agora...
pause
shutdown /r /t 0 /f
