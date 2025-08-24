@echo off
setlocal enabledelayedexpansion

echo ========================================
echo    AI Chat Proxy - Standalone Launcher
echo ========================================
echo.

:: Change to script directory
cd /d "%~dp0"

:: Check if Node.js is installed
echo [1/3] Checking Node.js installation...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    echo.
    pause
    exit /b 1
)
echo ✓ Node.js found: 
node --version

:: Check if dependencies are installed
echo.
echo [2/3] Checking dependencies...
if not exist "node_modules" (
    echo Installing Node.js dependencies...
    npm install
    if %errorlevel% neq 0 (
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
) else (
    echo ✓ Dependencies already installed
)

:: Check if .env file exists
echo.
echo [3/3] Checking configuration...
if not exist ".env" (
    echo WARNING: .env file not found
    echo Please copy env.example to .env and configure your API keys
    echo.
    if exist "env.example" (
        echo Creating .env from template...
        copy "env.example" ".env" >nul
        echo ✓ .env file created from template
        echo Please edit .env file with your API keys before continuing
        echo.
        pause
    )
) else (
    echo ✓ Configuration file found
)

:: Start the AI Chat proxy
echo.
echo Starting AI Chat Proxy...
echo Proxy will run on http://localhost:3000
echo.
echo Available endpoints:
echo - POST /proxy - AI chat requests
echo - GET  /status - Server status
echo.
echo Press Ctrl+C to stop the proxy
echo ========================================
echo.

node api_proxy.js
