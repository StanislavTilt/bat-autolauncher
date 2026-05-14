Option Explicit

Dim shell, here, target

Set shell = CreateObject("WScript.Shell")
here = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
target = """" & here & "launcher.bat"""

shell.Run target, 0, False
