cd "C:\Games\Steam\steamapps\common\Sven Co-op\svencoop\addons\metamod\dlls"

if exist ApiGenerator_old.dll (
    del ApiGenerator_old.dll
)
if exist ApiGenerator.dll (
    rename ApiGenerator.dll ApiGenerator_old.dll 
)

exit /b 0