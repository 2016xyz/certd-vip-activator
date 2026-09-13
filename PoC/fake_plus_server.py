#!/usr/bin/env python3
"""
certd 假激活服务器 (Fake Plus Server) v2 — 动态签发 license
====================================================
原理:
  certd 容器启动后通过 PLUS_SERVER_BASE_URL 指向此服务器。
  patched/plus-core-*.js 的内置公钥 = 本目录 selfsign_key.pem 的公钥。
  certd 启动时向本服务器请求 register / license/update / vip/check,
  本服务器用私钥**按 certd 实际上报的 subjectId 动态签发**永久 license,
  certd 端 verifyLocalOnly 校验通过 → isPlus()=true。

动态签发是关键: license content 第2字段是 subjectId (即站点 siteId),
每台机器新装 certd siteId 都随机, 静态 license 文件无法通用。

依赖: cryptography (pip install cryptography)
用法: python fake_plus_server.py
环境变量:
  CERTD_FAKE_SERVER_PORT  监听端口, 默认 11007
  CERTD_SELF_KEY          私钥 PEM 路径, 默认 /app/selfsign_key.pem
  CERTD_VIP_TYPE          plus / comm, 默认 plus
"""
import base64
import hashlib
import json
import os
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

PORT = int(os.environ.get('CERTD_FAKE_SERVER_PORT', '11007'))
KEY_PATH = os.environ.get('CERTD_SELF_KEY', '/app/selfsign_key.pem')
VIP_TYPE = os.environ.get('CERTD_VIP_TYPE', 'plus')
APP_KEY = 'kQth6FHM71IPV3qdWc'

with open(KEY_PATH, 'rb') as f:
    PRIVATE_KEY = serialization.load_pem_private_key(f.read(), password=None)


class LicenseIssuer:
    """按 subjectId 动态签发永久 license, 与 plus-core localVerify 时签名串完全一致"""

    SECRET_MAP = {}  # subjectId → secret (注册时生成并缓存, 密钥一致即可)

    @staticmethod
    def _random_secret(n_bytes=32):
        return base64.b64encode(os.urandom(n_bytes)).decode()[:47]

    @classmethod
    def issue(cls, subject_id: str, vip_type: str = None) -> str:
        vip_type = vip_type or VIP_TYPE
        if subject_id not in cls.SECRET_MAP:
            cls.SECRET_MAP[subject_id] = cls._random_secret()
        secret = cls.SECRET_MAP[subject_id]

        lic = {
            'subjectId': '',
            'appKey': '',
            'duration': -1,
            'activeTime': int(time.time() * 1000),
            'version': 1,
            'code': f'FAKE_SERVER_PERMANENT_{vip_type.upper()}',
            'vipType': vip_type,
            'expireTime': -1,
            'secret': secret,
        }
        content = f"{APP_KEY},{subject_id},{lic['code']},{lic['secret']},{lic['vipType']},{lic['activeTime']},{lic['duration']},{lic['expireTime']},{lic['version']}"
        sig = PRIVATE_KEY.sign(
            content.encode('utf-8'),
            padding.PKCS1v15(),
            hashes.SHA256(),
        )
        lic['signature'] = base64.b64encode(sig).decode()
        return base64.b64encode(json.dumps(lic, separators=(',', ':')).encode()).decode()


class FakePlusHandler(BaseHTTPRequestHandler):
    def _json(self, payload):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        body = json.dumps(payload).encode()
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _headers_json(self):
        xs = self.headers.get('X-Plus-Subject')
        if not xs:
            return {}
        try:
            return json.loads(base64.b64decode(xs).decode())
        except Exception:
            return {}

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body_raw = self.rfile.read(length) if length > 0 else b'{}'
        try:
            body = json.loads(body_raw or b'{}')
        except Exception:
            body = {}
        hdr = self._headers_json()
        subject_id = hdr.get('subjectId') or body.get('subjectId') or 'UNKNOWN'
        path = self.path

        print(f'[fake-plus] POST {path}  subjectId={subject_id}')

        if path.endswith('/activation/app/get'):
            return self._json({'code': 0, 'data': {'ok': True}})

        if path.endswith('/activation/subject/register'):
            lic = LicenseIssuer.issue(subject_id)
            return self._json({'code': 0, 'data': {'license': lic}})

        if path.endswith('/activation/subject/license/update'):
            lic = LicenseIssuer.issue(subject_id)
            return self._json({'code': 0, 'data': {'license': lic}})

        if path.endswith('/activation/subject/vip/check'):
            lic = LicenseIssuer.issue(subject_id)
            return self._json({
                'code': 0,
                'data': {'ok': True, 'expiresAt': -1, 'vipType': VIP_TYPE, 'license': lic},
            })

        if path.endswith('/activation/subject/vip/trialGet'):
            lic = LicenseIssuer.issue(subject_id, body.get('vipType') or VIP_TYPE)
            return self._json({'code': 0, 'data': {'license': lic, 'duration': -1}})

        if path.endswith('/activation/subject/urlBind'):
            return self._json({'code': 0, 'data': {'ok': True}})

        if path.endswith('/activation/active'):
            lic = LicenseIssuer.issue(subject_id)
            return self._json({'code': 0, 'data': {'license': lic}})

        return self._json({'code': 0, 'data': {'ok': True}})

    def do_GET(self):
        self.do_POST()

    def log_message(self, fmt, *args):
        pass


def main():
    server = HTTPServer(('0.0.0.0', PORT), FakePlusHandler)
    print(f'[fake-plus-server v2 动态签发] listening 0.0.0.0:{PORT}, 私钥: {KEY_PATH}, VIP类型: {VIP_TYPE}')
    server.serve_forever()


if __name__ == '__main__':
    main()
