import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest


LOOP = Path(__file__).resolve().parents[1]
FIRST = "11111111-1111-4111-8111-111111111111"
SECOND = "22222222-2222-4222-8222-222222222222"


class ReviewSettingsTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="review-settings-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.home = self.root / "codex"
        self.home.mkdir()
        self.runtime = self.root / "review-round"
        shutil.copytree(LOOP / "review-round", self.runtime)
        self.env = os.environ.copy()
        for key in ("CODEX_THREAD_ID", "CODEX_SESSION_ID", "CODEX_API_KEY", "OPENAI_API_KEY"):
            self.env.pop(key, None)
        self.env.update(CODEX_HOME=str(self.home), CODEX_THREAD_ID=FIRST)

    def database(self):
        with sqlite3.connect(self.home / "state_5.sqlite") as db:
            db.execute("CREATE TABLE threads (id TEXT PRIMARY KEY, model TEXT, reasoning_effort TEXT)")
            db.executemany("INSERT INTO threads VALUES (?, ?, ?)", [
                (FIRST, "model-first", "high"), (SECOND, "model-second", "low")
            ])

    def run_resolver(self, *args):
        return subprocess.run(
            [sys.executable, str(self.runtime / "scripts/resolve-settings.py"), *args],
            env=self.env, text=True, capture_output=True,
        )

    def resolve(self, *args):
        result = self.run_resolver(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_each_calling_session_inherits_its_own_settings(self):
        self.database()
        first = self.resolve()
        self.env["CODEX_THREAD_ID"] = SECOND
        second = self.resolve()
        self.assertEqual((first["codexModel"], first["effort"]), ("model-first", "high"))
        self.assertEqual((second["codexModel"], second["effort"]), ("model-second", "low"))
        self.assertEqual(second["sources"], {"codexModel": "session", "effort": "session"})

    def test_same_session_reads_changes_on_next_invocation(self):
        self.database()
        self.resolve()
        with sqlite3.connect(self.home / "state_5.sqlite") as db:
            db.execute("UPDATE threads SET model = ?, reasoning_effort = ? WHERE id = ?",
                       ("model-changed", "max", FIRST))
        result = self.resolve()
        self.assertEqual((result["codexModel"], result["effort"]), ("model-changed", "max"))

    def test_explicit_model_keeps_inherited_effort(self):
        self.database()
        result = self.resolve("--codex-model", "model-requested")
        self.assertEqual((result["codexModel"], result["effort"]), ("model-requested", "high"))

    def test_explicit_effort_keeps_inherited_model(self):
        self.database()
        result = self.resolve("--effort", "xhigh")
        self.assertEqual((result["codexModel"], result["effort"]), ("model-first", "xhigh"))

    def test_explicit_pair_does_not_require_a_codex_session(self):
        self.env.pop("CODEX_THREAD_ID")
        result = self.resolve("--codex-model", "model-requested", "--effort", "low")
        self.assertEqual(result["sources"], {"codexModel": "argument", "effort": "argument"})
        self.assertNotIn("sessionId", result)

    def test_configured_value_overrides_inheritance_but_not_arguments(self):
        self.database()
        (self.runtime / "settings.json").write_text(json.dumps({"codexModel": "model-configured", "effort": "inherit"}))
        result = self.resolve()
        self.assertEqual((result["codexModel"], result["effort"]), ("model-configured", "high"))
        self.assertEqual(self.resolve("--codex-model", "model-requested")["codexModel"], "model-requested")

    def test_missing_session_does_not_use_global_defaults(self):
        self.env.pop("CODEX_THREAD_ID")
        (self.home / "config.toml").write_text('model = "global-model"\nmodel_reasoning_effort = "low"\n')
        result = self.run_resolver()
        self.assertEqual(result.returncode, 64)
        self.assertEqual(result.stdout, "")

    def test_unknown_session_does_not_use_another_thread(self):
        self.database()
        self.env["CODEX_THREAD_ID"] = "33333333-3333-4333-8333-333333333333"
        self.assertEqual(self.run_resolver().returncode, 64)

    def test_legacy_session_uses_last_turn_context(self):
        self.env.pop("CODEX_THREAD_ID")
        self.env["CODEX_SESSION_ID"] = FIRST
        sessions = self.home / "sessions/2026/09/14"
        sessions.mkdir(parents=True)
        records = [
            {"type": "turn_context", "payload": {"model": "old-model", "effort": "low"}},
            {"type": "turn_context", "payload": {"model": "new-model", "effort": "xhigh"}},
        ]
        (sessions / f"rollout-date-{FIRST}.jsonl").write_text("\n".join(map(json.dumps, records)) + "\n")
        result = self.resolve()
        self.assertEqual((result["codexModel"], result["effort"]), ("new-model", "xhigh"))

    def test_unsupported_effort_is_not_silently_downgraded(self):
        result = self.run_resolver("--codex-model", "model-requested", "--effort", "ultra")
        self.assertEqual(result.returncode, 64)
        self.assertIn("ultra", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_preflight_checks_refreshed_catalog_without_starting_review(self):
        binary = self.root / "bin"
        binary.mkdir()
        fake = binary / "codex"
        fake.write_text('''#!/usr/bin/env python3
import json, sys
args = sys.argv[1:]
if args == ["login", "status"]:
    print("Logged in using ChatGPT")
elif args == ["debug", "models"]:
    print(json.dumps({"models": [{"slug": "new-model", "supported_reasoning_levels": [{"effort": "xhigh"}]}]}))
elif args == ["debug", "models", "--bundled"]:
    print('{"models": []}')
else:
    sys.exit(99)
''')
        fake.chmod(0o755)
        self.env["PATH"] = str(binary) + os.pathsep + self.env["PATH"]
        helper = self.runtime / "scripts/codex-review.sh"
        result = subprocess.run(["bash", str(helper), "preflight", "new-model", "xhigh"],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        unsupported = subprocess.run(["bash", str(helper), "preflight", "new-model", "max"],
                                     env=self.env, text=True, capture_output=True)
        self.assertEqual(unsupported.returncode, 64)
        unlisted = subprocess.run(["bash", str(helper), "preflight", "app-only-model", "xhigh"],
                                  env=self.env, text=True, capture_output=True)
        self.assertEqual(unlisted.returncode, 0, unlisted.stderr)
        self.assertIn("app-only-model", unlisted.stderr)



if __name__ == "__main__":
    unittest.main()
