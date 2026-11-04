#!/usr/bin/env python3
"""Planı koşturur: her kategori için alt konuları sırayla üretir.

## Eşzamanlılık kararı

Kategoriler PARALEL, kategori içi alt konular SIRALI koşar. Sebep tekrar
engelleme: üretici, çıktı dosyasındaki mevcut soruları modele "bunları
üretme" diye veriyor. Aynı dosyaya iki iş birden yazarsa o liste yarış
durumuna girer ve partiler arası tekrar engellenemez. Kategori başına ayrı
dosya + kategori içi sıralılık bunu çözer.

Kullanım:
  python3 tool/content_authoring/run_plan.py --out-dir docs/content_batches
  python3 tool/content_authoring/run_plan.py --only Teknolojî --count 10
"""
import argparse
import json
import pathlib
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(__file__).resolve().parents[2]
PLAN = ROOT / "tool/content_authoring/plan.json"
GENERATOR = ROOT / "tool/content_authoring/generate_batch.py"


def run_category(category: str, spec: dict, out_dir: pathlib.Path,
                 count: int, retries: int) -> tuple[str, int, int, list[str]]:
    out = out_dir / f"{category}.csv"
    done = failed = 0
    failed_subtopics: list[str] = []
    for subtopic in spec["subtopics"]:
        for attempt in range(retries + 1):
            result = subprocess.run(
                [sys.executable, str(GENERATOR),
                 "--category", category, "--subtopic", subtopic,
                 "--count", str(count), "--ratio", spec["ratio"],
                 "--out", str(out), "--max-tokens", "16000"],
                capture_output=True, text=True, cwd=ROOT,
            )
            line = (result.stdout or result.stderr).strip().splitlines()
            tail = line[-1] if line else "(çıktı yok)"
            if result.returncode == 0:
                done += 1
                print(f"  ✓ {category} · {subtopic[:44]} → {tail}", flush=True)
                break
            if attempt < retries:
                # Geçici API hatası ve modelin biçimi kaçırması aynı görünür;
                # ikisi de yeniden denemeye değer, ama sonsuz değil.
                time.sleep(5)
                continue
            failed += 1
            failed_subtopics.append(subtopic)
            print(f"  ✗ {category} · {subtopic[:44]} → {tail}", flush=True)
    return category, done, failed, failed_subtopics


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default="docs/content_batches")
    parser.add_argument("--count", type=int, default=25)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--only", action="append")
    args = parser.parse_args()

    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    if args.only:
        plan = {k: v for k, v in plan.items() if k in args.only}
    out_dir = ROOT / args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    total = sum(len(v["subtopics"]) for v in plan.values())
    print(f"{len(plan)} kategori, {total} parti, parti başına {args.count} soru")
    print(f"hedef: ~{total * args.count} soru\n", flush=True)

    started = time.time()
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(
            lambda item: run_category(item[0], item[1], out_dir,
                                      args.count, args.retries),
            plan.items(),
        ))

    print(f"\n{'kategori':<12} {'parti':>6} {'düşen':>6}")
    for category, done, failed, _ in sorted(results):
        print(f"{category:<12} {done:>6} {failed:>6}")
    print(f"\nsüre: {(time.time() - started) / 60:.1f} dk")

    # Sonuç manifesti: başarılı çıktılar korunur; yalnız düşen partiler
    # yeniden çalıştırılabilsin. Ana komut eskiden her durumda 0 dönüyordu
    # (bütün partiler düşse bile başarılı sayılıyordu).
    toplam_biten = sum(r[1] for r in results)
    toplam_dusen = sum(r[2] for r in results)
    manifest = {
        "kategoriler": {c: {"biten": d, "dusen": f, "dusen_altkonular": fs}
                        for c, d, f, fs in results},
        "toplam_biten": toplam_biten,
        "toplam_dusen": toplam_dusen,
    }
    (out_dir / "run_plan_sonuc.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    if toplam_dusen > 0 or toplam_biten == 0:
        print(f"HATA: {toplam_dusen} parti düştü, {toplam_biten} parti bitti; "
              "düşenler için run_plan_sonuc.json'a bak.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
