import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SKILLS = Path(__file__).resolve().parents[2]
LOOP = SKILLS / "agent-loop"


class HelpersTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="agent-loop-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.env = os.environ.copy()
        self.env.update(
            GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1", GIT_ALLOW_PROTOCOL="file",
            GIT_AUTHOR_NAME="Fixture", GIT_AUTHOR_EMAIL="fixture@example.invalid",
            GIT_COMMITTER_NAME="Fixture", GIT_COMMITTER_EMAIL="fixture@example.invalid",
        )
        self.git("init", "-q")
        self.write_config("INSTALL_CMD=\n")
        self.a = self.commit("base\n")
        self.v = self.commit("verified\n", [self.a])
        self.b = self.commit("new base\n", [self.a])
        self.m = self.commit("integrated\n", [self.v, self.b])
        self.checkout(self.v)
        self.git("remote", "add", "origin", str(self.repo))
        self.bin = self.root / "bin"
        self.bin.mkdir()
        gh = self.bin / "gh"
        gh.write_text('#!/bin/sh\ncat "$TEST_PR_JSON"\n')
        gh.chmod(0o755)
        self.env["PATH"] = str(self.bin) + os.pathsep + self.env["PATH"]
        self.env["TEST_PR_JSON"] = str(self.root / "pr.json")

    def write_config(self, text, repo=None):
        cfg = (repo or self.repo) / ".claude/agent-loop/config"
        cfg.parent.mkdir(parents=True, exist_ok=True)
        cfg.write_text(text)

    def git(self, *args, input=None):
        return subprocess.run(["git", "-C", str(self.repo), *args], input=input,
                              text=True, capture_output=True, check=True, env=self.env).stdout.strip()

    def commit(self, content, parents=()):
        blob = self.git("hash-object", "-w", "--stdin", input=content)
        ignore = self.git("hash-object", "-w", "--stdin", input=".e2e/\n.claude/\n")
        tree = self.git("mktree", input=f"100644 blob {ignore}\t.gitignore\n100644 blob {blob}\tvalue.txt\n")
        args = ["commit-tree", tree]
        for parent in parents:
            args += ["-p", parent]
        return self.git(*args, input="fixture\n")

    def checkout(self, commit):
        self.git("update-ref", "refs/heads/pr", commit)
        self.git("symbolic-ref", "HEAD", "refs/heads/pr")
        self.git("read-tree", "--reset", "-u", commit)

    def script(self, path, *args, cwd=None):
        return subprocess.run(["bash", str(path), *map(str, args)], cwd=cwd or self.repo,
                              text=True, capture_output=True, env=self.env)

    def record(self, record=None, head=None, body=None):
        record = record or self.v
        head = head or self.v
        if body is None:
            body = f"## 완료 조건 검증\n\n검증 대상: [{record}](https://github.com/o/r/commit/{record}) · 환경: test\n"
        Path(self.env["TEST_PR_JSON"]).write_text(json.dumps({
            "body": body, "headRefOid": head, "headRefName": "pr",
        }))
        return self.script(LOOP / "scripts/verified-head.sh", "1", self.repo)

    def test_same_head_is_current(self):
        result = self.record()
        self.assertEqual((result.returncode, result.stdout.strip()), (0, "current " + self.v))

    def test_short_sha_resolves_to_full_head(self):
        result = self.record(body=f"## 완료 조건 검증\n검증 대상: `{self.v[:8]}` · 환경: 20260914\n")
        self.assertEqual((result.returncode, result.stdout.strip()), (0, "current " + self.v))

    def test_rollback_merge_and_divergence_are_stale(self):
        for head in [self.a, self.b, self.m]:
            with self.subTest(head=head):
                result = self.record(head=head)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertTrue(result.stdout.startswith("stale " + self.v + " "))
                self.assertGreater(int(result.stdout.split()[-1]), 0)

    def test_same_tree_new_commit_is_stale(self):
        head = self.commit("verified\n", [self.v])
        self.assertEqual(self.record(head=head).returncode, 1)

    def test_outside_target_is_not_used(self):
        result = self.record(body=f"검증 대상: {self.v}\n## 완료 조건 검증\n미실행\n## Notes\n검증 대상: {self.v}\n")
        self.assertEqual(result.returncode, 2)

    def test_duplicate_section_or_target_is_missing(self):
        section = f"## 완료 조건 검증\n검증 대상: {self.v}\n"
        for body in [section + section, section + f"검증 대상: {self.a}\n"]:
            self.assertEqual(self.record(body=body).returncode, 2)

    def test_link_label_mismatch_is_missing(self):
        body = f"## 완료 조건 검증\n검증 대상: [{self.a}](https://github.com/o/r/commit/{self.v})\n"
        self.assertEqual(self.record(body=body).returncode, 2)

    def test_unknown_commit_is_missing(self):
        self.assertEqual(self.record(record="f" * 40).returncode, 2)

    def test_dirty_or_untracked_source_is_preserved(self):
        for filename in ["value.txt", "new-file.txt"]:
            p = self.repo / filename
            p.write_text("user changes\n")
            result = self.script(LOOP / "scripts/check-worktree.sh", self.repo, self.v)
            self.assertEqual(result.returncode, 3)
            self.assertEqual(p.read_text(), "user changes\n")
            if filename == "value.txt":
                p.write_text("verified\n")
            else:
                p.unlink()

    def test_ignored_artifacts_do_not_change_target(self):
        artifacts = self.repo / ".e2e"
        artifacts.mkdir()
        (artifacts / "result.json").write_text("{}")
        self.assertEqual(self.script(LOOP / "scripts/check-worktree.sh", self.repo, self.v).returncode, 0)

    def test_hollow_worktree_and_wrong_head_are_rejected(self):
        hollow = self.repo / ".claude/worktrees/hollow"
        hollow.mkdir(parents=True)
        self.assertEqual(self.script(LOOP / "scripts/check-worktree.sh", hollow).returncode, 3)
        self.assertEqual(self.script(LOOP / "scripts/check-worktree.sh", self.repo, self.a).returncode, 4)

    def test_slug_rejected_before_worktree_creation(self):
        result = self.script(SKILLS / "implement/scripts/prepare-worktree.sh", "12", "한글")
        self.assertEqual(result.returncode, 64)
        self.assertFalse((self.repo / ".claude/worktrees").exists())

    def test_prepare_does_not_install_over_another_branch(self):
        worktree = self.repo / ".claude/worktrees/issue-12-good"
        self.git("worktree", "add", "-b", "another-task", str(worktree), self.v)
        result = self.script(SKILLS / "implement/scripts/prepare-worktree.sh", "12", "good")
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertEqual((worktree / "value.txt").read_text(), "verified\n")

    def test_prepare_creates_an_isolated_worktree(self):
        generated = self.repo / "apps/web/src/routeTree.gen.ts"
        generated.parent.mkdir(parents=True)
        generated.write_text("generated\n")
        self.write_config('INSTALL_CMD="touch installed-here"\nCOPY_FROM_MAIN="apps/*/src/routeTree.gen.ts"\n')
        result = self.script(SKILLS / "implement/scripts/prepare-worktree.sh", "12", "good", "pr")
        self.assertEqual(result.returncode, 0, result.stderr)
        worktree = self.repo / ".claude/worktrees/issue-12-good"
        self.assertEqual((worktree / "value.txt").read_text(), "verified\n")
        self.assertTrue((worktree / "installed-here").exists())
        self.assertEqual((worktree / "apps/web/src/routeTree.gen.ts").read_text(), "generated\n")
        self.assertIn("generated files copied: 1", result.stdout)
        branch = subprocess.check_output(["git", "-C", str(worktree), "branch", "--show-current"], text=True, env=self.env).strip()
        self.assertEqual(branch, "agent/issue-12-good")

    def test_prepare_without_config_creates_nothing(self):
        (self.repo / ".claude/agent-loop/config").unlink()
        result = self.script(SKILLS / "implement/scripts/prepare-worktree.sh", "12", "good", "pr")
        self.assertEqual(result.returncode, 78, result.stderr)
        self.assertIn("config.example", result.stderr)
        self.assertFalse((self.repo / ".claude/worktrees").exists())

    def test_prepare_skips_install_when_command_is_empty(self):
        self.write_config("COPY_FROM_MAIN=\n")
        result = self.script(SKILLS / "implement/scripts/prepare-worktree.sh", "12", "good", "pr")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("INSTALL_CMD is empty", result.stderr)
        self.assertNotIn("WARN", result.stderr)

    def test_worktree_without_config_falls_back_to_main_checkout(self):
        worktree = self.repo / ".claude/worktrees/issue-12-good"
        self.git("worktree", "add", "-b", "agent/issue-12-good", str(worktree), self.v)
        self.write_config('INSTALL_CMD="from-main"\n')
        loader = LOOP / "scripts/load-config.sh"
        result = subprocess.run(["bash", "-c", f'. "{loader}" && agent_loop_load_config . && printf %s "$INSTALL_CMD"'],
                                cwd=worktree, text=True, capture_output=True, env=self.env)
        self.assertEqual((result.returncode, result.stdout), (0, "from-main"), result.stderr)


if __name__ == "__main__":
    unittest.main()
