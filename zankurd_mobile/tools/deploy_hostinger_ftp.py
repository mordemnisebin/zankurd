from __future__ import annotations

import ftplib
import os
import posixpath
import shutil
import sys
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD_WEB = ROOT / "build" / "web"
LOCAL_BACKUP_ROOT = ROOT / "output" / "hostinger_backups"


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default or "").strip()
    if not value:
        raise SystemExit(f"Missing environment variable: {name}")
    return value


FTP_HOST = env("HOSTINGER_FTP_HOST")
FTP_USER = env("HOSTINGER_FTP_USER")
FTP_PASS = env("HOSTINGER_FTP_PASS")
FTP_PORT = int(env("HOSTINGER_FTP_PORT", "21"))
FTP_ROOT = env("HOSTINGER_FTP_ROOT", "public_html").strip("/")


def connect() -> ftplib.FTP:
    ftp = ftplib.FTP()
    ftp.connect(FTP_HOST, FTP_PORT, timeout=45)
    ftp.login(FTP_USER, FTP_PASS)
    ftp.set_pasv(True)
    return ftp


def ensure_cwd(ftp: ftplib.FTP, path: str) -> None:
    ftp.cwd("/")
    for part in path.strip("/").split("/"):
        if part:
            ftp.cwd(part)


def is_dir(ftp: ftplib.FTP, name: str) -> bool:
    current = ftp.pwd()
    try:
        ftp.cwd(name)
        ftp.cwd(current)
        return True
    except ftplib.error_perm:
        ftp.cwd(current)
        return False


def list_names(ftp: ftplib.FTP) -> list[str]:
    try:
        return ftp.nlst()
    except ftplib.error_perm as error:
        if str(error).startswith("550"):
            return []
        raise


def download_tree(ftp: ftplib.FTP, local_dir: Path) -> int:
    local_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    for name in list_names(ftp):
        if name in {".", ".."}:
            continue
        if is_dir(ftp, name):
            ftp.cwd(name)
            count += download_tree(ftp, local_dir / name)
            ftp.cwd("..")
        else:
            with (local_dir / name).open("wb") as file:
                ftp.retrbinary(f"RETR {name}", file.write)
            count += 1
    return count


def delete_tree_contents(ftp: ftplib.FTP) -> None:
    for name in list_names(ftp):
        if name in {".", ".."}:
            continue
        if is_dir(ftp, name):
            ftp.cwd(name)
            delete_tree_contents(ftp)
            ftp.cwd("..")
            ftp.rmd(name)
        else:
            ftp.delete(name)


def ensure_remote_dir(ftp: ftplib.FTP, name: str) -> None:
    try:
        ftp.mkd(name)
    except ftplib.error_perm:
        pass


def upload_tree(ftp: ftplib.FTP, local_dir: Path) -> int:
    count = 0
    for item in sorted(local_dir.iterdir(), key=lambda p: (p.is_file(), p.name.lower())):
        if item.is_dir():
            ensure_remote_dir(ftp, item.name)
            ftp.cwd(item.name)
            count += upload_tree(ftp, item)
            ftp.cwd("..")
        else:
            with item.open("rb") as file:
                ftp.storbinary(f"STOR {item.name}", file)
            count += 1
    return count


def snapshot_build() -> Path:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    target = ROOT / "output" / f"zankurd_web_release_{stamp}"
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(BUILD_WEB, target)
    return target


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "deploy"
    with connect() as ftp:
        ensure_cwd(ftp, FTP_ROOT)
        if mode == "list":
            print(f"pwd={ftp.pwd()}")
            for name in list_names(ftp):
                print(("dir " if is_dir(ftp, name) else "file ") + name)
            return

        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = LOCAL_BACKUP_ROOT / stamp
        downloaded = download_tree(ftp, backup_dir)
        print(f"backup_files={downloaded}")
        print(f"backup_dir={backup_dir}")

        delete_tree_contents(ftp)
        build_snapshot = snapshot_build()
        uploaded = upload_tree(ftp, build_snapshot)
        print(f"uploaded_files={uploaded}")
        print(f"build_snapshot={build_snapshot}")


if __name__ == "__main__":
    main()
