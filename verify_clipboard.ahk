#Include Lib\CGDip.ahk
#Include ImageFromClipboard.ahk

; Initialize GDI+
pToken := CGdip.Startup()

; Create a test bitmap (100x100 red)
pBitmap := CGdip.Bitmap.Create(100, 100)
G := CGdip.Graphics.FromBitmap(pBitmap)
pBrush := CGdip.Brush.SolidFill(0xFFFF0000)
G.FillRectangle(pBrush, 0, 0, 100, 100)

; Put on clipboard
pBitmap.SetClipboard()

; Clean up creation resources
G := ""
pBrush := ""
pBitmap := ""

; Try to get it back using our new function
result := ClipboardUtil.TryGetPngFromClipboard()

if !result {
    FileAppend "Failed to get image from clipboard`n", "verify_result.txt"
    ExitApp 1
}

if !InStr(result, "data:image/png;base64,") {
    FileAppend "Result format incorrect: " SubStr(result, 1, 50) "`n", "verify_result.txt"
    ExitApp 1
}

len := StrLen(result)
FileAppend "Success! Retrieved image data length: " len "`n", "verify_result.txt"

CGdip.Shutdown()
ExitApp 0