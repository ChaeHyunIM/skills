#!/usr/bin/env python3
"""Codex JSONL transcript -> compact digest for writing a worklog.

Used by write-worklog's explicit transcript mode. Current-task mode should use
the conversation context directly.

Usage:
    extract_transcript.py <rollout.jsonl> [options]
      --thinking            include recorded reasoning summaries
      --results             include tool outputs, truncated
      --max-chars N         per-block truncation length (default 1200)
      --from "YYYY-MM-DD"   only records at/after this timestamp prefix

The extractor never decrypts or emits Codex's encrypted reasoning payload.
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))


def _kst_date(ts):
    """ISO UTC timestamp -> KST date (YYYY-MM-DD). None on failure."""
    if not ts:
        return None
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(KST).strftime("%Y-%m-%d")
    except (ValueError, AttributeError):
        return None


def _truncate(value, limit):
    text = (value or "").strip()
    if len(text) <= limit:
        return text
    return text[:limit].rstrip() + f"\n…(truncated, +{len(text) - limit} chars)"


def _block_text(blocks, accepted_types):
    if not isinstance(blocks, list):
        return ""
    parts = []
    for block in blocks:
        if not isinstance(block, dict) or block.get("type") not in accepted_types:
            continue
        text = block.get("text", "")
        if isinstance(text, str) and text.strip():
            parts.append(text)
    return "\n".join(parts)


_NOISE_PREFIXES = (
    "# AGENTS.md instructions",
    "<environment_context>",
    "<recommended_plugins>",
    "<permissions instructions>",
    "<app-context>",
    "<skills_instructions>",
)


def _is_noise_user_message(text):
    stripped = text.lstrip()
    return any(stripped.startswith(prefix) for prefix in _NOISE_PREFIXES)


def _compact_tool_call(payload, max_chars):
    name = payload.get("name", "tool")
    raw_input = payload.get("input", payload.get("arguments", ""))
    if not isinstance(raw_input, str):
        raw_input = json.dumps(raw_input, ensure_ascii=False)

    if name == "exec":
        nested = re.findall(r"tools\.([A-Za-z0-9_]+)\s*\(", raw_input)
        if nested:
            name = "exec:" + ",".join(dict.fromkeys(nested))

    one_line = re.sub(r"\s+", " ", raw_input).strip()
    return f"🔧 {name}({_truncate(one_line, min(max_chars, 240))})"


def _tool_output(payload, max_chars):
    output = payload.get("output")
    if isinstance(output, str):
        text = output
    else:
        text = _block_text(output, {"input_text", "output_text", "text"})
    if not text:
        return ""
    rendered = _truncate(text, max_chars).replace("\n", "\n> ")
    return f"> ↳ tool result: {rendered}"


def _reasoning_summary(payload, max_chars):
    text = _block_text(payload.get("summary"), {"summary_text"})
    if not text:
        return ""
    return f"<reasoning-summary>\n{_truncate(text, max_chars)}\n</reasoning-summary>"


def extract(path, include_thinking, include_results, max_chars, since):
    lines = []
    first_ts = None
    last_ts = None
    session_id = None
    cwd = None

    with open(path, encoding="utf-8") as transcript:
        for raw in transcript:
            raw = raw.strip()
            if not raw:
                continue
            try:
                record = json.loads(raw)
            except json.JSONDecodeError:
                continue

            record_type = record.get("type")
            payload = record.get("payload", {})
            if not isinstance(payload, dict):
                continue

            if record_type == "session_meta":
                session_id = payload.get("session_id") or payload.get("id") or session_id
                cwd = payload.get("cwd") or cwd
                first_ts = payload.get("timestamp") or record.get("timestamp") or first_ts
                continue

            ts = record.get("timestamp", "")
            if since and ts and ts < since:
                continue
            if ts:
                first_ts = first_ts or ts
                last_ts = ts

            if record_type == "turn_context":
                cwd = payload.get("cwd") or cwd
                continue

            if record_type != "response_item":
                continue

            payload_type = payload.get("type")
            if payload_type == "message":
                role = payload.get("role")
                if role not in {"user", "assistant"}:
                    continue
                text = _block_text(payload.get("content"), {"input_text", "output_text", "text"})
                if not text or (role == "user" and _is_noise_user_message(text)):
                    continue
                label = "👤 User" if role == "user" else "🤖 Codex"
                lines.append(f"### {label}\n\n{_truncate(text, max_chars)}\n")
                continue

            if payload_type in {"custom_tool_call", "function_call"}:
                lines.append(_compact_tool_call(payload, max_chars) + "\n")
                continue

            if payload_type in {"custom_tool_call_output", "function_call_output"} and include_results:
                result = _tool_output(payload, max_chars)
                if result:
                    lines.append(result + "\n")
                continue

            if payload_type == "reasoning" and include_thinking:
                summary = _reasoning_summary(payload, max_chars)
                if summary:
                    lines.append(summary + "\n")

    session_date = _kst_date(first_ts)
    if not session_id:
        basename = os.path.splitext(os.path.basename(path))[0]
        match = re.search(
            r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$",
            basename,
            re.IGNORECASE,
        )
        session_id = match.group(1) if match else basename

    header = [
        "# Transcript digest",
        f"- Source: `{path}`",
        f"- Session ID: `{session_id}`",
        f"- Working directory: `{cwd or '?'}`",
        f"- Session date (KST): {session_date or '?'}",
        f"- Span (UTC): {first_ts or '?'} → {last_ts or '?'}",
        f"- Options: thinking={include_thinking}, results={include_results}, max_chars={max_chars}",
        "\n---\n",
    ]
    return "\n".join(header) + "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Codex JSONL -> worklog digest")
    parser.add_argument("transcript", help="path to a Codex rollout JSONL file")
    parser.add_argument("--thinking", action="store_true", help="include recorded reasoning summaries")
    parser.add_argument("--results", action="store_true", help="include truncated tool outputs")
    parser.add_argument("--max-chars", type=int, default=1200, help="per-block truncation length")
    parser.add_argument("--from", dest="since", default=None, help="only records at/after this timestamp")
    args = parser.parse_args()

    try:
        output = extract(
            args.transcript,
            args.thinking,
            args.results,
            args.max_chars,
            args.since,
        )
    except FileNotFoundError:
        print(f"transcript not found: {args.transcript}", file=sys.stderr)
        sys.exit(1)
    sys.stdout.write(output)


if __name__ == "__main__":
    main()
