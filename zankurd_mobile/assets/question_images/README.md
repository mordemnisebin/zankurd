# Question Images

Real question images should be placed in this folder with the same slug used by the question bank.

Examples:

- `newroz.png`
- `dengbej.png`
- `kilim_motifleri.png`
- `mezopotamya.png`

The app references local images with:

```text
asset://assets/question_images/<slug>.png
```

## Import Real Images

Put the real image files in any folder, then run from `zankurd_mobile/`:

```powershell
python tools/import_question_images.py C:\path\to\real-images
flutter test test/question_bank_test.dart
```

The import script accepts `.png`, `.jpg`, `.jpeg`, and `.webp`. It writes normalized `900x520` PNG files into this folder. The question bank test fails if any local image reference points to a missing file.
