// textmsg_fix - TextMsg tail-byte sanitizer (module 40)
//
// Root cause of the "client crashes when the wait period ends" bug
// (proven by crash-dump reverse engineering + a msvcr120 reproduction
// experiment): on a Chinese Windows system the game's MSVC CRT runs
// _vsnprintf in CP936 multibyte mode, and the Black Mesa client passes
// the TextMsg payload as the FORMAT STRING to _vsnprintf. UTF-8 Chinese
// text is therefore validated as GBK byte pairs; a message whose LAST
// byte is a dangling GBK lead byte (0x81..0xFE - the 3rd byte of any
// UTF-8 CJK character) fails validation with EINVAL, which triggers
// InvalidParameterHandler -> fail-fast crash. Appending a single ASCII
// character at the end fixes it completely (experiment: exit 127
// without, rc=34 with). Messages ENDING in ASCII are always safe.
//
// Two layers:
// 1. Safe* wrapper functions (SafePrintCenterText / SafePrintToChat /
//    SafePrintHintText + All variants): format once, append a space
//    when the last byte is a GBK lead byte, send with "%s". All
//    Chinese text senders (advertisements, bms_match) must use these
//    instead of the raw natives: SourceMod's own usermessage path
//    (ENGINE_CALL) deliberately bypasses HookUserMessage, so the hook
//    below can never see plugin-sent messages.
// 2. HookUserMessage("TextMsg"): catches GAME-sent (server.dll)
//    messages, which DO pass through IVEngineServer::UserMessageBegin.
//    Stray '%' specifiers are escaped (the client re-formats the
//    payload itself) and unsafe tails get a trailing space. Every
//    intercepted message is logged to logs/textmsg_fix.log.
//
// All symbols get the mod_textmsg_fix_ prefix. Pure ASCII: no player
// facing text in here.

UserMsg g_TextMsgFix_hMsg = INVALID_MESSAGE_ID;

// Append one trailing ASCII space when the last byte is a GBK lead byte
// (0x81..0xFE) and would be dangling at end of string under CP936.
void TextMsgFix_SafeTail(char[] text, int maxlen)
{
	int len = strlen(text);
	if (len > 0 && len + 1 < maxlen)
	{
		int last = text[len - 1] & 0xFF;
		if (last >= 0x81 && last <= 0xFE)
		{
			text[len] = ' ';
			text[len + 1] = '\0';
		}
	}
}

bool TextMsgFix_TailUnsafe(const char[] s)
{
	int len = strlen(s);
	if (len == 0)
	{
		return false;
	}
	int last = s[len - 1] & 0xFF;
	return last >= 0x81 && last <= 0xFE;
}

// Returns the index just past the specifier if the '%' at position i
// starts a valid printf conversion, or -1 if it is stray/invalid.
int TextMsgFix_CheckSpecifier(const char[] s, int i, int len)
{
	int j = i + 1;
	if (j < len && s[j] == '%')
	{
		return j + 1;
	}
	// flags
	while (j < len)
	{
		char c = s[j];
		if (c == '-' || c == '+' || c == ' ' || c == '#' || c == '0')
		{
			j++;
			continue;
		}
		break;
	}
	// width / precision / positional / length modifiers
	while (j < len)
	{
		char c = s[j];
		if ((c >= '0' && c <= '9') || c == '.' || c == '*' || c == '$'
			|| c == 'l' || c == 'h' || c == 'L' || c == 'j' || c == 'z'
			|| c == 't' || c == 'I' || c == 'q' || c == 'w')
		{
			j++;
			continue;
		}
		break;
	}
	if (j >= len)
	{
		return -1;
	}
	char c = s[j];
	if (c == 'c' || c == 'd' || c == 'i' || c == 'e' || c == 'E' || c == 'f'
		|| c == 'g' || c == 'G' || c == 'o' || c == 's' || c == 'u' || c == 'x'
		|| c == 'X' || c == 'p' || c == 'n' || c == 'a' || c == 'A' || c == 'C'
		|| c == 'S')
	{
		return j + 1;
	}
	return -1;
}

bool TextMsgFix_HasStrayPercent(const char[] s)
{
	int len = strlen(s);
	for (int i = 0; i < len; i++)
	{
		if (s[i] != '%')
		{
			continue;
		}
		int after = TextMsgFix_CheckSpecifier(s, i, len);
		if (after < 0)
		{
			return true;
		}
		i = after - 1;
	}
	return false;
}

// Copy s to out, doubling every STRAY '%' (valid specifiers are kept
// as-is so they can still be substituted server-side). Result is a
// format string that is safe to pass to Format().
void TextMsgFix_EscapeTemplate(const char[] input, char[] out, int outlen)
{
	int len = strlen(input);
	int o = 0;
	int i = 0;
	while (i < len && o < outlen - 1)
	{
		if (input[i] == '%')
		{
			int after = TextMsgFix_CheckSpecifier(input, i, len);
			if (after < 0)
			{
				if (o + 1 >= outlen)
				{
					break;
				}
				out[o++] = '%';
				out[o++] = '%';
				i++;
				continue;
			}
			while (i < after && o < outlen - 1)
			{
				out[o++] = input[i++];
			}
			continue;
		}
		out[o++] = input[i++];
	}
	out[o] = '\0';
}

