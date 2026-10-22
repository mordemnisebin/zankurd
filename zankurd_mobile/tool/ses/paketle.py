"""Üretilen sesleri uygulamaya paketler.

Yalnız CER <= ESIK olan ("iyi") klipler alınır; zayıf olanlar alınmaz ve
uygulama o terimde ses düğmesini göstermez (yanlış telaffuz çalmaktansa
sessizlik). WAV -> AAC (m4a, mono, 24 kHz, 40 kbps) ve index.json.

Kullanım: python3 paketle.py cikti /yol/assets/audio/ku
"""
import glob
import json
import os
import subprocess
import sys

ESIK = 0.10
SPEAKER = "Anadil Kurmanji TTS (sentetik ses, VoxCPM2 + LoRA)"
LICENSE = "MIT (Anadil LoRA) + Apache-2.0 (openbmb/VoxCPM2)"
PROVENANCE = (
    "Anadilorg/Anadil_Kurmanji_TTS ile 2026-10-22'de üretildi; "
    f"facebook/mms-1b-all (kmr) ile geri okunup harf hatası <= {ESIK:.2f} olanlar alındı"
)


def main():
    cikti, hedef = sys.argv[1], sys.argv[2]
    satirlar = {}
    for yol in sorted(glob.glob(os.path.join(cikti, "sonuc_*.jsonl"))):
        for line in open(yol):
            s = json.loads(line)
            onceki = satirlar.get(s["key"])
            if onceki is None or s.get("cer", 9) < onceki.get("cer", 9):
                satirlar[s["key"]] = s
    os.makedirs(hedef, exist_ok=True)
    for eski in glob.glob(os.path.join(hedef, "*.m4a")):
        os.remove(eski)
    index = []
    alinmayan = []
    for key, s in sorted(satirlar.items()):
        wav = os.path.join(cikti, "wav", key + ".wav")
        if s.get("durum") != "iyi" or not os.path.exists(wav):
            alinmayan.append(s)
            continue
        dosya = key + ".m4a"
        subprocess.run(
            ["afconvert", "-f", "m4af", "-d", "aac@24000", "-b", "40000", "-c", "1",
             wav, os.path.join(hedef, dosya)],
            check=True,
        )
        index.append({
            "key": key,
            "text": s["text"],
            "file": dosya,
            "speaker": SPEAKER,
            "license": LICENSE,
            "provenance": PROVENANCE,
        })
    with open(os.path.join(hedef, "index.json"), "w") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)
        f.write("\n")
    with open(os.path.join(cikti, "alinmayanlar.json"), "w") as f:
        json.dump(alinmayan, f, ensure_ascii=False, indent=1)
    print(f"alınan {len(index)}, alınmayan {len(alinmayan)}")


if __name__ == "__main__":
    main()
