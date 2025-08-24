@echo off
setlocal enabledelayedexpansion

echo ========================================
echo    AI Chat Plugin - Installation Script
echo ========================================
echo.

:: Change to script directory
cd /d "%~dp0"

echo [1/5] Checking system requirements...

:: Check Node.js
echo Checking Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed
    echo.
    echo Please install Node.js from https://nodejs.org/
    echo Recommended version: 16.x or higher
    echo.
    echo After installing Node.js, run this script again
    pause
    exit /b 1
)
echo ✓ Node.js found: 
node --version

:: Check npm
echo Checking npm...
npm --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: npm is not available
    echo Please reinstall Node.js
    pause
    exit /b 1
)
echo ✓ npm found: 
npm --version

echo.
echo [2/5] Installing Node.js dependencies...
if exist "package.json" (
    echo Installing packages from package.json...
    npm install
    if %errorlevel% neq 0 (
        echo ERROR: Failed to install dependencies
        echo Please check your internet connection and try again
        pause
        exit /b 1
    )
    echo ✓ Dependencies installed successfully
) else (
    echo ERROR: package.json not found
    pause
    exit /b 1
)

echo.
echo [3/5] Setting up configuration...
if not exist ".env" (
    if exist "env.example" (
        echo Creating .env file from template...
        copy "env.example" ".env" >nul
        echo ✓ .env file created
        echo.
        echo IMPORTANT: You need to edit the .env file with your API keys
        echo.
        echo Available AI providers:
        echo - DeepSeek: Get API key from https://platform.deepseek.com/
        echo - OpenAI: Get API key from https://platform.openai.com/
        echo.
        echo Edit .env file and add at least one API key:
        echo DEEPSEEK_API_KEY=your_key_here
        echo OPENAI_API_KEY=your_key_here
        echo.
        echo After editing .env, run start_openkore_e_proxy.bat
        echo.
        pause
    ) else (
        echo WARNING: env.example not found
    )
) else (
    echo ✓ .env file already exists
)

echo.
echo [4/5] Creating startup scripts...
if not exist "start_proxy_only.bat" (
    echo Creating start_proxy_only.bat...
    (
        echo @echo off
        echo echo Starting AI Chat Proxy...
        echo cd /d "%%~dp0"
        echo node api_proxy.js
        echo pause
    ) > "start_proxy_only.bat"
    echo ✓ start_proxy_only.bat created
)

echo.
echo [5/5] Installation complete!
echo.
echo Next steps:
echo 1. Edit .env file with your API keys
echo 2. Run start_openkore_e_proxy.bat to start everything
echo 3. Or run start_proxy_only.bat to start just the proxy
echo.
echo For help, check README.md
echo.
echo ========================================
pause
