#!/usr/bin/env python3
"""
Claude Code JSONL transcript -> compact digest for writing a worklog.

Used by the worklog skill's "explicit file input" mode. Not needed when
documenting the current conversation (Claude reads its own context directly).

Extraction priority (by how much signal each carries for a worklog):
  1. User prompts   — intent / decisions / feedback. Always included.
  2. Claude text    — surfaced explanations / rationale. Always included.
  3. tool_use lines — Edit/Write (files changed), Bash (commands, commits). One line each.
  4. tool_result    — omitted by default. With --results, errors / command output, truncated.
  5. thinking       — omitted by default. With --thinking, option deliberation, truncated.

Usage:
    extract_transcript.py <transcript.jsonl> [options]
      --thinking            include assistant thinking blocks (decision rationale)
      --results             include tool_result summaries (useful for debugging sessions)
      --max-chars N         per-block truncation length (default 1200)
      --from "YYYY-MM-DD"   only messages at/after this date (UTC prefix match)

Writes a markdown digest to stdout. Large transcripts produce large digests;
narrow with --from or pipe the result to a file when that happens.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))


def _kst_date(ts):
    """ISO UTC timestamp (…Z) -> KST date (YYYY-MM-DD). None on failure."""
    if not ts:
        return None
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(KST).strftime("%Y-%m-%d")
    except (ValueError, AttributeError):
        return None


def _text_of(content):
    """If content is a string, return it; if a list, join the text blocks."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for b in content:
            if isinstance(b, dict) and b.get("type") == "text":
                parts.append(b.get("text", ""))
        return "\n".join(parts)
    return ""


def _truncate(s, n):
    s = (s or "").strip()
    if len(s) <= n:
        return s
    return s[:n].rstrip() + f"\n…(truncated, +{len(s) - n} chars)"


# Automatic/meta user messages with no worklog value
_NOISE_MARKERS = (
    "<command-name>",
    "<local-command-stdout>",
    "Caveat: The messages below",
    "[Request interrupted",
    "<system-reminder>",
)


def _compact_tool_use(b, max_chars):
    """Summarize a tool_use block into one line, exposing only the key arg."""
    name = b.get("name", "?")
    inp = b.get("input", {}) or {}
    key = ""
    if "file_path" in inp:
        key = inp["file_path"]
    elif "command" in inp:
        key = _truncate(str(inp["command"]), 200).replace("\n", " ⏎ ")
    elif "path" in inp:
        key = inp["path"]
    elif "pattern" in inp:
        key = f"pattern={inp['pattern']!r}"
    elif "description" in inp:
        key = inp["description"]
    elif "prompt" in inp:
        key = _truncate(str(inp["prompt"]), 160)
    else:
        key = _truncate(json.dumps(inp, ensure_ascii=False), 160)
    return f"🔧 {name}({key})"


def _result_summary(content, max_chars):
    """Summarize tool_result blocks inside a user turn (error/output tracing)."""
    out = []
    for b in content if isinstance(content, list) else []:
        if not (isinstance(b, dict) and b.get("type") == "tool_result"):
            continue
        c = b.get("content", "")
        if isinstance(c, list):
            c = "\n".join(
                x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text"
            )
        c = str(c).strip()
        if not c:
            continue
        err = b.get("is_error")
        tag = "⚠️ tool error" if err else "↳ tool result"
        out.append(f"> {tag}: {_truncate(c, max_chars)}".replace("\n", "\n> "))
    return "\n".join(out)


def extract(path, include_thinking, include_results, max_chars, since):
    lines = []
    first_ts = None
    last_ts = None
    branch = None

    with open(path, encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                rec = json.loads(raw)
            except json.JSONDecodeError:
                continue

            rtype = rec.get("type")
            if rtype not in ("user", "assistant"):
                continue

            ts = rec.get("timestamp", "")
            if since and ts and ts < since:
                continue
            if ts:
                first_ts = first_ts or ts
                last_ts = ts
            branch = rec.get("gitBranch") or branch

            msg = rec.get("message", {})
            if not isinstance(msg, dict):
                continue
            content = msg.get("content")

            if rtype == "user":
                text = _text_of(content)
                # user turn that only carries tool_result
                if not text:
                    if include_results:
                        s = _result_summary(content, max_chars)
                        if s:
                            lines.append(s + "\n")
                    continue
                if any(m in text for m in _NOISE_MARKERS):
                    # if a system-reminder etc. is mixed in but real text exists, keep only the real part
                    cleaned = "\n".join(
                        ln for ln in text.splitlines()
                        if not any(m in ln for m in _NOISE_MARKERS)
                    ).strip()
                    if not cleaned:
                        continue
                    text = cleaned
                lines.append(f"### 👤 User\n\n{_truncate(text, max_chars)}\n")

            else:  # assistant
                if not isinstance(content, list):
                    t = _text_of(content)
                    if t:
                        lines.append(f"### 🤖 Claude\n\n{_truncate(t, max_chars)}\n")
                    continue
                buf = []
                for b in content:
                    if not isinstance(b, dict):
                        continue
                    bt = b.get("type")
                    if bt == "text" and b.get("text", "").strip():
                        buf.append(_truncate(b["text"], max_chars))
                    elif bt == "thinking" and include_thinking:
                        th = b.get("thinking", "").strip()
                        if th:
                            buf.append(f"<thinking>\n{_truncate(th, max_chars)}\n</thinking>")
                    elif bt == "tool_use":
                        buf.append(_compact_tool_use(b, max_chars))
                if buf:
                    lines.append("### 🤖 Claude\n\n" + "\n\n".join(buf) + "\n")

    session_date = _kst_date(first_ts)
    session_id = os.path.splitext(os.path.basename(path))[0]
    header = [
        f"# Transcript digest",
        f"- Source: `{path}`",
        f"- Session ID: `{session_id}`  ← the transcript filename (uuid), use in the per-session meta line",
        f"- Branch: `{branch or '?'}`",
        f"- Session date (KST): {session_date or '?'}  ← use as the worklog filename / H1 date",
        f"- Span (UTC): {first_ts or '?'} → {last_ts or '?'}",
        f"- Options: thinking={include_thinking}, results={include_results}, max_chars={max_chars}",
        "\n---\n",
    ]
    return "\n".join(header) + "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description="Claude Code JSONL -> worklog digest")
    ap.add_argument("transcript", help="path to the JSONL transcript")
    ap.add_argument("--thinking", action="store_true", help="include thinking blocks")
    ap.add_argument("--results", action="store_true", help="include tool_result summaries")
    ap.add_argument("--max-chars", type=int, default=1200, help="per-block truncation length")
    ap.add_argument("--from", dest="since", default=None, help="only messages at/after this timestamp (prefix compare)")
    args = ap.parse_args()

    try:
        out = extract(args.transcript, args.thinking, args.results, args.max_chars, args.since)
    except FileNotFoundError:
        print(f"transcript not found: {args.transcript}", file=sys.stderr)
        sys.exit(1)
    sys.stdout.write(out)


if __name__ == "__main__":
    main()
