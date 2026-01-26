#Requires AutoHotkey 2.0
#Include Settings\ConfigurationManager.ahk

; Simple test to verify ConfigurationManager works
try {
    config := ConfigurationManager.GetInstance()
    
    ; Test basic properties
    if (config.llmTypes.Length > 0) {
        MsgBox("✓ ConfigurationManager loaded successfully!`n`nFound " . config.llmTypes.Length . " LLM types:`n" . config.llmTypes[1], "Configuration Test", "Iconi T3")
    } else {
        MsgBox("✗ ConfigurationManager failed - no LLM types found", "Configuration Test", "Iconx")
    }
    
    ; Test singleton pattern
    config2 := ConfigurationManager.GetInstance()
    if (config == config2) {
        ; MsgBox("✓ Singleton pattern working correctly", "Configuration Test", "Iconi T2")
    } else {
        MsgBox("✗ Singleton pattern failed", "Configuration Test", "Iconx")
    }
    
} catch as e {
    MsgBox("✗ ConfigurationManager test failed: " . e.Message, "Configuration Test", "Iconx")
}