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
        ; Every providers\*.json merges additively. Provider-level keys are set
        ; on first sight, models merge by name. Never skip providers.json: a
        ; company-specific file must not disable the shipped defaults.
        Loop Files, "providers\*.json" {
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
}
