#!/usr/bin/env python3
"""YOURKASE 허브에 HTML을 게시합니다."""
import argparse
import json
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

ORIGIN = 'https://hub.yourkase.com'
LIMIT = 16 * 1024 * 1024


class HubError(Exception):
    def __init__(self, message, code=1):
        super().__init__(message)
        self.code = code


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def credentials():
    try:
        path = Path.home() / '.config/yourkase-site-hub/credentials.json'
        if path.stat().st_mode & 0o077:
            raise HubError('인증 파일 권한을 600으로 설정해 주세요.')
        data = json.loads(path.read_text())
        if not all(isinstance(data.get(k), str) and data[k] and '\n' not in data[k] and '\r' not in data[k]
                   for k in ('client_id', 'client_secret')):
            raise ValueError()
        return data
    except HubError:
        raise
    except (OSError, ValueError, TypeError, AttributeError):
        raise HubError('서비스 토큰 설정이 없거나 잘못되었습니다. 허브 관리자에게 설정을 요청하세요.') from None


def site_path(value):
    if value.startswith(ORIGIN + '/'):
        value = value[len(ORIGIN):]
    if len(value) > 240 or not re.fullmatch(r'/[a-z0-9]+(?:-[a-z0-9]+)*(?:/[a-z0-9]+(?:-[a-z0-9]+)*)*', value) or value.split('/')[1] == 'cdn-cgi':
        raise HubError('허브 URL 또는 /reports/example 형태의 경로를 지정해 주세요.')
    return value


def call_api(path, auth, body=None, content_type=None):
    headers = {'CF-Access-Client-ID': auth['client_id'], 'CF-Access-Client-Secret': auth['client_secret'], 'Accept': 'application/json', 'User-Agent': 'YOURKASE-Site-Hub/1.0'}
    if content_type:
        headers['Content-Type'] = content_type
    req = urllib.request.Request(ORIGIN + '/_agent/sites' + path, data=body, headers=headers)
    try:
        with urllib.request.build_opener(NoRedirect()).open(req, timeout=30) as response:
            raw = response.read(65537)
            if len(raw) > 65536:
                raise ValueError()
            result = json.loads(raw)
            if not isinstance(result, dict):
                raise ValueError()
            return result
    except urllib.error.HTTPError as error:
        error.close()
        if error.code in (301, 302, 303, 307, 308, 401, 403):
            raise HubError('서비스 토큰 인증에 실패했습니다. 만료·권한·설정을 확인해 주세요.') from None
        if error.code == 409:
            raise HubError('파일이 이미 있거나 변경됐습니다. 현재 내용을 확인하고 교체 승인을 다시 받아 주세요.', 3) from None
        raise HubError('업로드 요청이 거절됐습니다. 파일 크기·HTML 형식·제목을 확인해 주세요.') from None
    except (OSError, ValueError, urllib.error.URLError):
        raise HubError('허브 연결 또는 응답 확인에 실패했습니다. 완료 여부를 확인한 뒤 다시 시도하세요.') from None


def check(path, auth):
    data = call_api('?' + urllib.parse.urlencode({'path': path}), auth)
    if type(data.get('exists')) is not bool or (data['exists'] and not re.fullmatch(r'[a-f0-9]{32}', str(data.get('etag')))):
        raise HubError('허브의 파일 상태를 확인하지 못했습니다.')
    return data


def publish(path, file, title, replace_etag, auth):
    try:
        with Path(file).open('rb') as source:
            html = source.read(LIMIT + 1)
        if Path(file).suffix.lower() not in ('.html', '.htm') or not html or len(html) > LIMIT:
            raise ValueError()
        if not re.search(r'<!doctype\s+html|<html(?:\s|>)', html.decode('utf-8-sig'), re.I):
            raise ValueError()
    except (OSError, ValueError, UnicodeError):
        raise HubError('16 MiB 이하의 UTF-8 HTML 파일을 지정해 주세요.') from None
    if not title.strip() or len(title.encode('utf-8')) > 1500 or '\r' in title or '\n' in title:
        raise HubError('짧은 한 줄 제목을 입력해 주세요.')
    current = check(path, auth)
    if current['exists'] and replace_etag != current['etag']:
        raise HubError('기존 URL입니다. 교체 승인을 받은 뒤 check의 etag를 --replace-etag로 지정하세요.', 3)
    if replace_etag and (not current['exists'] or not re.fullmatch(r'[a-f0-9]{32}', replace_etag)):
        raise HubError('교체 대상이 바뀌었습니다. 다시 확인하고 승인받아 주세요.', 3)
    boundary = 'hub-' + uuid.uuid4().hex
    fields = {'path': path, 'title': title.strip()}
    if replace_etag:
        fields['expectedEtag'] = replace_etag
    parts = [f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode() for key, value in fields.items()]
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="page.html"\r\nContent-Type: text/html\r\n\r\n'.encode() + html + f'\r\n--{boundary}--\r\n'.encode())
    result = call_api('', auth, b''.join(parts), 'multipart/form-data; boundary=' + boundary)
    if result.get('path') != path or result.get('url') != ORIGIN + path:
        raise HubError('저장 응답을 확인하지 못했습니다. URL 상태를 확인해 주세요.')
    return result['url']


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('check', 'publish'):
        command = sub.add_parser(name)
        command.add_argument('--path', required=True)
        if name == 'publish':
            command.add_argument('--file', required=True)
            command.add_argument('--title', required=True)
            command.add_argument('--replace-etag')
    args = parser.parse_args(argv)
    try:
        path = site_path(args.path)
        auth = credentials()
        if args.command == 'check':
            print(json.dumps(check(path, auth)))
        else:
            print(publish(path, args.file, args.title, args.replace_etag, auth))
        return 0
    except HubError as error:
        print(str(error), file=sys.stderr)
        return error.code
    except Exception:
        print('게시를 완료하지 못했습니다. 인증 설정과 연결 상태를 확인해 주세요.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
