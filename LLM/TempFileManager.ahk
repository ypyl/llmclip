class TempFileManager {
    static TempDir := A_ScriptDir "\temp"

    static CleanUp() {
        if DirExist(this.TempDir) {
            try {
                DirDelete(this.TempDir, true)
            } catch as e {
                ; Ignore errors if files are in use
            }
        }
        if !DirExist(this.TempDir) {
            DirCreate(this.TempDir)
        }
    }

    static GetPath(filename := "") {
        if (filename = "")
            return this.TempDir
        return this.TempDir "\" filename
    }
}
