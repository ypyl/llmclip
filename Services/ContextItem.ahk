class ContextItem {
    Value := ""
    Checked := true

    __New(value, checked := true) {
        this.Value := value
        this.Checked := checked
    }

    ; For serialization
    ToObject() {
        return {
            Value: this.Value,
            Checked: this.Checked
        }
    }

    static FromObject(obj) {
        if (Type(obj) = "Map") {
            return ContextItem(obj["Value"], obj["Checked"])
        }
        return ContextItem(obj.Value, obj.Checked)
    }
}
