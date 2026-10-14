#!/usr/bin/env python3
"""Online for the browser version: the game's network adapter (DEV9) sends its TCP and UDP traffic
over one WebSocket (the page's /net, see ps2xIOP/src/emulator/dev9/web_sockets.cpp) and this relay
makes the real connections. It only reaches the game server's own ports, so it can't be used as
an open proxy.

  python3 net_relay.py --server nbas3.example.com [--listen 127.0.0.1:8765]

Put it behind the web server (Caddy: `handle /net { reverse_proxy 127.0.0.1:8765 }`).
Needs the `websockets` package (apt install python3-websockets).

Messages (binary, ids and ports little endian, IPv4 addresses in network order):
  page -> relay   1 TCP_OPEN id ip4 port16 | 2 TCP_SEND id data | 3 CLOSE id | 4 UDP_OPEN id
                  5 UDP_SEND id ip4 port16 data | 6 RESOLVE id name | 7 SHUTDOWN id
  relay -> page   10 CONNECTED id ok8 | 11 DATA id data | 12 CLOSED id
                  13 UDP_DATA id ip4 port16 data | 14 RESOLVED id ok8 ip4
"""
import argparse
import asyncio
import logging
import socket
import struct

import websockets

# The NBA Street V3 community server: accounts and lobbies (TCP), matches (UDP relay).
TCP_PORTS = {80, 10899, 21000, 21001}
UDP_PORTS = {21003}


class Session:
    """One browser: its connections, closed when it goes away."""

    def __init__(self, ws, allowed):
        self.ws = ws
        self.allowed = allowed
        self.tcp = {}  # id -> StreamWriter
        self.udp = {}  # id -> DatagramTransport
        self.tasks = set()
        self.lock = asyncio.Lock()

    async def send(self, payload):
        async with self.lock:
            try:
                await self.ws.send(payload)
            except websockets.ConnectionClosed:
                pass

    def spawn(self, coroutine):
        task = asyncio.ensure_future(coroutine)
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)

    def allowed_tcp(self, ip, port):
        return ip in self.allowed and port in TCP_PORTS

    def allowed_udp(self, ip, port):
        return ip in self.allowed and port in UDP_PORTS

    async def tcp_open(self, sid, ip, port):
        if not self.allowed_tcp(ip, port):
            logging.info("refused TCP %s:%d", ip, port)
            await self.send(struct.pack("<BIB", 10, sid, 0))
            return
        try:
            reader, writer = await asyncio.wait_for(asyncio.open_connection(ip, port), 10)
        except (OSError, asyncio.TimeoutError):
            await self.send(struct.pack("<BIB", 10, sid, 0))
            return
        sock = writer.get_extra_info("socket")
        if sock is not None:
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.tcp[sid] = writer
        await self.send(struct.pack("<BIB", 10, sid, 1))
        try:
            while True:
                data = await reader.read(65536)
                if not data:
                    break
                await self.send(struct.pack("<BI", 11, sid) + data)
        except OSError:
            pass
        await self.send(struct.pack("<BI", 12, sid))

    async def udp_open(self, sid):
        session = self
        loop = asyncio.get_running_loop()

        class Protocol(asyncio.DatagramProtocol):
            def datagram_received(self, data, address):
                ip, port = address[0], address[1]
                if session.allowed_udp(ip, port):
                    session.spawn(session.send(struct.pack("<BI", 13, sid) + socket.inet_aton(ip) + struct.pack("<H", port) + data))

        transport, _ = await loop.create_datagram_endpoint(Protocol, local_addr=("0.0.0.0", 0))
        self.udp[sid] = transport

    async def resolve(self, rid, name):
        try:
            infos = await asyncio.get_running_loop().getaddrinfo(name, None, family=socket.AF_INET)
            ip = infos[0][4][0]
            await self.send(struct.pack("<BIB", 14, rid, 1) + socket.inet_aton(ip))
        except (OSError, IndexError):
            await self.send(struct.pack("<BIB", 14, rid, 0) + b"\0\0\0\0")

    def close(self, sid):
        writer = self.tcp.pop(sid, None)
        if writer:
            writer.close()
        transport = self.udp.pop(sid, None)
        if transport:
            transport.close()

    async def handle(self, message):
        if not isinstance(message, bytes) or len(message) < 5:
            return
        kind, sid = struct.unpack_from("<BI", message)
        body = message[5:]
        if kind == 1 and len(body) >= 6:
            ip = socket.inet_ntoa(body[:4])
            (port,) = struct.unpack_from("<H", body, 4)
            self.spawn(self.tcp_open(sid, ip, port))
        elif kind == 2:
            writer = self.tcp.get(sid)
            if writer:
                writer.write(body)
                if writer.transport.get_write_buffer_size() > 1 << 20:
                    await writer.drain()
        elif kind == 3:
            self.close(sid)
        elif kind == 4:
            if sid not in self.udp:
                await self.udp_open(sid)
        elif kind == 5 and len(body) >= 6:
            ip = socket.inet_ntoa(body[:4])
            (port,) = struct.unpack_from("<H", body, 4)
            transport = self.udp.get(sid)
            if transport and self.allowed_udp(ip, port):
                transport.sendto(body[6:], (ip, port))
        elif kind == 6:
            self.spawn(self.resolve(sid, body.decode("ascii", "replace")))
        elif kind == 7:
            writer = self.tcp.get(sid)
            if writer and writer.can_write_eof():
                writer.write_eof()

    async def run(self):
        try:
            async for message in self.ws:
                await self.handle(message)
        except websockets.ConnectionClosed:
            pass
        finally:
            for sid in list(self.tcp) + list(self.udp):
                self.close(sid)
            for task in list(self.tasks):
                task.cancel()


def server_addresses(name):
    addresses = {"127.0.0.1"}
    for info in socket.getaddrinfo(name, None, family=socket.AF_INET):
        addresses.add(info[4][0])
    return addresses


async def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--server", required=True, help="the game server's name or IPv4 address")
    parser.add_argument("--listen", default="127.0.0.1:8765")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    allowed = server_addresses(args.server)
    host, port = args.listen.rsplit(":", 1)
    logging.info("relay on %s:%s to %s (%s)", host, port, args.server, ", ".join(sorted(allowed)))

    async def handler(ws):
        logging.info("browser connected")
        await Session(ws, allowed).run()
        logging.info("browser gone")

    async with websockets.serve(handler, host, int(port), max_size=1 << 22, compression=None):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
