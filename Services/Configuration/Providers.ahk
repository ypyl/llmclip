#Include <Json>

class Providers {
    providers := Map()

    __New() {
        this.Reload()
    }

    Reload() {
        this.providers := Map()
        if (DirExist("providers")) {
            fileCount := 0
            Loop Files, "providers\*.json" {
                fileCount++
            }
            skipDefault := fileCount > 1
            Loop Files, "providers\*.json" {
                if (skipDefault && A_LoopFileName = "providers.json") {
                    continue
                }
                try {
                    parsed := JSON.LoadFile(A_LoopFilePath)
                    for key, value in parsed {
                        if (value.Has("models")) {
                            for _, modelConfig in value["models"] {
                                if (modelConfig.Has("model")) {
                                    modelName := modelConfig["model"]
                                    mergedConfig := Map()
                                    
                                    for k, v in value {
                                        if (k != "models") {
                                            mergedConfig[k] := v
                                        }
                                    }
                                    
                                    for k, v in modelConfig {
                                        mergedConfig[k] := v
                                    }
                                    
                                    mergedConfig["provider_name"] := key
                                    this.providers[modelName] := mergedConfig
                                }
                            }
                        } else {
                            this.providers[key] := value
                        }
                    }
                }
            }
        }
    }

    Get(name) {
        if (this.providers.Has(name)) {
            return this.providers[name]
        }
        return Map()
    }
    
    GetAll() {
        return this.providers
    }
    
    GetNames() {
        names := []
        for name in this.providers {
            names.Push(name)
        }
        return names
    }
}
