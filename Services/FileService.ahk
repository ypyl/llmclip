#Requires AutoHotkey 2.0

class FileService {
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
}
