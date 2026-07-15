from __future__ import annotations

import sys
import ftplib

from deploy_hostinger_ftp import (
    BUILD_WEB,
    FTP_ROOT,
    connect,
    delete_tree_contents,
    ensure_cwd,
    snapshot_build,
    upload_tree,
    is_dir,
    list_names,
)


def delete_tree_contents_robust(ftp) -> None:
    for name in list_names(ftp):
        if name in {".", ".."}:
            continue
        try:
            directory = is_dir(ftp, name)
        except ftplib.error_perm:
            continue
        if directory:
            try:
                ftp.cwd(name)
                delete_tree_contents_robust(ftp)
                ftp.cwd("..")
                try:
                    ftp.rmd(name)
                except ftplib.error_perm as error:
                    if not str(error).startswith("550"):
                        raise
            except ftplib.error_perm as error:
                if not str(error).startswith("550"):
                    raise
        else:
            try:
                ftp.delete(name)
            except ftplib.error_perm as error:
                if not str(error).startswith("550"):
                    raise


def main() -> None:
    if not BUILD_WEB.exists() or not (BUILD_WEB / "main.dart.js").exists():
        raise SystemExit("Verified build/web/main.dart.js is missing")
    with connect() as ftp:
        ensure_cwd(ftp, FTP_ROOT)
        print("connected; uploading verified build", flush=True)
        snapshot = snapshot_build()
        uploaded = upload_tree(ftp, snapshot)
        print(f"uploaded_files={uploaded}", flush=True)
        print(f"build_snapshot={snapshot}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"repair failed: {error}", file=sys.stderr, flush=True)
        raise
