@echo off
chcp | find "866" 1>nul 2>nul

if not errorlevel 1 (
set LNGRUS=1
) else (
set LNGRUS=0
)

@set LUACLN=.\bin\lua5.1.bin .\utils\luaClean.lua
@set LUAFLT=findstr /R "^"

if %LNGRUS% equ 0 goto english

echo Чистка тегов в PGN-файле
if "%~1"==""       goto errargs-rus
if not exist "%~1" goto errargs-rus

set PSSRC="%~f1"
set PSDST="%~dp1result.pgn"

echo ------------------------------------------------------------
echo.
echo Исходный файл: %PSSRC%
echo Итоговый файл: %PSDST%
echo.
echo Обработка . . .

cd /d "%~dp0"
%LUACLN% < %PSSRC% | %LUAFLT% > %PSDST%
if errorlevel 1 goto errexec-rus

echo OK!
echo.
goto done

:errargs-rus
echo Неверные аргументы!
echo ------------------------------------------------------------
echo.
echo Использование: %~nx0 games.pgn
echo где games.pgn - существующий исходный файл с партиями
echo.
echo Итоговый файл result.pgn будет сохранен рядом с games.pgn
echo в той же папке.
echo.
echo Если в имени файла есть пробелы, заключите его в кавычки.
echo Например: %~nx0 "games 1.pgn"
echo.
goto done

:errexec-rus
echo Ошибка!
echo.
goto done

:english

echo PGN: Tags cleaning
if "%~1"==""       goto errargs-eng
if not exist "%~1" goto errargs-eng

set PSSRC="%~f1"
set PSDST="%~dp1result.pgn"

echo ------------------------------------------------------------
echo.
echo Original file: %PSSRC%
echo Final file:    %PSDST%
echo.
echo Processing . . .

cd /d "%~dp0"
%LUACLN% < %PSSRC% | %LUAFLT% > %PSDST%
if errorlevel 1 goto errexec-eng

echo OK!
echo.
goto done

:errargs-eng
echo Wrong arguments!
echo ------------------------------------------------------------
echo.
echo Usage: %~nx0 games.pgn
echo where games.pgn is the existing source file with games
echo.
echo The final file, result.pgn, will be saved next to games.pgn
echo in the same folder.
echo.
echo If the file name contains spaces, enclose it in quotation
echo marks. For example: %~nx0 "games 1.pgn"
echo.
goto done

:errexec-eng
echo Error!
echo.

:done
echo ------------------------------------------------------------
pause
