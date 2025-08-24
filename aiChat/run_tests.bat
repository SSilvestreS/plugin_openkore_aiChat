@echo off
setlocal enabledelayedexpansion

echo ========================================
echo    AI Chat Plugin - Test Runner
echo ========================================
echo.

:: Change to script directory
cd /d "%~dp0"

:: Check if Perl is available
echo [1/4] Checking Perl installation...
perl --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Perl is not installed or not in PATH
    echo Please install Perl from https://strawberryperl.com/ (Windows) or use your system package manager
    echo.
    pause
    exit /b 1
)
echo ✓ Perl found: 
perl --version

:: Check if Test::More is available
echo.
echo [2/4] Checking Perl test modules...
perl -e "use Test::More; print 'Test::More available\n'" >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing required Perl modules...
    cpan Test::More Test::MockTime
    if %errorlevel% neq 0 (
        echo ERROR: Failed to install Test::More
        echo Please install manually: cpan Test::More Test::MockTime
        pause
        exit /b 1
    )
) else (
    echo ✓ Test::More available
)

:: Check if Test::MockTime is available
perl -e "use Test::MockTime; print 'Test::MockTime available\n'" >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Test::MockTime...
    cpan Test::MockTime
    if %errorlevel% neq 0 (
        echo ERROR: Failed to install Test::MockTime
        pause
        exit /b 1
    )
) else (
    echo ✓ Test::MockTime available
)

:: Create test directory if it doesn't exist
echo.
echo [3/4] Setting up test environment...
if not exist "t" (
    mkdir t
    echo ✓ Created test directory
) else (
    echo ✓ Test directory exists
)

:: Check if test files exist
if not exist "t\test_cache.t" (
    echo ERROR: Test files not found
    echo Please make sure all test files are present in the t/ directory
    pause
    exit /b 1
)

echo ✓ Test files found

:: Run tests
echo.
echo [4/4] Running tests...
echo.

:: Test Cache module
echo ========================================
echo Testing Cache Module
echo ========================================
perl t/test_cache.t
if %errorlevel% neq 0 (
    echo.
    echo WARNING: Cache tests failed
    set /a failed_tests+=1
) else (
    echo.
    echo ✓ Cache tests passed
)

:: Test FallbackManager module
echo.
echo ========================================
echo Testing FallbackManager Module
echo ========================================
perl t/test_fallback.t
if %errorlevel% neq 0 (
    echo.
    echo WARNING: FallbackManager tests failed
    set /a failed_tests+=1
) else (
    echo.
    echo ✓ FallbackManager tests passed
)

:: Test ContextManager module
echo.
echo ========================================
echo Testing ContextManager Module
echo ========================================
perl t/test_context.t
if %errorlevel% neq 0 (
    echo.
    echo WARNING: ContextManager tests failed
    set /a failed_tests+=1
) else (
    echo.
    echo ✓ ContextManager tests passed
)

:: Summary
echo.
echo ========================================
echo Test Summary
echo ========================================
if defined failed_tests (
    echo.
    echo WARNING: $failed_tests test suite(s) failed
    echo Please check the output above for details
    echo.
    echo Common issues:
    echo - Missing Perl modules (install with cpan)
    echo - Syntax errors in test files
    echo - Missing dependencies
) else (
    echo.
    echo ✓ All test suites passed successfully!
    echo.
    echo The new AI Chat modules are working correctly
)

echo.
echo ========================================
echo Test run completed
echo ========================================
echo.
pause
