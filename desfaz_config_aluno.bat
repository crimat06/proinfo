@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

:: ======================================================
::  SCRIPT ANTIDOTO - DESFAZ TODAS AS CONFIGURACOES
::  Reverte:
::   [1] Restricoes de acesso (Painel/Rede) do aluno
::   [2] Bloqueio de sincronizacao (Offline Files / CscService)
::   [3] Filtro de Wi-Fi (volta a enxergar todas as redes)
:: ======================================================

set "USER_ALUNO=aluno"

net session >nul 2>&1
if %errorLevel% neq 0 (
    color cf
    echo [ERRO] Execute este script como ADMINISTRADOR!
    pause
    exit /b
)

cls
color 2f
title ANTIDOTO - REVERTER CONFIGURACOES
echo ======================================================
echo   REVERTENDO TODAS AS CONFIGURACOES APLICADAS
echo ======================================================
echo.
echo Este script vai desfazer, em sequencia:
echo  [1] Restricoes de Painel de Controle / Config. de Rede
echo  [2] Bloqueio de sincronizacao (Offline Files)
echo  [3] Filtro de Wi-Fi (voltar a enxergar todas as redes)
echo.
echo O PC sera REINICIADO automaticamente ao final.
echo.
pause

:: ======================================================
:: ETAPA 1 - REMOVER RESTRICOES DE ACESSO (USUARIO)
:: ======================================================
echo.
echo ======================================================
echo   ETAPA 1/3 - REMOVENDO RESTRICOES DE ACESSO
echo ======================================================

echo [1/4] Desativando UWF para gravar reversao...
uwfmgr filter disable >nul 2>&1
net stop uwfvol /y >nul 2>&1

echo [2/4] Removendo bloqueios do Perfil Padrao...
reg load "HKLM\TEMP_DEFAULT" "C:\Users\Default\NTUSER.DAT" >nul 2>&1
if %errorLevel% equ 0 (
    reg delete "HKLM\TEMP_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoControlPanel /f >nul 2>&1
    reg delete "HKLM\TEMP_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoSettingsPage /f >nul 2>&1
    reg delete "HKLM\TEMP_DEFAULT\Software\Policies\Microsoft\Windows\Network Connections" /v NC_LanProperties /f >nul 2>&1
    reg delete "HKLM\TEMP_DEFAULT\Software\Policies\Microsoft\Windows\Network Connections" /v NC_NoSetup /f >nul 2>&1
    reg unload "HKLM\TEMP_DEFAULT" >nul 2>&1
    echo    [OK] Perfil Padrao revertido.
) else (
    echo    [ERRO] Nao foi possivel carregar perfil padrao.
)

echo [3/4] Verificando perfil atual do aluno...
for /d %%d in ("C:\Users\%USER_ALUNO%*") do (
    if exist "%%d\NTUSER.DAT" (
        echo    - Encontrado perfil em: %%d
        reg load "HKU\Temp_Aluno" "%%d\NTUSER.DAT" >nul 2>&1
        if !errorLevel! equ 0 (
            reg delete "HKU\Temp_Aluno\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoControlPanel /f >nul 2>&1
            reg delete "HKU\Temp_Aluno\Software\Policies\Microsoft\Windows\Network Connections" /v NC_LanProperties /f >nul 2>&1
            reg delete "HKU\Temp_Aluno\Software\Policies\Microsoft\Windows\Network Connections" /v NC_NoSetup /f >nul 2>&1
            reg unload "HKU\Temp_Aluno" >nul 2>&1
            echo    [OK] Perfil atual revertido.
        )
    ) else (
        echo    - Nenhum perfil de aluno encontrado (normal, se a pasta foi apagada).
    )
)

echo [4/4] Reativando UWF...
net start uwfvol >nul 2>&1
uwfmgr filter enable >nul 2>&1
uwfmgr volume protect c: >nul 2>&1

echo.
echo Etapa 1 concluida! Restricoes removidas.
echo.

:: ======================================================
:: ETAPA 2 - REATIVAR SINCRONIZACAO (OFFLINE FILES)
:: ======================================================
echo ======================================================
echo   ETAPA 2/3 - REATIVANDO SINCRONIZACAO
echo ======================================================

echo [1/2] Reativando servico de Arquivos Offline...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Csc" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
sc config CscService start= demand >nul 2>&1
sc start CscService >nul 2>&1
echo    - Servico de sincronizacao reativado (inicio manual).

echo [2/2] Removendo exclusoes especificas do UWF (Admin/Professor)...
uwfmgr filter disable >nul 2>&1
net stop uwfvol /y >nul 2>&1
uwfmgr file remove-exclusion "C:\Users\Administrador" >nul 2>&1
uwfmgr file remove-exclusion "C:\Users\professor" >nul 2>&1
net start uwfvol >nul 2>&1
uwfmgr filter enable >nul 2>&1
uwfmgr volume protect c: >nul 2>&1

echo.
echo Etapa 2 concluida! Sincronizacao reativada.
echo.

:: ======================================================
:: ETAPA 3 - REMOVER FILTRO DE WI-FI
:: ======================================================
echo ======================================================
echo   ETAPA 3/3 - REMOVENDO FILTRO DE WI-FI
echo ======================================================

echo [1/1] Removendo todos os filtros de rede aplicados...
netsh wlan delete filter permission=denyall networktype=infrastructure >nul 2>&1
netsh wlan delete filter permission=allow ssid="Tecnico.Neusa" networktype=infrastructure >nul 2>&1

echo.
echo Etapa 3 concluida! O notebook voltara a enxergar todas as redes Wi-Fi.
echo.

echo ======================================================
echo TODAS AS REVERSOES FORAM CONCLUIDAS.
echo ======================================================
echo  [1] Restricoes de Painel/Rede removidas
echo  [2] Sincronizacao (Offline Files) reativada
echo  [3] Filtro de Wi-Fi removido (todas as redes visiveis)
echo.
echo OBSERVACAO: se a pasta do aluno ja tinha sido apagada
echo pelo script anterior, os arquivos locais NAO podem ser
echo recuperados por este antidoto. Um novo perfil sera criado
echo normalmente no proximo login do usuario aluno.
echo ======================================================
echo O PC sera reiniciado agora...
pause
shutdown /r /t 0 /f
