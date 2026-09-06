import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ADAPTERS = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('criteria', ADAPTERS / 'criteria.py')
criteria = importlib.util.module_from_spec(spec)
spec.loader.exec_module(criteria)


class ParserTests(unittest.TestCase):
    def raw(self, body, updated='v1'):
        return {'number': 'TST-1', 'updatedAt': updated, 'body': body}

    def changes(self, raw, statuses):
        return [dict(item, checked=value) for item, value in zip(criteria.snapshot(raw)['items'], statuses)]

    def test_legacy_bullets_multiline_fences_and_other_sections(self):
        body = ('## 목표\r\n원문 보존\r\n\r\n```md\r\n## 완료 조건\r\n- [x] 가짜\r\n```\r\n'
                '## Acceptance criteria\r\n* 이름을 바꿀 수 있다.\r\n  다시 열어도 유지된다.\r\n'
                '* [X] 실패 안내가 보인다.\r\n\r\n## 메모\r\n- [ ] 다른 체크\r\n')
        raw = self.raw(body)
        snapshot = criteria.snapshot(raw)
        self.assertEqual(len(snapshot['items']), 2)
        self.assertIn('다시 열어도', snapshot['items'][0]['text'])
        prepared = criteria.prepare(snapshot, self.changes(raw, [True, False]), raw)
        expected = body.replace('* 이름을', '* [x] 이름을').replace('* [X] 실패', '* [ ] 실패')
        self.assertEqual(prepared['body'], expected)
        self.assertTrue(criteria.verify(prepared, self.raw(expected, 'v2'))['items'][0]['checked'])

    def test_korean_aliases_and_custom_heading_level(self):
        for heading in ['완료 조건', '검수 기준', 'ACCEPTANCE CRITERIA']:
            raw = self.raw(f'### {heading}\n+ [ ] 결과\n### 다른 절\n- 다른 항목\n')
            self.assertEqual(criteria.snapshot(raw)['items'], [{'index': 1, 'text': '결과', 'checked': False}])

    def test_no_section_is_explicit_and_cannot_write(self):
        raw = self.raw('## 목표\n- [ ] 할 일\n')
        snapshot = criteria.snapshot(raw)
        self.assertIsNone(snapshot['section'])
        self.assertEqual(snapshot['items'], [])
        with self.assertRaises(ValueError):
            criteria.prepare(snapshot, [], raw)

    def test_empty_section_is_not_a_pass(self):
        raw = self.raw('## 완료 조건\n아직 작성 전\n')
        self.assertEqual(criteria.snapshot(raw)['items'], [])
        with self.assertRaises(ValueError):
            criteria.prepare(criteria.snapshot(raw), [], raw)

    def test_ambiguous_sections_and_nested_checks_are_refused(self):
        for body in ['## 완료 조건\n- a\n## Acceptance criteria\n- b\n',
                     '## 완료 조건\n- [ ] 부모\n  - [ ] 자식\n']:
            with self.assertRaises(ValueError):
                criteria.snapshot(self.raw(body))

    def test_stale_body_even_if_timestamp_did_not_change(self):
        old = self.raw('## 완료 조건\n- [ ] 원문\n')
        new = self.raw('## 완료 조건\n- [ ] 새 문구\n')
        with self.assertRaises(ValueError):
            criteria.prepare(criteria.snapshot(old), self.changes(old, [True]), new)

    def test_stale_version_even_if_body_did_not_change(self):
        raw = self.raw('## 완료 조건\n- [ ] 원문\n')
        with self.assertRaises(ValueError):
            criteria.guard(criteria.snapshot(raw), dict(raw, updatedAt='v2'))

    def test_wrong_issue_and_wrong_text_are_refused(self):
        raw = self.raw('## 완료 조건\n- [ ] 원문\n')
        with self.assertRaises(ValueError):
            criteria.guard(criteria.snapshot(raw), dict(raw, number='TST-2'))
        checks = self.changes(raw, [True])
        checks[0]['text'] = '다른 조건'
        with self.assertRaises(ValueError):
            criteria.prepare(criteria.snapshot(raw), checks, raw)

    def test_every_condition_must_have_exactly_one_boolean_result(self):
        raw = self.raw('## 완료 조건\n- [ ] 첫째\n- [ ] 둘째\n')
        valid = self.changes(raw, [True, False])
        invalid = [valid[:1], [valid[0], valid[0]], [dict(valid[0], index=True), valid[1]],
                   [dict(valid[0], checked='true'), valid[1]], [dict(valid[0], extra=1), valid[1]]]
        for checks in invalid:
            with self.subTest(checks=checks), self.assertRaises(ValueError):
                criteria.prepare(criteria.snapshot(raw), checks, raw)

    def test_noop_preserves_uppercase_checkbox_and_whitespace(self):
        raw = self.raw('## 완료 조건\n- [X]  완료\n\n')
        prepared = criteria.prepare(criteria.snapshot(raw), self.changes(raw, [True]), raw)
        self.assertFalse(prepared['changed'])
        self.assertEqual(prepared['body'], raw['body'])

    def test_readback_requires_entire_body_preserved(self):
        raw = self.raw('## 목표\n보존\n## 완료 조건\n- [ ] 결과\n')
        prepared = criteria.prepare(criteria.snapshot(raw), self.changes(raw, [True]), raw)
        for body in [prepared['body'].replace('보존', '유실'), prepared['body'].replace('- [x]', '* [x]')]:
            with self.assertRaises(ValueError):
                criteria.verify(prepared, self.raw(body, 'v2'))


