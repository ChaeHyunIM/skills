---
name: site-hub
description: YOURKASE 사내 HTML 페이지를 만들고 hub.yourkase.com에 게시하거나 같은 URL에서 수정할 때 사용한다. Claude Code와 Codex에서 URL 확인, 기존 페이지 교체 승인, 서비스 토큰 인증, 업로드를 처리한다.
---

# 사내 사이트 게시

결과물은 회사 계정으로 열 수 있는 허브 URL 하나다. 로컬 HTML은 업로드 원본으로만 사용하고, claude.ai Artifact 등 별도의 게시본을 만들지 않는다.

## 만들기와 주소 확인

1. 페이지는 UTF-8 단독 `.html` 파일, 최대 16 MiB다. CSS·폰트·필요 자산을 파일에 포함한다. 게시 페이지는 sandbox로 실행되어 허브 API, 인증 쿠키, 동일 출처 저장소를 사용할 수 없다. 외부 네트워크 접근이 반드시 필요한 페이지는 동작과 데이터 전송 범위를 먼저 확인한다.
2. 사용자가 URL을 지정했다면 그대로 사용한다. `https://hub.yourkase.com/reports/example` 또는 `/reports/example` 형식이다. 소문자 영문·숫자·하이픈과 경로 구분 `/`만 허용한다. 지정한 URL이 유효하지 않으면 이유를 알리고 수정안을 확인받는다. 주소를 조용히 변경하지 않는다.
3. URL이 없으면 내용을 반영한 주소 하나를 제안하고 사용자 확인을 받은 뒤 게시한다. 기존 페이지 수정은 원래 URL을 유지한다.

## 확인 후 게시

이 스킬 폴더의 `scripts/hub.py`를 Python 3로 실행한다. 아래 `SKILL_DIR`은 실제 스킬 디렉터리로 치환한다. 경로·제목은 셸 인자로 안전하게 인용한다.

```sh
python3 "$SKILL_DIR/scripts/hub.py" check --path /reports/example
python3 "$SKILL_DIR/scripts/hub.py" publish --path /reports/example --file /absolute/path/page.html --title '보고서'
```

- `check` 결과가 `exists: false`면 사용자에게 확인받은 URL로 새로 게시한다.
- `exists: true`면 기존 URL과 교체할 내용을 짧게 제시하고 **명시적인 교체 승인**을 받는다. 이미 대화에서 해당 URL 교체가 승인되었다면 반복해서 묻지 않는다. 승인 전에는 `--replace-etag`를 사용하지 않는다.
- 승인을 받은 버전의 `check` 결과 `etag`를 아래 명령에 넣는다. 게시 직전 파일이 바뀌면 도구가 중단한다. 충돌 시 새 ETag로 자동 재시도하지 말고 다시 확인·승인받는다.

```sh
python3 "$SKILL_DIR/scripts/hub.py" publish --path /reports/example --file /absolute/path/page.html --title '보고서' --replace-etag APPROVED_ETAG
```

종료 코드 0일 때만 출력된 URL을 게시 완료로 안내한다. 종료 코드 3은 교체 승인 또는 변경된 버전 확인이 필요하다. 나머지는 오류 메시지를 간단히 전달하고 성공했다고 말하지 않는다. 연결이 끊기면 저장됐을 수도 있으므로 `check`로 먼저 상태를 확인한다. 업로드 성공과 실제 회사 계정 열람 확인은 구분해서 보고한다.

## 인증

도구가 `~/.config/yourkase-site-hub/credentials.json`의 `client_id`, `client_secret`을 내부에서 읽는다. 파일 권한은 `600`, 디렉터리는 `700`이어야 한다. 사용자별 서비스 토큰은 허브 관리자가 발급·설치한다. 자격 증명을 스킬이나 저장소에 넣지 않는다.

인증 파일을 읽어 대화에 표시하거나 `cat`, 디버그 출력, `curl -v`, 명령행 토큰 인자, 요청 헤더 로깅을 사용하지 않는다. 토큰을 채팅으로 요청하지 않는다. 인증이 없거나 만료되었으면 관리자에게 로컬 보안 파일 설치·갱신이 필요하다고 안내한다. 브라우저 세션 쿠키 추출이나 Access 우회로 대체하지 않는다.

서비스 토큰은 `/_agent/sites`의 상태 확인·게시만 가능하다. 회사 계정용 목록·보관·페이지 열람 권한은 없다. 업로더는 `site-hub-agent@yourkase.com`이라는 서비스 표시명으로 기록된다.
