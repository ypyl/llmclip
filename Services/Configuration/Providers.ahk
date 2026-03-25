#Include <Json>

class Providers {
    providers := Map()

    __New() {
        this.Reload()
    }

    Reload() {
        this.providers := Map()
        if (!DirExist("providers"))
            return
        fileCount := 0
        Loop Files, "providers\*.json"
            fileCount++
        skipDefault := fileCount > 1
        Loop Files, "providers\*.json" {
            if (skipDefault && A_LoopFileName = "providers.json")
                continue
            try {
                parsed := JSON.LoadFile(A_LoopFilePath)
                for providerName, providerConfig in parsed {
                    if (!this.providers.Has(providerName)) {
                        entry := Map()
                        for k, v in providerConfig {
                            if (k != "models")
                                entry[k] := v
                        }
                        entry["models"] := Map()
                        this.providers[providerName] := entry
                    }
                    if (providerConfig.Has("models")) {
                        for _, modelConfig in providerConfig["models"] {
                            if (!modelConfig.Has("model"))
                                continue
                            modelName := modelConfig["model"]
                            merged := Map()
                            for k, v in providerConfig {
                                if (k != "models")
                                    merged[k] := v
                            }
                            for k, v in modelConfig
                                merged[k] := v
                            merged["provider_name"] := providerName
                            this.providers[providerName]["models"][modelName] := merged
                        }
                    }
                }
            }
        }
    }

    ; Returns merged config for a specific provider+model
    Get(providerName, modelName) {
        if (this.providers.Has(providerName) && this.providers[providerName]["models"].Has(modelName))
            return this.providers[providerName]["models"][modelName]
        return Map()
    }

    GetAll() {
        return this.providers
    }

    ; Returns flat list of "providerName/modelName" strings
    GetNames() {
        names := []
        for providerName, providerEntry in this.providers {
            for modelName in providerEntry["models"]
                names.Push(providerName . "/" . modelName)
        }
        return names
    }
}
