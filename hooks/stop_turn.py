"""The reply text a Stop hook checks. Imported by the Stop hooks' programs
beside this file, which `python3 hooks/<name>.py` puts on the import path.
"""

import json


def turn_text(hook):
    """The assistant text of the turn that just ended."""
    last = hook.get("last_assistant_message")
    if isinstance(last, str) and last:
        return last
    path = hook.get("transcript_path")
    if not path:
        return ""
    texts = []
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                try:
                    entry = json.loads(raw)
                except ValueError:
                    continue
                if entry.get("isSidechain"):
                    continue
                kind = entry.get("type")
                content = (entry.get("message") or {}).get("content")
                # A loaded skill or a subagent's report arrives mid-turn as an
                # isMeta user entry, and does not start a new turn.
                if kind == "user" and not entry.get("isMeta") and _is_prompt(content):
                    texts = []
                elif kind == "assistant" and isinstance(content, list):
                    texts.extend(
                        c.get("text", "") for c in content
                        if isinstance(c, dict) and c.get("type") == "text"
                    )
    except OSError:
        return ""
    return "\n".join(texts)


def _is_prompt(content):
    """A user entry that starts a turn, rather than one carrying a tool result."""
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        return not any(
            isinstance(c, dict) and c.get("type") == "tool_result" for c in content
        )
    return False
