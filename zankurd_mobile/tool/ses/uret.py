"""ZanKurd sözlük terimleri için Kurmancî ses üretimi.

Model: Anadil Kurmanji TTS (VoxCPM2 + LoRA; adaptör MIT, taban Apache-2.0),
TENDURISTI/taslaklar/ses-denemesi'deki kurulum. Her terim için tohum 1..N
denenir; her aday MMS-1B (kmr-script_latin) ile geri metne çevrilir ve harf
hata oranı (CER) ölçülür. CER <= ESIK olan ilk aday alınır, yoksa en düşük
CER'li aday ve satır "zayif" işaretlenir.

Devam edilebilir: sonuc.jsonl'de olan anahtar atlanır.
Kullanım (TENDURISTI venv'iyle):
  python uret.py terimler.json cikti_klasoru [baslangic] [bitis]
"""
import json
import os
import re
import subprocess
import sys
import time
import unicodedata

import numpy as np
import soundfile as sf
import torch

TTS_DIR = "/Users/kocer/Projects/TENDURISTI/taslaklar/ses-denemesi"
LORA = TTS_DIR + "/models/anadil/"
PREFIX = "[speaker:spk_tmp_001 language:kmr] "
SR = 48000
ESIK = 0.10
TOHUMLAR = [int(x) for x in os.environ.get("ZK_TOHUMLAR", "1,2,3").split(",")]


def log(*a):
    print(*a, flush=True)


def norm(s):
    s = unicodedata.normalize("NFC", s.lower())
    return re.sub(r"[^\w]", "", s)


def cer(r, h):
    if not r:
        return 1.0
    d = list(range(len(h) + 1))
    for i in range(1, len(r) + 1):
        prev = d[:]
        d[0] = i
        for j in range(1, len(h) + 1):
            d[j] = min(prev[j] + 1, d[j - 1] + 1, prev[j - 1] + (r[i - 1] != h[j - 1]))
    return d[-1] / len(r)


def kirp(a, sr=SR):
    """Baş/son sessizliği kırpar; 30 ms pay bırakır, kenarları yumuşatır."""
    if a.size == 0:
        return a
    fr = int(sr * 0.01)
    n = len(a) // fr
    if n == 0:
        return a
    e = np.sqrt(np.mean(a[: n * fr].reshape(n, fr) ** 2, axis=1))
    thr = max(e.max() * 0.04, 1e-4)
    idx = np.where(e > thr)[0]
    if idx.size == 0:
        return a
    s = max(idx[0] * fr - int(sr * 0.03), 0)
    t = min((idx[-1] + 1) * fr + int(sr * 0.06), len(a))
    a = a[s:t].copy()
    fi, fo = int(sr * 0.006), int(sr * 0.04)
    a[:fi] *= np.linspace(0, 1, fi)
    a[-fo:] *= np.linspace(1, 0, fo)
    peak = np.abs(a).max()
    if peak > 0:
        a = a / peak * 0.89
    return a.astype(np.float32)


def main():
    terimler = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    lo = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    hi = int(sys.argv[4]) if len(sys.argv) > 4 else len(terimler)
    os.makedirs(out + "/wav", exist_ok=True)
    sonuc_yolu = out + f"/sonuc_{lo}_{hi}.jsonl"
    bitti = set()
    if os.path.exists(sonuc_yolu):
        for line in open(sonuc_yolu):
            bitti.add(json.loads(line)["key"])

    from voxcpm import VoxCPM
    from voxcpm.model.voxcpm import LoRAConfig
    from transformers import AutoProcessor, Wav2Vec2ForCTC

    lc = json.load(open(LORA + "lora_config.json"))["lora_config"]
    cfg = LoRAConfig(**{k: v for k, v in lc.items() if k in LoRAConfig.model_fields})
    tts = VoxCPM.from_pretrained(
        "openbmb/VoxCPM2",
        load_denoiser=False,
        lora_config=cfg,
        lora_weights_path=LORA + "lora_weights.safetensors",
        device="mps",
    )
    proc = AutoProcessor.from_pretrained("facebook/mms-1b-all", target_lang="kmr-script_latin")
    asr = Wav2Vec2ForCTC.from_pretrained(
        "facebook/mms-1b-all", target_lang="kmr-script_latin", ignore_mismatched_sizes=True
    ).eval()

    def dinle(a):
        x16 = np.interp(
            np.linspace(0, len(a), int(len(a) * 16000 / SR), endpoint=False),
            np.arange(len(a)),
            a,
        ).astype(np.float32)
        x = proc(x16, sampling_rate=16000, return_tensors="pt")
        with torch.no_grad():
            lg = asr(**x).logits
        return proc.decode(torch.argmax(lg, -1)[0])

    with open(sonuc_yolu, "a") as kayit:
        for i in range(lo, hi):
            t = terimler[i]
            if t["key"] in bitti:
                continue
            metin = t["text"].strip()
            # İki biçimli ("Kûçik / Seg") ya da açıklamalı ("Wî (nêr)") terim
            # sesli okununca anlamsız olur: ses üretilmez, düğme görünmez.
            if "/" in metin or "(" in metin:
                kayit.write(json.dumps({"key": t["key"], "text": metin, "durum": "atlandi"}, ensure_ascii=False) + "\n")
                kayit.flush()
                continue
            # Çok kısa sözcükte MMS geri okuması bir harfi kaçırınca CER
            # sıçrar ("Hesp" -> "hesm" 0.25); eşik kısa sözcükte 0.25.
            esik = 0.25 if len(norm(metin)) <= 5 and os.environ.get("ZK_SIKI") != "1" else ESIK
            okunan = metin if metin[-1] in ".?!" else metin + "."
            en_iyi = None
            t0 = time.time()
            for tohum in TOHUMLAR:
                torch.manual_seed(tohum)
                a = np.asarray(
                    tts.generate(text=PREFIX + okunan, inference_timesteps=int(os.environ.get("ZK_TS", "10")), cfg_value=float(os.environ.get("ZK_CFG", "3.0")))
                ).squeeze().astype(np.float32)
                a = kirp(a)
                if len(a) < SR * 0.15 or len(a) > SR * 8:
                    continue
                h = dinle(a)
                c = cer(norm(metin), norm(h))
                if en_iyi is None or c < en_iyi[0]:
                    en_iyi = (c, a, h, tohum)
                if c <= esik:
                    break
            if en_iyi is None:
                satir = {"key": t["key"], "text": metin, "durum": "yok"}
            else:
                c, a, h, tohum = en_iyi
                wav = f"{out}/wav/{t['key']}.wav"
                sf.write(wav, a, SR)
                satir = {
                    "key": t["key"],
                    "text": metin,
                    "cer": round(c, 3),
                    "asr": h,
                    "tohum": tohum,
                    "sure": round(len(a) / SR, 2),
                    "durum": "iyi" if c <= esik else "zayif",
                }
            kayit.write(json.dumps(satir, ensure_ascii=False) + "\n")
            kayit.flush()
            log(i, satir.get("durum"), satir.get("cer"), metin, "->", satir.get("asr"), f"{time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
