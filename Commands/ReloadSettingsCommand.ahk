#Requires AutoHotkey 2.0

class ReloadSettingsCommand {
    configService := ""

    __New(configService) {
        this.configService := configService
    }

    Execute() {
        this.configService.Reload()
    }
}
