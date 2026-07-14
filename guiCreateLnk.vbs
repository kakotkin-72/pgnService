rem Создание ярлыка для Рабочего Стола
rem Creating a Shortcut

Set fso = CreateObject("Scripting.FileSystemObject")
Set shl = CreateObject("WScript.Shell")

dir = fso.GetParentFolderName(WScript.ScriptFullName)
arg = """" & fso.BuildPath(dir, "guiStarter.hta") & """"
ico = fso.BuildPath(dir, "pgnService.ico") & ",0"

Set lnk = shl.CreateShortcut(fso.BuildPath(dir, "pgnService.lnk"))

lnk.TargetPath       = "mshta.exe"
lnk.WorkingDirectory = dir
lnk.Arguments        = arg
lnk.IconLocation     = ico

lnk.Save
