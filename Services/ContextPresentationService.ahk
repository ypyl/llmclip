#Requires AutoHotkey 2.0

class ContextPresentationService {
    contextManager := ""

    __New(contextManager) {
        this.contextManager := contextManager
    }

    GetListViewItem(item) {
        return {
            label: this.GetLabelFromContextItem(item),
            hasCheckbox: !this.contextManager.IsPdf(item)
        }
    }

    GetLabelFromContextItem(item) {
        if (this.contextManager.IsHttpLink(item)) {
            return "🌐 " item
        }
        if (DirExist(item)) {
            SplitPath item, &name
            return "📁 " name " - " item
        }
        else if (FileExist(item)) {
            SplitPath item, &name, &dir
            if (this.contextManager.IsImage(item)) {
                return "🖼️ " name " - " dir
            }
            if (this.contextManager.IsPdf(item)) {
                return "📕 " name " - " dir
            }
            return "📄 " name " - " dir
        }
        else {
            truncatedText := SubStr(item, 1, 50)
            if (StrLen(item) > 50)
                truncatedText .= "..."
            return "📝 " truncatedText
        }
    }
}