MOCK = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
p=Path(os.environ['CRITERIA_MOCK_STATE'])
s=json.loads(p.read_text())
args=sys.argv[1:]
name=Path(sys.argv[0]).name
if name == 'gh':
    if args[:2] == ['issue','view']:
        action='read'
    elif args[:2] == ['issue','edit'] and '--body-file' in args:
        action='write'
        body=Path(args[args.index('--body-file')+1]).read_text()
    else:
        raise SystemExit('unexpected gh command: '+str(args))
else:
    payload=json.loads(args[args.index('--data')+1])
    query=payload['query']
    if query.startswith('query') and 'description' in query:
        action='read'
    elif query.startswith('mutation') and 'issueUpdate' in query:
        action='write'
        body=payload['variables']['i']['description']
    else:
        raise SystemExit('unexpected GraphQL query')
if action=='read':
    s['reads']+=1
    if s.get('race_at')==s['reads']:
        s['body']+='\n사람이 쓴 메모\n'
        s['updatedAt']='human-edit'
    if name=='gh':
        result={'number':1,'body':s['body'],'updatedAt':s['updatedAt']}
    else:
        result={'data':{'issue':{'id':'uuid-1','identifier':'TST-1','description':s['body'],'updatedAt':s['updatedAt']}}}
else:
    s['writes']+=1
    if s.get('write_failure'):
        p.write_text(json.dumps(s))
        if name=='gh': raise SystemExit(1)
        print(json.dumps({'data':{'issueUpdate':{'success':False}}}))
        raise SystemExit(0)
    s['body']=body.replace('- [x]', '* [x]') if s.get('normalize') else body
    s['updatedAt']='v'+str(s['writes']+1)
    result={} if name=='gh' else {'data':{'issueUpdate':{'success':True}}}
p.write_text(json.dumps(s))
print(json.dumps(result))
'''


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='criteria-tests-')
        self.root = Path(self.directory.name)
        self.addCleanup(self.directory.cleanup)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        config = self.root / '.claude/agent-loop'
        config.mkdir(parents=True)
        (config / 'config').write_text('LINEAR_TEAM_KEY=TST\n')
        bindir = self.root / 'bin'
        bindir.mkdir()
        for name in ['gh', 'curl']:
            script = bindir / name
            script.write_text(MOCK)
            script.chmod(0o755)
        self.state = self.root / 'state.json'
        self.env = dict(os.environ, PATH=str(bindir)+os.pathsep+os.environ['PATH'],
                        CRITERIA_MOCK_STATE=str(self.state), LINEAR_API_KEY='offline-test-only')
        for key in ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE']:
            self.env.pop(key, None)

    def reset(self, **extra):
        state = {'body': '## 목표\n원문\n\n## 완료 조건\n- [ ] 첫째\n- [x] 둘째\n',
                 'updatedAt': 'v1', 'reads': 0, 'writes': 0}
        state.update(extra)
        self.state.write_text(json.dumps(state))

    def call(self, platform, verb, *args):
        return subprocess.run(['bash', str(ADAPTERS / platform / 'tracker.sh'), verb,
                               '1' if platform == 'github' else 'TST-1', *map(str, args)],
                              cwd=self.root, env=self.env, capture_output=True, text=True)

    def files(self, platform, statuses=(True, False)):
        result = self.call(platform, 'criteria')
        self.assertEqual(result.returncode, 0, result.stderr)
        snapshot = json.loads(result.stdout)
        snapshot_file = self.root / 'snapshot.json'
        snapshot_file.write_text(json.dumps(snapshot))
        checks_file = self.root / 'checks.json'
        checks_file.write_text(json.dumps([dict(item, checked=value)
                                          for item, value in zip(snapshot['items'], statuses)]))
        return snapshot_file, checks_file

    def test_both_adapters_change_only_selected_checks_and_repeated_read_is_noop(self):
        for platform in ['github', 'linear']:
            with self.subTest(platform=platform):
                self.reset()
                files = self.files(platform)
                result = self.call(platform, 'check', *files)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(json.loads(result.stdout)['changed'])
                saved = json.loads(self.state.read_text())
                self.assertEqual(saved['writes'], 1)
                self.assertEqual(saved['body'], '## 목표\n원문\n\n## 완료 조건\n- [x] 첫째\n- [ ] 둘째\n')
                files = self.files(platform)
                result = self.call(platform, 'check', *files)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(json.loads(result.stdout)['changed'])
                self.assertEqual(json.loads(self.state.read_text())['writes'], 1)

    def test_second_read_race_prevents_either_adapter_from_writing(self):
        for platform in ['github', 'linear']:
            with self.subTest(platform=platform):
                self.reset(race_at=3)
                result = self.call(platform, 'check', *self.files(platform))
                self.assertNotEqual(result.returncode, 0)
                state = json.loads(self.state.read_text())
                self.assertEqual(state['writes'], 0)
                self.assertIn('사람이 쓴 메모', state['body'])

    def test_failed_mutation_is_not_reported_as_success(self):
        for platform in ['github', 'linear']:
            with self.subTest(platform=platform):
                self.reset(write_failure=True)
                result = self.call(platform, 'check', *self.files(platform))
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertEqual(json.loads(self.state.read_text())['writes'], 1)

    def test_normalization_mismatch_fails_without_a_retry(self):
        for platform in ['github', 'linear']:
            with self.subTest(platform=platform):
                self.reset(normalize=True)
                result = self.call(platform, 'check', *self.files(platform))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('saved body differs', result.stderr)
                self.assertEqual(json.loads(self.state.read_text())['writes'], 1)


if __name__ == '__main__':
    unittest.main()
