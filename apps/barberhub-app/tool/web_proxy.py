"""Servidor local para testar o app no navegador, sem emulador. Só para desenvolvimento.

O BFF e o Keycloak não liberam CORS, então o navegador bloqueia as chamadas do app web
feitas direto para as portas 8010 e 8080. Este servidor entrega o build web em / e repassa
/bff para o BFF e /kc para o Keycloak: para o navegador, tudo vem do mesmo endereço.
Nada muda no back-end. Quem chama é o tool/web.sh.

    python3 tool/web_proxy.py <pasta build/web> [porta]

Outro endereço de back-end: variáveis BFF_DESTINO e KEYCLOAK_DESTINO.
"""

import os
import sys
import urllib.error
import urllib.request
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

DESTINOS = {
    "/bff": os.environ.get("BFF_DESTINO", "http://localhost:8010").rstrip("/"),
    "/kc": os.environ.get("KEYCLOAK_DESTINO", "http://localhost:8080").rstrip("/"),
}
REPASSAR = ("authorization", "content-type", "accept")


class Handler(SimpleHTTPRequestHandler):
    def _destino(self):
        for prefixo, base in DESTINOS.items():
            if self.path == prefixo or self.path.startswith(prefixo + "/"):
                return base + self.path[len(prefixo):]
        return None

    def _repassar(self):
        tamanho = int(self.headers.get("Content-Length") or 0)
        corpo = self.rfile.read(tamanho) if tamanho else None
        headers = {k: v for k, v in self.headers.items() if k.lower() in REPASSAR}
        pedido = urllib.request.Request(
            self._destino(), data=corpo, method=self.command, headers=headers
        )
        try:
            resposta = urllib.request.urlopen(pedido, timeout=30)
        except urllib.error.HTTPError as erro:
            resposta = erro  # 4xx e 5xx do back-end voltam para o app como vieram
        except OSError as erro:
            self.send_error(502, f"Back-end fora do ar: {erro}")
            return
        dados = resposta.read()
        self.send_response(resposta.status)
        tipo = resposta.headers.get("Content-Type")
        if tipo:
            self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(dados)))
        self.end_headers()
        self.wfile.write(dados)

    def do_GET(self):
        if self._destino():
            self._repassar()
        else:
            super().do_GET()

    def do_POST(self):
        if self._destino():
            self._repassar()
        else:
            self.send_error(405)

    do_DELETE = do_PUT = do_PATCH = do_POST

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "authorization, content-type, accept")
        self.send_header("Access-Control-Max-Age", "600")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def end_headers(self):
        # Sem cache: depois de um build novo, recarregar a página já pega a versão nova.
        self.send_header("Cache-Control", "no-store")
        # O build chama http://localhost:<porta>. Abrir a página por http://127.0.0.1:<porta>
        # é outra origem para o navegador; com este header as duas funcionam.
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    pasta = sys.argv[1]
    porta = int(sys.argv[2]) if len(sys.argv) > 2 else 5173
    ThreadingHTTPServer.request_queue_size = 128
    servidor = ThreadingHTTPServer(("127.0.0.1", porta), partial(Handler, directory=pasta))
    print(f"App em http://localhost:{porta}/  (Ctrl+C para parar)", flush=True)
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass
