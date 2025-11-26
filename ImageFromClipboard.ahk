#Include Lib\CGDip.ahk
#Include Base64.ahk

class ClipboardUtil {
    static TryGetPngFromClipboard() {
        pToken := CGdip.Startup()
        if !pToken
            return false

        pBitmap := CGdip.Bitmap.FromClipboard()
        if !IsObject(pBitmap) {
            CGdip.Shutdown()
            return false
        }

        ; Save to memory stream as PNG
        pStream := pBitmap.Save(".png")
        if !pStream {
            pBitmap := ""
            CGdip.Shutdown()
            return false
        }

        ; Get HGLOBAL from stream
        DllCall("ole32\GetHGlobalFromStream", "Ptr", pStream, "Ptr*", &hGlobal := 0)
        pData := DllCall("GlobalLock", "Ptr", hGlobal, "Ptr")
        nSize := DllCall("GlobalSize", "Ptr", hGlobal, "UPtr")

        ; Copy to Buffer
        buf := Buffer(nSize)
        DllCall("RtlMoveMemory", "Ptr", buf, "Ptr", pData, "UPtr", nSize)

        ; Cleanup
        DllCall("GlobalUnlock", "Ptr", hGlobal)
        ObjRelease(pStream)
        pBitmap := ""
        CGdip.Shutdown()

        ; Convert to Base64
        b64 := Base64.Encode(buf)
        if !b64
            return false

        return "data:image/png;base64," . b64
    }
}
