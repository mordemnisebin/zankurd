#!/usr/bin/env python3
"""Build an editor-facing queue from the JSON banks registered at runtime."""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
import re
import sys
import unicodedata


class AuditError(RuntimeError):
    pass


_ASSET_RE = re.compile(r"['\"](assets/data/[^'\"]+\.json)['\"]")


def registered_assets(manifest: Path) -> list[str]:
    try:
        source = manifest.read_text(encoding="utf-8")
    except OSError as exc:
        raise AuditError(f"Cannot read manifest: {manifest}: {exc}") from exc
    marker = "questionBankAssets"
    start = source.find(marker)
    if start < 0:
        raise AuditError(f"questionBankAssets not found in {manifest}")
    open_bracket = source.find("[", start)
    close_bracket = source.find("]", open_bracket)
    if open_bracket < 0 or close_bracket < 0:
        raise AuditError(f"Malformed questionBankAssets declaration in {manifest}")
    block = source[open_bracket + 1 : close_bracket]
    active = "\n".join(line.split("//", 1)[0] for line in block.splitlines())
    assets = _ASSET_RE.findall(active)
    if not assets:
        raise AuditError(f"No registered JSON banks found in {manifest}")
    return assets


def _text(value: object) -> str:
    return value.strip() if isinstance(value, str) else ""


def _record(asset: str, raw: dict[str, object]) -> dict[str, object]:
    metadata = raw.get("metadata")
    metadata_map = metadata if isinstance(metadata, dict) else {}
    review_status = _text(metadata_map.get("reviewStatus")) or "unreviewed"
    source_title = _text(metadata_map.get("sourceTitle"))
    source_reference = _text(metadata_map.get("sourceReference"))
    image_url = _text(raw.get("imageUrl"))
    image_alt_missing = bool(image_url) and not (
        _text(raw.get("imageAltKu")) and _text(raw.get("imageAltTr"))
    )
    audio_absent = not any(
        _text(raw.get(field)) for field in ("audioUrl", "audioAsset", "audio")
    )
    source_missing = not (source_title and source_reference)

    if image_alt_missing and _text(raw.get("type")) == "visual":
        priority = "P0"
    elif review_status == "rejected":
        priority = "P1"
    elif review_status == "needsReview":
        priority = "P2"
    elif review_status == "unreviewed" or source_missing:
        priority = "P3"
    else:
        priority = "P4"

    return {
        "priority": priority,
        "id": _text(raw.get("id")),
        "bank": asset,
        "category": _text(raw.get("category")),
        "type": _text(raw.get("type")) or "unspecified",
        "difficulty": raw.get("difficulty"),
        "reviewStatus": review_status,
        "metadataAbsent": not isinstance(metadata, dict),
        "sourceMissing": source_missing,
        "sourceTitle": source_title,
        "sourceReference": source_reference,
        "imageUrl": image_url,
        "imageAltMissing": image_alt_missing,
        "audioAbsent": audio_absent,
        "prompt": _text(raw.get("prompt")),
        "promptTr": _text(raw.get("promptTr")),
    }