// ---- Safe* wrappers: format once, sanitize the tail byte, send. ----

void SafePrintCenterText(int client, const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 3);
	TextMsgFix_SafeTail(buffer, sizeof(buffer));
	PrintCenterText(client, "%s", buffer);
}

void SafePrintCenterTextAll(const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	TextMsgFix_SafeTail(buffer, sizeof(buffer));
	PrintCenterTextAll("%s", buffer);
}

void SafePrintToChat(int client, const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 3);
	TextMsgFix_SafeTail(buffer, sizeof(buffer));
	PrintToChat(client, "%s", buffer);
}

void SafePrintToChatAll(const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	TextMsgFix_SafeTail(buffer, sizeof(buffer));
	PrintToChatAll("%s", buffer);
}

void SafePrintHintText(int client, const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 3);
	TextMsgFix_SafeTail(buffer, sizeof(buffer));
	PrintHintText(client, "%s", buffer);
}

void SafePrintHintTextAll(const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	TextMsgFix_SafeTail(buffer, sizeof(buffer));
	PrintHintTextAll("%s", buffer);
}

// ---- Game-sent TextMsg hook ----

public Action TextMsgFix_OnTextMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int dest = msg.ReadByte();

	char tpl[256];
	char p1[128];
	char p2[128];
	char p3[128];
	char p4[128];
	tpl[0] = '\0';
	p1[0] = '\0';
	p2[0] = '\0';
	p3[0] = '\0';
	p4[0] = '\0';
	msg.ReadString(tpl, sizeof(tpl));
	msg.ReadString(p1, sizeof(p1));
	msg.ReadString(p2, sizeof(p2));
	msg.ReadString(p3, sizeof(p3));
	msg.ReadString(p4, sizeof(p4));

	LogToFile("textmsg_fix.log", "dest=%d tpl=\"%s\" p1=\"%s\" p2=\"%s\" p3=\"%s\" p4=\"%s\"",
		dest, tpl, p1, p2, p3, p4);

	bool tailBad = TextMsgFix_TailUnsafe(tpl);
	bool stray = TextMsgFix_HasStrayPercent(tpl);

	if ((dest != 3 && dest != 4) || (!tailBad && !stray))
	{
		return Plugin_Continue;
	}

	// Sanitize: escape stray % in the template, format it server-side
	// (valid specifiers substituted, escaped % rendered literally), then
	// escape the result once more because the client re-formats param0
	// with its own _vsnprintf. Finally append a safe ASCII tail byte so
	// the client-side CP936 format validation can never see a dangling
	// multibyte lead. The client renders the exact intended text.
	char escaped[512];
	char out[512];
	TextMsgFix_EscapeTemplate(tpl, escaped, sizeof(escaped));
	Format(out, sizeof(out), escaped, p1, p2, p3, p4);
	ReplaceString(out, sizeof(out), "%", "%%");
	TextMsgFix_SafeTail(out, sizeof(out));

	// This hook runs with intercept=true, i.e. INSIDE the engine's
	// usermessage send. Sending another usermessage (PrintToChat/
	// PrintCenterText) here nests a send inside a send: SourceMod throws
	// "Could not send a usermessage", the exception aborts the hook, and
	// the in-flight TextMsg is left corrupted - which crashes the client
	// (verified: !timeleft -> errors log -> bms.exe crash). Defer the
	// re-send to the next game frame instead.
	DataPack dp = new DataPack();
	dp.WriteCell(dest);
	dp.WriteString(out);
	dp.WriteCell(playersNum);
	for (int i = 0; i < playersNum; i++)
	{
		dp.WriteCell(players[i]);
	}
	RequestFrame(TextMsgFix_ResendFrame, dp);
	return Plugin_Handled;
}

// Runs on the next game frame, outside any usermessage send, and delivers
// the sanitized message with the same destination the game used.
public void TextMsgFix_ResendFrame(any data)
{
	DataPack dp = view_as<DataPack>(data);
	dp.Reset();
	int dest = dp.ReadCell();
	char out[512];
	dp.ReadString(out, sizeof(out));
	int num = dp.ReadCell();
	int[] targets = new int[MaxClients];
	for (int i = 0; i < num; i++)
	{
		targets[i] = dp.ReadCell();
	}
	delete dp;

	if (num <= 0)
	{
		// No explicit recipient list (should not happen with SM hooks,
		// but never drop the message): fall back to everyone in game.
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				targets[num++] = i;
			}
		}
	}
	for (int i = 0; i < num; i++)
	{
		if (!IsClientInGame(targets[i]))
		{
			continue;
		}
		if (dest == 4)
		{
			PrintCenterText(targets[i], "%s", out);
		}
		else
		{
			PrintToChat(targets[i], "%s", out);
		}
	}
}

public void OnPluginStart()
{
	g_TextMsgFix_hMsg = GetUserMessageId("TextMsg");
	if (g_TextMsgFix_hMsg == INVALID_MESSAGE_ID)
	{
		LogMessage("textmsg_fix: TextMsg user message not found, hook layer disabled (Safe* wrappers still active)");
		return;
	}
	HookUserMessage(g_TextMsgFix_hMsg, TextMsgFix_OnTextMsg, true);
}
