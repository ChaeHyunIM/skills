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
        ps = self.bin / "ps"
        ps.write_text('#!/bin/sh\n[ "$2" = "${TEST_OWNED_PID:-none}" ] || exit 1\nprintf "fixture-start\\n"\n')
        ps.chmod(0o755)
        self.env["PATH"] = str(self.bin) + os.pathsep + self.env["PATH"]
        self.env["TEST_PR_JSON"] = str(self.root / "pr.json")

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
        return self.script(SKILLS / "verify/scripts/verified-head.sh", "1", self.repo)

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

    def test_sync_fast_forwards_and_preserves_local_only_commit(self):
        clone = self.root / "clone"
        subprocess.run(["git", "clone", "-q", str(self.repo), str(clone)], check=True, env=self.env)
        self.checkout(self.m)
        result = self.script(LOOP / "scripts/sync-worktree.sh", clone, "pr")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((clone / "value.txt").read_text(), "integrated\n")
        self.checkout(self.v)
        result = self.script(LOOP / "scripts/sync-worktree.sh", clone, "pr")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((clone / "value.txt").read_text(), "integrated\n")

    def test_sync_rejects_dirty_and_wrong_branch(self):
        (self.repo / "value.txt").write_text("keep me\n")
        result = self.script(LOOP / "scripts/sync-worktree.sh", self.repo, "pr")
        self.assertEqual(result.returncode, 3)
        self.assertEqual((self.repo / "value.txt").read_text(), "keep me\n")
        (self.repo / "value.txt").write_text("verified\n")
        self.assertNotEqual(self.script(LOOP / "scripts/sync-worktree.sh", self.repo, "other").returncode, 0)

    def test_slug_rejected_before_worktree_creation(self):
        result = self.script(SKILLS / "implement/scripts/prepare-worktree.sh", "12", "한글")
        self.assertEqual(result.returncode, 64)
        self.assertFalse((self.repo / ".claude").exists())

    def test_prepare_does_not_install_over_another_branch(self):
        worktree = self.repo / ".claude/worktrees/issue-12-good"
        self.git("worktree", "add", "-b", "another-task", str(worktree), self.v)
        result = self.script(SKILLS / "implement/scripts/prepare-worktree.sh", "12", "good")
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertEqual((worktree / "value.txt").read_text(), "verified\n")

    def test_prepare_creates_an_isolated_worktree(self):
        pnpm = self.bin / "pnpm"
        pnpm.write_text("#!/bin/sh\nexit 0\n")
        pnpm.chmod(0o755)
        result = self.script(SKILLS / "implement/scripts/prepare-worktree.sh", "12", "good", "pr")
        self.assertEqual(result.returncode, 0, result.stderr)
        worktree = self.repo / ".claude/worktrees/issue-12-good"
        self.assertEqual((worktree / "value.txt").read_text(), "verified\n")
        branch = subprocess.check_output(["git", "-C", str(worktree), "branch", "--show-current"], text=True, env=self.env).strip()
        self.assertEqual(branch, "agent/issue-12-good")

    def test_remove_only_named_clean_base_worktree(self):
        one = self.repo / ".claude/worktrees/verify-base-one"
        two = self.repo / ".claude/worktrees/verify-base-two"
        self.git("worktree", "add", "--detach", str(one), self.a)
        self.git("worktree", "add", "--detach", str(two), self.b)
        helper = SKILLS / "verify/scripts/base-worktree.sh"
        self.assertNotEqual(self.script(helper, "--remove").returncode, 0)
        (one / "value.txt").write_text("user work\n")
        self.assertNotEqual(self.script(helper, "--remove", one).returncode, 0)
        self.assertEqual((one / "value.txt").read_text(), "user work\n")
        (one / "value.txt").write_text("base\n")
        result = self.script(helper, "--remove", one)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(one.exists())
        self.assertTrue(two.exists())

    def test_server_stop_preserves_unknown_process(self):
        process = subprocess.Popen(["sleep", "30"])
        def cleanup():
            if process.poll() is None:
                process.terminate()
            process.wait()
        self.addCleanup(cleanup)
        state = self.repo / ".e2e/servers/head"
        state.mkdir(parents=True)
        (state / "api.pid").write_text(str(process.pid))
        (state / "api.started").write_text("not this process")
        result = self.script(SKILLS / "verify/scripts/dev-servers.sh", "stop", "head")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIsNone(process.poll())

    def test_server_stop_terminates_owned_process(self):
        process = subprocess.Popen(["sleep", "30"])
        def cleanup():
            if process.poll() is None:
                process.terminate()
            process.wait()
        self.addCleanup(cleanup)
        state = self.repo / ".e2e/servers/head"
        state.mkdir(parents=True)
        (state / "api.pid").write_text(str(process.pid))
        self.env["TEST_OWNED_PID"] = str(process.pid)
        (state / "api.started").write_text("fixture-start\n")
        result = self.script(SKILLS / "verify/scripts/dev-servers.sh", "stop", "head")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(process.wait(timeout=2), -15)


if __name__ == "__main__":
    unittest.main()
