#Include ..\..\Lib\Json.ahk

/**
 * Resolves credentials declared as a shell command in provider JSON.
 *
 * A provider entry may declare:
 *   "auth": {
 *     "type": "command",
 *     "command": "az account get-access-token --resource ... -o tsv",
 *     "ttl_seconds": 900,
 *     "skew_seconds": 60,
 *     "login_hint": "az login"
 *   }
 *
 * The command must print the token on stdout. Tokens are cached per command
 * string, so two providers that share a command share one cache entry.
 *
 * Expiry comes from ttl_seconds rather than from the token itself: tenant
 * token lifetime is a policy decision and the CLI output format is not a
 * contract. A wrong TTL costs one rejected request, because LLMClient
 * invalidates the cache on any 401.
 */
class TokenService {
    static DEFAULT_TTL := 900
    static DEFAULT_SKEW := 60
    static TOKEN_PREFIX := "eyJ"
    ; Trim() defaults to space and tab only; a stray CR/LF inside an
    ; Authorization header breaks the request, so strip all whitespace.
    static TRIM_CHARS := " `t`r`n"

    cache := Map()   ; command string -> {token, acquiredAt}
    isCancelled := false
    pid := 0
    tempDir := A_ScriptDir "\temp"

    /**
     * @param authConfig Map from provider JSON (the "auth" object)
     * @returns The access token as a string
     * @throws Error when the config is invalid, the command fails, or the
     *         output does not look like a token
     */
    GetToken(authConfig) {
        if (!(authConfig is Map))
            throw Error("Auth config must be an object")

        command := authConfig.Get("command", "")
        if (command = "")
            throw Error("Auth config has no command")

        windowSec := authConfig.Get("ttl_seconds", TokenService.DEFAULT_TTL)
            - authConfig.Get("skew_seconds", TokenService.DEFAULT_SKEW)
        if (windowSec < 1)
            windowSec := 1

        if (this.cache.Has(command)) {
            entry := this.cache[command]
            if (DateDiff(A_NowUTC, entry.acquiredAt, "Seconds") < windowSec)
                return entry.token
            this.cache.Delete(command)
        }

        token := this.RunCommand(command, authConfig)
        this.cache[command] := { token: token, acquiredAt: A_NowUTC }
        return token
    }

    /** Drops the cached token for this config, forcing a fresh fetch next time. */
    Invalidate(authConfig) {
        if (!(authConfig is Map))
            return
        command := authConfig.Get("command", "")
        if (command != "" && this.cache.Has(command))
            this.cache.Delete(command)
    }

    /** Aborts an in-flight token fetch. */
    Cancel() {
        this.isCancelled := true
        if (this.pid > 0) {
            try RunWait('taskkill /F /T /PID ' . this.pid, , "Hide")
            this.pid := 0
        }
    }

    ; Runs the command without blocking the message loop, mirroring
    ; PowerShellTool.ExecuteScript: AHK cannot capture stdout from Run(),
    ; so output goes to temp files through cmd.exe redirects.
    RunCommand(command, authConfig) {
        if (!DirExist(this.tempDir))
            DirCreate(this.tempDir)

        stamp := A_TickCount
        outFile := this.tempDir "\_token_out_" . stamp . ".txt"
        errFile := this.tempDir "\_token_err_" . stamp . ".txt"

        ; cmd.exe is required for PATH lookup of .cmd shims (az is one) and
        ; for the redirects. stdout and stderr stay separate: CLI warnings on
        ; stderr would otherwise corrupt the token.
        cmdLine := 'cmd.exe /c "' . command
            . ' > "' . outFile . '" 2> "' . errFile . '""'

        this.isCancelled := false
        pid := 0
        Run(cmdLine, , "Hide", &pid)
        this.pid := pid

        try {
            while ProcessExist(pid) {
                if (this.isCancelled) {
                    try RunWait('taskkill /F /T /PID ' . pid, , "Hide")
                    throw Error("Request cancelled")
                }
                Sleep(50)
            }

            ; Cancel() kills the pid, so the loop above can exit without the
            ; in-loop check ever firing. Check once more before trusting output.
            if (this.isCancelled)
                throw Error("Request cancelled")

            token := FileExist(outFile) ? Trim(FileRead(outFile, "UTF-8"), TokenService.TRIM_CHARS) : ""
            if (SubStr(token, 1, StrLen(TokenService.TOKEN_PREFIX)) = TokenService.TOKEN_PREFIX)
                return token

            throw Error(this.BuildFailureMessage(token, errFile, authConfig))

        } finally {
            this.pid := 0
            this.isCancelled := false
            try FileDelete(outFile)
            try FileDelete(errFile)
        }
    }

    BuildFailureMessage(stdout, errFile, authConfig) {
        message := "Token acquisition failed."
        hint := authConfig.Get("login_hint", "")
        if (hint != "")
            message .= ' Run "' . hint . '" and retry.'

        stderr := FileExist(errFile) ? Trim(FileRead(errFile, "UTF-8"), TokenService.TRIM_CHARS) : ""
        if (stderr != "")
            message .= " Details: " . stderr
        else if (stdout != "")
            message .= " Unexpected output: " . SubStr(stdout, 1, 200)
        else
            message .= " The command produced no output."

        return message
    }
}
