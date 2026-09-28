Class Base64Helper {
	/**
	 * Base64 Encoding
	 * @param Buf Buffer Object has Ptr, Size Property. May contain any binary contents including NULL bytes.
	 * @param Codec CRYPT_STRING_BASE64 0x00000001
	 * CRYPT_STRING_NOCRLF 0x40000000
	 * @returns Base64 String if success, otherwise blank.
	 */
	static Encode(Buf, Codec := 0x40000001) {
		if Buf is String
			p := StrPtr(Buf), s := StrLen(Buf) * 2
		else p := Buf, s := Buf.Size
		if (DllCall("crypt32\CryptBinaryToString", "Ptr", p, "UInt", s, "UInt", Codec, "Ptr", 0, "Uint*", &nSize := 0) &&
			(VarSetStrCapacity(&VarOut, nSize << 1), DllCall("crypt32\CryptBinaryToString", "Ptr", p, "UInt", s, "UInt", Codec, "Str", VarOut, "Uint*", &nSize)))
			return (VarSetStrCapacity(&VarOut, -1), VarOut)
	}
}
