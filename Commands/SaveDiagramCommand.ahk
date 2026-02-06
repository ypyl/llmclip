#Requires AutoHotkey 2.0

class SaveDiagramCommand {
    fileService := ""

    __New(fileService) {
        this.fileService := fileService
    }

    /**
     * Executes the command to save the diagram data to a file.
     * @param filePath The path where to save the diagram.
     * @param svgData The SVG data to save.
     */
    Execute(filePath, svgData) {
        if (filePath = "") {
            return
        }

        ; Ensure .svg extension
        if (!RegExMatch(filePath, "i)\.svg$")) {
            filePath .= ".svg"
        }

        try {
            this.fileService.WriteText(filePath, svgData, "UTF-8")
        } catch Error as err {
            throw Error("Failed to save diagram: " . err.Message)
        }
    }
}