def reviewed_duplicate_groups(
    root: Path, raw_records: dict[tuple[str, str], dict[str, object]]
) -> dict[str, object]:
    """Validate explicit reviews; no removal, suppression or semantic inference."""
    path = root / "tool/content_authoring/reviewed_duplicate_groups.json"
    if not path.exists():
        return {"status": "not_configured", "groups": []}
    try:
        sidecar = json.loads(path.read_text(encoding="utf-8"))
        if (not isinstance(sidecar, dict) or sidecar.get("schemaVersion") != 1
                or sidecar.get("hashAlgorithm") != "sha256-canonical-json-v1"
                or not isinstance(sidecar.get("groups"), list)):
            raise ValueError("unsupported schema or hash algorithm")
        groups = []
        seen_groups = set()
        seen_members = set()
        for group in sidecar["groups"]:
            if not isinstance(group, dict):
                raise ValueError("group must be an object")
            group_id = group.get("groupId")
            if not isinstance(group_id, str) or not group_id or group_id in seen_groups:
                raise ValueError("groupId must be nonempty and unique")
            seen_groups.add(group_id)
            if not isinstance(group.get("rationale"), str) or not group["rationale"].strip():
                raise ValueError("group rationale is required")
            members = group.get("members")
            if not isinstance(members, list) or len(members) < 2:
                raise ValueError("group requires at least two members")
            checked = []
            for member in members:
                if not isinstance(member, dict):
                    raise ValueError("member must be an object")
                source, record_id = member.get("sourcePath"), member.get("id")
                expected = member.get("recordSha256")
                if (not isinstance(source, str) or not source.startswith("assets/data/")
                        or not isinstance(record_id, str) or not record_id
                        or not isinstance(expected, str)
                        or not re.fullmatch(r"[0-9a-f]{64}", expected)):
                    raise ValueError("invalid source/id/recordSha256")
                key = (source, record_id)
                if key in seen_members:
                    raise ValueError("member belongs to multiple groups; union them first")
                seen_members.add(key)
                raw = raw_records.get(key)
                actual = None if raw is None else hashlib.sha256(json.dumps(
                    raw, ensure_ascii=False, sort_keys=True, separators=(",", ":")
                ).encode("utf-8")).hexdigest()
                status = "missing_or_not_registered" if raw is None else (
                    "current" if actual == expected else "changed")
                checked.append({**member, "actualRecordSha256": actual, "status": status})
            valid = all(member["status"] == "current" for member in checked)
            member_keys = {(m["sourcePath"], m["id"]) for m in members}
            matches = []
            for key, candidate in raw_records.items():
                if key in member_keys:
                    continue
                for member in checked:
                    raw = raw_records.get((member["sourcePath"], member["id"]))
                    if raw is None:
                        continue
                    left, right = _text(candidate.get("prompt")), _text(raw.get("prompt"))
                    normalize = lambda text: " ".join(unicodedata.normalize("NFKC", text).casefold().split())
                    if left and normalize(left) == normalize(right):
                        matches.append({"sourcePath": key[0], "id": key[1],
                            "matchesMemberId": member["id"],
                            "matchKind": "exact_prompt" if left == right else "normalized_prompt",
                            "semanticReviewRequired": True})
                        break
            groups.append({**group, "members": checked, "reviewValid": valid,
                "status": "current" if valid else "stale",
                "unreviewedPromptMatches": matches})
        return {"status": "loaded", "sourcePath": str(path.relative_to(root)),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "scopeNote": "Explicit same-objective review only; prompt matches are unreviewed candidates. No semantic third-variant detection or quality suppression.",
            "groups": groups}
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError, TypeError) as exc:
        raise AuditError(f"Invalid reviewed duplicate sidecar: {exc}") from exc


def build_report(root: Path, manifest: Path | None = None) -> dict[str, object]:
    manifest = manifest or root / "lib/src/data/question_bank_assets.dart"
    assets = registered_assets(manifest)
    records: list[dict[str, object]] = []
    banks: list[dict[str, object]] = []
    seen_ids: dict[str, str] = {}
    combined = hashlib.sha256()
    raw_records: dict[tuple[str, str], dict[str, object]] = {}

    for asset in assets:
        path = root / asset
        try:
            content = path.read_bytes()
        except OSError as exc:
            raise AuditError(f"Declared bank missing or unreadable: {asset}: {exc}") from exc
        try:
            decoded = json.loads(content)
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            raise AuditError(f"Malformed JSON in {asset}: {exc}") from exc
        if not isinstance(decoded, list):
            raise AuditError(f"Bank must contain a JSON list: {asset}")
        digest = hashlib.sha256(content).hexdigest()
        banks.append({"asset": asset, "sha256": digest, "recordCount": len(decoded)})
        combined.update(asset.encode("utf-8"))
        combined.update(b"\0")
        combined.update(content)

        for index, item in enumerate(decoded):
            if not isinstance(item, dict):
                raise AuditError(f"Record {index} in {asset} is not an object")
            record = _record(asset, item)
            question_id = record["id"]
            if not question_id:
                raise AuditError(f"Record {index} in {asset} has no id")
            if question_id in seen_ids:
                raise AuditError(
                    f"Duplicate id: {question_id} ({seen_ids[question_id]}, {asset})"
                )
            seen_ids[question_id] = asset
            raw_records[(asset, question_id)] = item
            records.append(record)

    priority_order = {f"P{i}": i for i in range(5)}
    records.sort(key=lambda row: (priority_order[str(row["priority"])], str(row["id"])))
    statuses = Counter(str(row["reviewStatus"]) for row in records)
    priorities = Counter(str(row["priority"]) for row in records)
    return {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "scope": "registered_json_assets_only",
        "scopeNote": (
            "Only JSON assets actively listed in questionBankAssets are counted; "
            "commented/quarantined files and Dart curated/runtime totals are excluded."
        ),
        "source": {
            "manifest": str(manifest.relative_to(root)),
            "sha256": combined.hexdigest(),
            "banks": banks,
        },
        "summary": {
            "bankCount": len(banks),
            "recordCount": len(records),
            "reviewStatuses": dict(sorted(statuses.items())),
            "priorities": dict(sorted(priorities.items())),
            "sourceMissing": sum(bool(row["sourceMissing"]) for row in records),
            "imageAltMissing": sum(bool(row["imageAltMissing"]) for row in records),
            "audioAbsent": sum(bool(row["audioAbsent"]) for row in records),
        },
        "reviewedDuplicateGroups": reviewed_duplicate_groups(root, raw_records),
        "records": records,
    }


