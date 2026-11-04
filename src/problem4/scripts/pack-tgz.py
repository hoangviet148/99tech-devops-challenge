import gzip
import os
import sys
import tarfile


def normalize(info, mtime):
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    info.mtime = mtime
    if info.isdir():
        info.mode = 0o755
    else:
        info.mode = 0o755 if info.mode & 0o111 else 0o644
    return info


def entries(src):
    found = []
    for root, dirs, files in os.walk(src):
        for name in dirs + files:
            path = os.path.join(root, name)
            if os.path.islink(path):
                raise SystemExit(f"refusing to pack a symlink: {os.path.relpath(path, src)}")
            found.append(os.path.relpath(path, src))
    return sorted(found)


def main():
    src, dst, mtime = sys.argv[1], sys.argv[2], int(sys.argv[3])
    with open(dst, "wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as gz:
        with tarfile.open(fileobj=gz, mode="w", format=tarfile.PAX_FORMAT) as tar:
            for rel in entries(src):
                tar.add(os.path.join(src, rel), arcname=rel, recursive=False, filter=lambda i: normalize(i, mtime))


if __name__ == "__main__":
    main()
