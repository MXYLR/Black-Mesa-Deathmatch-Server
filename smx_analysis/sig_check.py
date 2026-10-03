#!/usr/bin/env python3
"""在「已加载」镜像上校验 gamedata 签名是否唯一命中。

为什么需要这个：SourceMod 的 GameConfGetAddress 是在**进程内存里**扫描已重定位的
模块，而绝对地址类指令（mov ecx,[abs] / cmp reg,imm32 / movss xmm,[abs]）的
32 位字段在加载时会被基址重定位改写。所以只在磁盘文件上验证唯一命中是不够的 ——
一旦签名包含这类字段，磁盘上命中、运行时必然失配。

本脚本把 PE 的 base relocation 表施加到文件字节上（模拟任意 ASLR 基址），
再扫描，因此结果与运行时一致。

用法:
    python sig_check.py <dll> <pattern>
    pattern 用空格或反斜杠分隔的十六进制字节，通配用 ?? 或 2A
    例: python sig_check.py server.dll 0F 84 ?? ?? ?? ?? 81 F9 ?? ?? ?? ?? 75 16
"""
import sys
import struct

import pefile

IMAGE_BASE_REL_HIGHLOW = 3


def load(path):
    raw = bytearray(open(path, 'rb').read())
    pe = pefile.PE(path, fast_load=True)
    pe.parse_data_directories(
        directories=[pefile.DIRECTORY_ENTRY['IMAGE_DIRECTORY_ENTRY_BASERELOC']])
    return raw, pe


def va2off(pe, raw, va):
    rva = va - pe.OPTIONAL_HEADER.ImageBase
    for s in pe.sections:
        if s.VirtualAddress <= rva < s.VirtualAddress + max(s.Misc_VirtualSize, s.SizeOfRawData):
            off = s.PointerToRawData + (rva - s.VirtualAddress)
            if 0 <= off < len(raw):
                return off
    return None


def relocate(pe, raw, delta):
    """按 base relocation 表把绝对地址字段加上 delta，返回模拟已加载的字节。"""
    out = bytearray(raw)
    n = 0
    for blk in getattr(pe, 'DIRECTORY_ENTRY_BASERELOC', []):
        base = pe.OPTIONAL_HEADER.ImageBase + blk.struct.VirtualAddress
        blkoff = blk.struct.get_file_offset()
        body = bytes(raw[blkoff + 8: blkoff + blk.struct.SizeOfBlock])
        for i in range(0, len(body) - 1, 2):
            v = struct.unpack_from('<H', body, i)[0]
            if (v >> 12) != IMAGE_BASE_REL_HIGHLOW:
                continue
            off = va2off(pe, raw, base + (v & 0x0FFF))
            if off is None or off + 4 > len(out):
                continue
            cur = struct.unpack_from('<I', out, off)[0]
            struct.pack_into('<I', out, off, (cur + delta) & 0xFFFFFFFF)
            n += 1
    return out, n


def parse_pattern(text):
    toks = text.replace('\\x', ' ').replace(',', ' ').split()
    return [None if t.lower() in ('??', '2a', '*') else int(t, 16) for t in toks]


def scan(buf, pe, pat):
    n = len(pat)
    first = next((i for i, b in enumerate(pat) if b is not None), None)
    hits = []
    if first is None:
        return hits[:0]
    start = 0
    while True:
        idx = buf.find(bytes([pat[first]]), start)
        if idx < 0:
            break
        start = idx + 1
        if idx - first < 0 or idx - first + n > len(buf):
            continue
        ok = True
        for k in range(n):
            b = pat[k]
            if b is not None and buf[idx - first + k] != b:
                ok = False
                break
        if ok:
            hits.append(idx - first)
    # 只保留落在节内、且能换算成 VA 的命中
    out = []
    for off in hits:
        for s in pe.sections:
            if s.PointerToRawData <= off < s.PointerToRawData + s.SizeOfRawData:
                out.append((s.VirtualAddress + (off - s.PointerToRawData),
                            s.Name.rstrip(b'\x00').decode()))
                break
    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    dll, pattext = sys.argv[1], ' '.join(sys.argv[2:])
    pat = parse_pattern(pattext)
    raw, pe = load(dll)
    base = pe.OPTIONAL_HEADER.ImageBase

    print("dll        = %s" % dll)
    print("ImageBase  = 0x%08X" % base)
    print("pattern    = %d bytes (%d wildcards)" % (len(pat), pat.count(None)))
    print()

    fh = scan(bytes(raw), pe, pat)
    print("[磁盘镜像]  命中 %d 处" % len(fh))
    for va, sec in fh:
        print("            0x%08X  (%s)" % (base + va, sec))

    # 用两个不同的 ASLR 基址各模拟一次，确认结论与基址无关
    for delta in (0x193C0000, 0x1A500000):
        rel, n = relocate(pe, raw, delta)
        rh = scan(bytes(rel), pe, pat)
        print("[已加载镜像 +0x%08X, 重定位 %d 处]  命中 %d 处"
              % (delta, n, len(rh)))
        for va, sec in rh:
            print("            0x%08X  (%s)" % (base + delta + va, sec))
    return 0


if __name__ == '__main__':
    sys.exit(main())
