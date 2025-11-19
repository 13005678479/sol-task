@echo off
echo Foundry Installation Helper
echo ========================
echo.
echo Due to network restrictions, please install Foundry manually:
echo.
echo 1. OPEN THIS LINK IN YOUR BROWSER:
echo    https://github.com/foundry-rs/foundry/releases
echo.
echo 2. Download these files:
echo    - forge-windows-x64.exe (rename to forge.exe)
echo    - cast-windows-x64.exe (rename to cast.exe)  
echo    - anvil-windows-x64.exe (rename to anvil.exe)
echo.
echo 3. CREATE FOLDER: C:\foundry
echo 4. COPY downloaded files to C:\foundry
echo 5. ADD TO PATH: C:\foundry
echo.
echo Adding to PATH instructions:
echo - Press Win+R, type "sysdm.cpl"
echo - Go to Advanced > Environment Variables
echo - Find "Path" in System variables > Edit > New
echo - Add: C:\foundry
echo - Click OK on all windows
echo.
echo 6. RESTART PowerShell and test:
echo    forge --version
echo.
pause