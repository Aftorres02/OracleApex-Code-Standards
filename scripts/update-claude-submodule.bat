@echo off
:: --------------------------------------------------------------------------
:: update-claude-submodule.bat
::
:: Windows version of update-claude-submodule.sh: moves a consumer
:: project's submodule (default: .claude, this standards package) to the
:: latest commit of its tracked remote branch, checks that every path the
:: project references inside it still exists, and prints what is left to
:: commit. It never commits or pushes.
::
:: Project-independent: the parent repo is resolved from this file's own
:: location (normally .claude\scripts\, where the superproject is used).
::
:: Usage (double-click, or from anywhere):
::   .claude\scripts\update-claude-submodule.bat            (updates .claude)
::   .claude\scripts\update-claude-submodule.bat <path>     (another submodule)
:: --------------------------------------------------------------------------

:: This file lives in the folder that `git submodule update` rewrites, and
:: cmd.exe reads a batch file from disk line by line while it runs — a newer
:: version landing mid-run would execute half-old, half-new lines. So the
:: original only copies itself to %TEMP% and hands control to that copy
:: (no "call": control never comes back here).
if "%~1"=="--from-temp" goto :run
set "UCS_TEMP_COPY=%TEMP%\update-claude-submodule.bat"
copy /y "%~f0" "%UCS_TEMP_COPY%" >nul || (
  echo ERROR: could not copy this script to %TEMP%.
  pause
  exit /b 1
)
"%UCS_TEMP_COPY%" --from-temp "%~dp0." %1

:run
setlocal EnableDelayedExpansion
set "SCRIPT_DIR=%~2"
set "SUBMODULE=%~3"
if "%SUBMODULE%"=="" set "SUBMODULE=.claude"

:: --------------------------------------------------------------------------
:: Resolve the parent repo
:: --------------------------------------------------------------------------
set "REPO="
for /f "delims=" %%i in ('git -C "%SCRIPT_DIR%" rev-parse --show-superproject-working-tree 2^>nul') do set "REPO=%%i"
if not defined REPO (
  for /f "delims=" %%i in ('git -C "%SCRIPT_DIR%" rev-parse --show-toplevel 2^>nul') do set "REPO=%%i"
)
if not defined REPO (
  echo ERROR: %SCRIPT_DIR% is not inside a git repository.
  goto :fail
)

echo Repo:      %REPO%
echo Submodule: %SUBMODULE%
echo.

:: --------------------------------------------------------------------------
:: Refuse to run over local edits inside the submodule
:: --------------------------------------------------------------------------
set "OLD="
if exist "%REPO%\%SUBMODULE%\.git" (
  set "DIRTY="
  for /f "delims=" %%i in ('git -C "%REPO%/%SUBMODULE%" status --porcelain --untracked-files^=no') do set "DIRTY=1"
  if defined DIRTY (
    echo ERROR: %SUBMODULE% has uncommitted changes - commit, push or discard them first:
    git -C "%REPO%/%SUBMODULE%" status --short --untracked-files=no
    goto :fail
  )
  for /f "delims=" %%i in ('git -C "%REPO%/%SUBMODULE%" rev-parse HEAD') do set "OLD=%%i"
)

:: --------------------------------------------------------------------------
:: Update to the latest remote commit
:: --------------------------------------------------------------------------
echo Updating %SUBMODULE% to the latest remote commit ...
git -C "%REPO%" submodule update --init --remote -- "%SUBMODULE%"
if errorlevel 1 (
  echo.
  echo ERROR: submodule update failed.
  goto :fail
)

set "NEW="
for /f "delims=" %%i in ('git -C "%REPO%/%SUBMODULE%" rev-parse HEAD') do set "NEW=%%i"
echo.

if "%OLD%"=="%NEW%" (
  echo Already up to date at:
  git -C "%REPO%/%SUBMODULE%" log --oneline -1
  goto :done
)

echo Now at:
git -C "%REPO%/%SUBMODULE%" log --oneline -1
if defined OLD (
  echo.
  echo New commits:
  git -C "%REPO%/%SUBMODULE%" log --oneline --no-merges %OLD%..%NEW%
  echo.
  echo Files added ^(A^), modified ^(M^), deleted ^(D^) or renamed ^(R^):
  git -C "%REPO%/%SUBMODULE%" diff --name-status %OLD% %NEW%
)
echo.

:: --------------------------------------------------------------------------
:: Check that every path the project references inside the submodule still
:: exists. Windows ignores a trailing "." in a path, so a reference at the
:: end of a sentence ("see .claude/rules/x.md.") still resolves.
:: --------------------------------------------------------------------------
set "PATH_REGEX=%SUBMODULE:.=\.%/[A-Za-z0-9_./-]+"
set "MISSING="
set "LAST="
for /f "delims=" %%p in ('git -C "%REPO%" grep -ohE "%PATH_REGEX%" -- ":(exclude)%SUBMODULE%" 2^>nul ^| sort') do (
  if not "%%p"=="!LAST!" (
    set "LAST=%%p"
    set "REF=%%p"
    if not exist "%REPO%\!REF:/=\!" (
      echo MISSING: %%p is referenced in this project but no longer exists.
      set "MISSING=1"
    )
  )
)
if defined MISSING (
  echo          Fix those references before committing the new pointer.
) else (
  echo Every %SUBMODULE%/... path referenced in this project still exists.
)
echo.

:: --------------------------------------------------------------------------
:: What is left to do in the parent repo
:: --------------------------------------------------------------------------
echo Parent repo status for %SUBMODULE% (M = new pointer not committed yet):
git -C "%REPO%" status --short -- "%SUBMODULE%"
echo.
echo To keep it, on a branch: git add %SUBMODULE% ^&^& git commit
echo To undo it:              git submodule update -- %SUBMODULE%

:done
pause
endlocal
exit /b 0

:fail
pause
endlocal
exit /b 1
