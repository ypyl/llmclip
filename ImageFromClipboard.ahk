#Include <windows>

class ClipboardUtil {
    static TryGetPngFromClipboard() {
        BitmapDecoder := Windows.Graphics.Imaging.BitmapDecoder
        BitmapEncoder := Windows.Graphics.Imaging.BitmapEncoder
        SoftwareBitmap := Windows.Graphics.Imaging.SoftwareBitmap
        CryptographicBuffer := Windows.Security.Cryptography.CryptographicBuffer
        InMemoryRandomAccessStream := Windows.Storage.Streams.InMemoryRandomAccessStream
        Clipboard := Windows.ApplicationModel.DataTransfer.Clipboard
        BufferClass := Windows.Storage.Streams.Buffer

        content := Clipboard.GetContent()
        if (!content.Contains('Bitmap')) {
            return false
        }
        bitmapRef := content.GetBitmapAsync().await()
        stream := bitmapRef.OpenReadAsync().await()
        decoder := BitmapDecoder.CreateAsync(stream).await()
        frame := decoder.GetFrameAsync(0).await()
        sb := frame.GetSoftwareBitmapAsync().await()

        memStream := InMemoryRandomAccessStream()
        encoder := BitmapEncoder.CreateAsync(BitmapEncoder.PngEncoderId, memStream).await()
        encoder.SetSoftwareBitmap(sb)
        encoder.FlushAsync().await()
        memStream.Seek(0)

        rawSize := memStream.Size
        if (rawSize = 0) {
            return false
        }
        size := rawSize & 0xFFFFFFFF
        if (size > 100 * 1024 * 1024)
            return false

        b := BufferClass(size)
        memStream.ReadAsync(b, size, 0).await()

        b64 := CryptographicBuffer.EncodeToBase64String(b)
        return "data:image/png;base64," . b64
    }
}
