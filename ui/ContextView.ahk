class ContextView {
    contextBox := ""
    selectAllCheckbox := ""
    deleteButton := ""
    clearSelectionButton := ""
    clearAllButton := ""
    controller := ""

    Create(gui, contextViewController) {
        this.controller := contextViewController

        this.selectAllCheckbox := gui.Add("Button", "vSelectAllCheckbox x10 y10 w100", "Toggle")
        this.selectAllCheckbox.OnEvent("Click", ObjBindMethod(contextViewController, "SelectAllToggle"))

        this.contextBox := gui.Add("ListView", "vContextBox x10 y40 w380 h150 Checked -Hdr", ["Item"])
        this.contextBox.OnEvent("ItemSelect", ObjBindMethod(contextViewController, "ContextBoxSelect"))
        this.contextBox.OnEvent("DoubleClick", ObjBindMethod(contextViewController, "ContextBoxDoubleClick"))

        ; LVN_ITEMCHANGED = -101
        this.contextBox.OnNotify(-101, (ctrl, lParam) => this.OnContextBoxNotify(ctrl, lParam))

        this.deleteButton := gui.Add("Button", "x10 y190 w120", "Delete")
        this.deleteButton.OnEvent("Click", ObjBindMethod(contextViewController, "DeleteSelected"))

        this.clearSelectionButton := gui.Add("Button", "x140 y190 w120", "Reset Selection")
        this.clearSelectionButton.OnEvent("Click", ObjBindMethod(contextViewController, "ResetSelection"))

        this.clearAllButton := gui.Add("Button", "x270 y190 w120", "Clear Context")
        this.clearAllButton.OnEvent("Click", ObjBindMethod(contextViewController, "ClearAllContext"))
    }

    OnContextBoxNotify(ctrl, lParam) {
        iItem := NumGet(lParam, 3 * A_PtrSize, "Int") + 1
        uNewState := NumGet(lParam, 3 * A_PtrSize + 8, "UInt")
        uOldState := NumGet(lParam, 3 * A_PtrSize + 12, "UInt")

        if ((uNewState & 0xF000) != (uOldState & 0xF000)) {
            checked := this.IsItemChecked(iItem)
            this.controller.ContextBoxItemCheck(iItem, checked)
        }
    }

    IsItemChecked(index) {
        if (!this.contextBox)
            return true
        Result := SendMessage(0x102C, index-1, 0xF000, this.contextBox.Hwnd) ; LVM_GETITEMSTATE
        State := (Result >> 12) - 1
        return State == 1
    }

    DeleteItems() => this.contextBox.Delete()
    AddItem(label, options) => this.contextBox.Add(options, label)
    Modify(row, options) => this.contextBox.Modify(row, options)
    GetCount() => this.contextBox.GetCount()
    ModifyCol(col, width) => this.contextBox.ModifyCol(col, width)
    GetNext(row) => this.contextBox.GetNext(row)
    GetValue() => this.contextBox.Value

    RemoveCheckbox(row) {
        LVITEM := Buffer(60, 0)
        NumPut("UInt", 0x8, LVITEM, 0)      ; mask = LVIF_STATE (0x0008)
        NumPut("Int", row - 1, LVITEM, 4)   ; iItem (0-based)
        NumPut("Int", 0, LVITEM, 8)         ; iSubItem
        NumPut("UInt", 0, LVITEM, 12)       ; state (0 = no image)
        NumPut("UInt", 0xF000, LVITEM, 16)  ; stateMask = LVIS_STATEIMAGEMASK (0xF000)
        SendMessage(0x102B, row - 1, LVITEM.Ptr, this.contextBox.Hwnd)
    }
}
