@echo off
setlocal enabledelayedexpansion

echo ========================================
echo    CONFIGURACAO DO FORK - AI Chat
echo ========================================
echo.

echo [1/4] Verificando configuração atual do Git...
git remote -v
echo.

echo [2/4] Configurando fork como origin...
echo Digite seu nome de usuário do GitHub:
set /p GITHUB_USER=

if "%GITHUB_USER%"=="" (
    echo ERRO: Nome de usuário não pode estar vazio!
    pause
    exit /b 1
)

echo Configurando origin para: https://github.com/%GITHUB_USER%/plugin_openkore_aiChat.git
git remote set-url origin https://github.com/%GITHUB_USER%/plugin_openkore_aiChat.git

echo.
echo [3/4] Verificando nova configuração...
git remote -v

echo.
echo [4/4] Tentando fazer push para o fork...
git push origin main

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo    SUCESSO! Push realizado com sucesso!
    echo ========================================
    echo.
    echo Próximos passos:
    echo 1. Acesse: https://github.com/%GITHUB_USER%/plugin_openkore_aiChat
    echo 2. Clique em "Compare ^& pull request"
    echo 3. Descreva as melhorias implementadas
    echo 4. Crie o Pull Request
    echo.
) else (
    echo.
    echo ========================================
    echo    ATENCAO: Push falhou!
    echo ========================================
    echo.
    echo Possíveis causas:
    echo - Fork ainda não foi criado no GitHub
    echo - Nome de usuário incorreto
    echo - Problemas de autenticação
    echo.
    echo Verifique se o fork existe em:
    echo https://github.com/%GITHUB_USER%/plugin_openkore_aiChat
    echo.
)

echo Pressione qualquer tecla para continuar...
pause >nul
