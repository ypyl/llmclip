#Requires AutoHotkey 2.0
#Include LLM/TempFileManager.ahk

class PdfProcessor {
    static PdfToolsDir := "pdf"

    static ExtractText(toolPath, pdfPath) {
        if !FileExist(toolPath)
            return ""
        if !FileExist(pdfPath)
            return ""

        SplitPath(pdfPath, &name, , &ext, &name_no_ext)
        outputDir := TempFileManager.GetPath(name_no_ext)
        if !DirExist(outputDir)
            DirCreate(outputDir)
        
        outputFile := outputDir . "\" . name_no_ext . ".txt"
        
        command := Format('"{1}" "{2}" "{3}"', toolPath, pdfPath, outputFile)
        RunWait(command, , "Hide")

        if FileExist(outputFile)
            return outputFile
        return ""
    }

    static ExtractImages(pdfPath) {
        if !FileExist(pdfPath)
            return []

        SplitPath(pdfPath, &name, , &ext, &name_no_ext)
        outputDir := TempFileManager.GetPath(name_no_ext . "_images")
        if !DirExist(outputDir)
            DirCreate(outputDir)

        toolPath := this.PdfToolsDir . "\pdfimages.exe"
        
        if !FileExist(toolPath)
            return []

        ; Run pdfimages -png
        ; Format: pdfimages -png input.pdf output_prefix
        outputPrefix := outputDir . "\img"
        command := Format('"{1}" -j "{2}" "{3}"', toolPath, pdfPath, outputPrefix)
        RunWait(command, , "Hide")

        images := []
        Loop Files, outputDir . "\*.jpg"
        {
            images.Push(A_LoopFileFullPath)
        }
        return images
    }
}