def write_outputs(report: dict[str, object], output_base: Path) -> None:
    output_base.parent.mkdir(parents=True, exist_ok=True)
    output_base.with_suffix(".json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    records = report["records"]
    assert isinstance(records, list)
    fields = list(records[0]) if records else ["priority", "id"]
    csv_buffer = io.StringIO(newline="")
    writer = csv.DictWriter(csv_buffer, fieldnames=fields)
    writer.writeheader()
    writer.writerows(records)
    output_base.with_suffix(".csv").write_text(csv_buffer.getvalue(), encoding="utf-8")

    summary = report["summary"]
    assert isinstance(summary, dict)
    statuses = summary["reviewStatuses"]
    priorities = summary["priorities"]
    lines = [
        "# Editoryal soru kuyruğu",
        "",
        f"Üretim zamanı: `{report['generatedAt']}`",
        "",
        "## Kapsam",
        "",
        str(report["scopeNote"]),
        "",
        f"- Kayıtlı JSON bankası: {summary['bankCount']}",
        f"- JSON kaydı: {summary['recordCount']}",
        f"- Kaynağı eksik: {summary['sourceMissing']}",
        f"- Görsel betimlemesi eksik: {summary['imageAltMissing']}",
        f"- Ses alanı bulunmayan: {summary['audioAbsent']}",
        f"- İnceleme durumları: {json.dumps(statuses, ensure_ascii=False, sort_keys=True)}",
        f"- Öncelikler: {json.dumps(priorities, ensure_ascii=False, sort_keys=True)}",
        "",
        "## Öncelikli kayıtlar",
        "",
        "| Öncelik | Durum | Kimlik | Banka | Soru | Kaynak |",
        "|---|---|---|---|---|---|",
    ]
    for row in records[:100]:
        prompt = str(row["prompt"]).replace("|", "\\|").replace("\n", " ")
        source = str(row["sourceTitle"]).replace("|", "\\|") or "—"
        lines.append(
            f"| {row['priority']} | {row['reviewStatus']} | `{row['id']}` | "
            f"`{row['bank']}` | {prompt} | {source} |"
        )
    duplicate_reviews = report["reviewedDuplicateGroups"]
    lines.extend(["", "## İncelenmiş aynı hedef grupları", "",
        f"Yan rapor durumu: `{duplicate_reviews['status']}`. Üretim kaydı elenmez; kalite uyarıları bastırılmaz.", ""])
    for group in duplicate_reviews["groups"]:
        lines.append(f"- `{group['groupId']}`: `{group['status']}`; "
            f"üye={len(group['members'])}; incelenmemiş prompt eşleşmesi={len(group['unreviewedPromptMatches'])}.")
    lines.extend(["", "Tam kayıt kuyruğu ve hash doğrulamaları JSON çıktısındadır.", ""])
    output_base.with_suffix(".md").write_text("\n".join(lines), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--manifest", type=Path)
    parser.add_argument(
        "--output-base",
        type=Path,
        default=Path("docs/audit/product_2026_09_05/editorial_queue"),
    )
    args = parser.parse_args(argv)
    root = args.root.resolve()
    manifest = args.manifest.resolve() if args.manifest else None
    output_base = args.output_base
    if not output_base.is_absolute():
        output_base = root / output_base
    try:
        report = build_report(root, manifest)
        write_outputs(report, output_base)
    except AuditError as exc:
        print(f"editorial_queue: {exc}", file=sys.stderr)
        return 1
    summary = report["summary"]
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
