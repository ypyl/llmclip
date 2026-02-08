#Include Base64Service.ahk
class FileService {
    static GetFileAsBase64(filePath) {
        try {
            if (FileExist(filePath)) {
                fileObj := FileOpen(filePath, "r")
                if (fileObj) {
                    fileSize := fileObj.Length
                    fileBuffer := Buffer(fileSize)
                    fileObj.RawRead(fileBuffer, fileSize)
                    fileObj.Close()

                    return Base64Service.Encode(fileBuffer)
                }
            }
            return ""
        } catch Error as e {
            return ""
        }
    }

    /**
     * Write content to a file. Overwrites if exists.
     * @param filePath The absolute path to the file
     * @param content The string content to write
     * @param encoding The encoding to use (default UTF-8)
     */
    WriteText(filePath, content, encoding := "UTF-8") {
        if (FileExist(filePath)) {
            FileDelete(filePath)
        }
        FileAppend(content, filePath, encoding)
    }

    /**
     * Read content from a file.
     * @param filePath The absolute path to the file
     * @param encoding The encoding to use (default UTF-8)
     * @returns The string content of the file
     */
    ReadText(filePath, encoding := "UTF-8") {
        if (!FileExist(filePath)) {
            throw Error("File not found: " . filePath)
        }
        return FileRead(filePath, encoding)
    }

    /**
     * Generates a filename with a timestamp.
     * @param prefix String to prepend to the timestamp
     * @param extension File extension (including the dot)
     * @returns A string like "prefix_YYYYMMDD_HHMMSS.extension"
     */
    GetTimestampedFilename(prefix, extension) {
        timestamp := FormatTime(, "yyyyMMdd_HHmmss")
        return prefix . "_" . timestamp . extension
    }
}
