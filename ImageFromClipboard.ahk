class ClipboardUtil {
    static TryGetPngFromClipboard() {
        ; PowerShell command to read clipboard image as PNG and convert to Base64
        psCmd := "
(
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$img = [System.Windows.Forms.Clipboard]::GetImage()
if ($null -eq $img) { exit 1 }

$ms = New-Object System.IO.MemoryStream
$img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)

$b64 = [Convert]::ToBase64String($ms.ToArray())
Write-Output $b64
)"

        ; Run PowerShell in STA mode
        output := ClipboardUtil.RunPowerShellSTA(psCmd) ; A_ScriptDir "\test.ps1")
        if !output
            return false
        return "data:image/png;base64," . output
    }

    ; Runs PowerShell in STA mode and returns StdOut (trimmed)
    static RunPowerShellSTA(script) {
        shell := ComObject("WScript.Shell")
        exec := shell.Exec("powershell -NoProfile -Command -")
        exec.StdIn.Write(script)
        exec.StdIn.Close()
        result := ""
        while !exec.StdOut.AtEndOfStream {
            result .= exec.StdOut.ReadLine() . "`n"
        }

        return RTrim(result, "`n")
    }
}
