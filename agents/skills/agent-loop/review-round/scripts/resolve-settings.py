#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import uuid


def current_session():
    session_id = os.environ.get("CODEX_THREAD_ID") or os.environ.get("CODEX_SESSION_ID")
    if not session_id:
        raise ValueError("현재 Codex 세션 ID가 없습니다. --codex-model과 effort를 명시하세요.")
    try:
        uuid.UUID(session_id)
    except ValueError:
        raise ValueError("현재 Codex 세션 ID가 올바르지 않습니다.") from None
    home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))).expanduser()
    databases = [p for p in home.glob("state_*.sqlite") if re.fullmatch(r"state_\d+\.sqlite", p.name)]
    values = {}
    if databases:
        database = max(databases, key=lambda p: int(p.stem.split("_")[1]))
        connection = None
        try:
            connection = sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True)
            row = connection.execute(
                "SELECT model, reasoning_effort FROM threads WHERE id = ?", (session_id,)
            ).fetchone()
            if row:
                values = {"codexModel": row[0], "effort": row[1]}
        except sqlite3.Error:
            pass
        finally:
            if connection is not None:
                connection.close()
    if not all(values.get(key) for key in ("codexModel", "effort")):
        # 구형 CLI는 세션 설정을 DB 대신 rollout의 turn_context에만 남긴다.
        rollouts = list((home / "sessions").glob(f"**/*-{session_id}.jsonl"))
        if len(rollouts) > 1:
            raise ValueError("현재 세션의 rollout이 여러 개라 상속할 설정을 확정할 수 없습니다.")
        if rollouts:
            with rollouts[0].open() as stream:
                for line in stream:
                    try:
                        record = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if record.get("type") == "turn_context":
                        payload = record["payload"]
                        values = {"codexModel": payload.get("model"), "effort": payload.get("effort")}
    return session_id, values


def resolve(args):
    settings = json.loads((Path(__file__).resolve().parents[1] / "settings.json").read_text())
    overrides = {"codexModel": args.codex_model, "effort": args.effort}
    result = {}
    sources = {}
    for key, override in overrides.items():
        result[key] = override if override is not None else settings.get(key, "inherit")
        sources[key] = "argument" if override is not None else "settings"
    if "inherit" in result.values():
        session_id, inherited = current_session()
        for key in result:
            if result[key] == "inherit":
                result[key] = inherited.get(key)
                sources[key] = "session"
        result["sessionId"] = session_id
    for key in ("codexModel", "effort"):
        if not isinstance(result[key], str) or not result[key] or any(c.isspace() for c in result[key]):
            raise ValueError(f"현재 세션의 {key}를 확인할 수 없습니다. 해당 옵션을 명시하세요.")
    if result["effort"] not in {"low", "medium", "high", "xhigh", "max"}:
        raise ValueError(
            f"effort={result['effort']}는 두 엔진 공통 리뷰에서 지원하지 않습니다. "
            "자동으로 낮추지 않으므로 지원되는 effort를 명시하세요."
        )
    result["sources"] = sources
    return result


def main():
    parser = argparse.ArgumentParser(description="호출한 Codex 세션의 모델·effort를 리뷰에 상속한다.")
    parser.add_argument("--codex-model")
    parser.add_argument("--effort")
    args = parser.parse_args()
    try:
        print(json.dumps(resolve(args), ensure_ascii=False))
    except (ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        return 64
    return 0


if __name__ == "__main__":
    sys.exit(main())
