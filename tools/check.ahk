#SingleInstance Force

; Create the GUI window
GuiObj := Gui()
GuiObj.Opt("+Resize")  ; Allow resizing
GuiObj.Title := "Shell32.dll Icons"

; Add a ListView control to display icons and their indices
LV := GuiObj.Add("ListView", "r20 w400", ["Index", "Icon"])
LV.Opt("+Grid +LV0x10000")  ; Grid lines and full-row select

; Set the icon size for the ListView (16x16 small icons)
LV.SetImageList(ImageListID := DllCall("ImageList_Create", "Int", 16, "Int", 16, "UInt", 0x21, "Int", 1, "Int", 256))

; Populate the ListView with icons from shell32.dll
Loop 512  ; 0 to 255
{
    IconIndex := A_Index - 1  ; A_Index starts at 1, icons at 0
    ; Extract icon and add to ImageList
    hIcon := DllCall("Shell32\ExtractIconW", "Ptr", 0, "Str", "shell32.dll", "Int", IconIndex, "Ptr")
    if (hIcon) {
        DllCall("ImageList_ReplaceIcon", "Ptr", ImageListID, "Int", -1, "Ptr", hIcon)
        DllCall("DestroyIcon", "Ptr", hIcon)  ; Clean up the icon handle
        ; Add row to ListView (IconIndex + 1 to match visible numbering)
        LV.Add("Icon" . IconIndex, IconIndex, "")
    }
}

; Show the GUI
GuiObj.Show()

return
