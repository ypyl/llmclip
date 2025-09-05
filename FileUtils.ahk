#Include Base64.ahk

class FileUtils {
    static GetFileAsBase64(filePath) {
        try {
            if (FileExist(filePath)) {
                fileObj := FileOpen(filePath, "r")
                if (fileObj) {
                    fileSize := fileObj.Length
                    fileBuffer := Buffer(fileSize)
                    fileObj.RawRead(fileBuffer, fileSize)
                    fileObj.Close()

                    return Base64.Encode(fileBuffer)
                }
            }
            return ""
        } catch Error as e {
            return ""
        }
    }
}
