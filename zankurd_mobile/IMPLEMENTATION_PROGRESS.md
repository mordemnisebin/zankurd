# ZanKurd doğrulama durumu

Bu dosya sabit test sayısı veya yüzdelik ilerleme iddiası taşımaz; bunlar hızla
eskir. Güncel yerel durumu proje kökünde şu kapılarla doğrulayın:

```powershell
dart analyze
python tool/verify_and_fix_question_bank.py
dart run tool/question_quality/question_quality_audit.dart gate
flutter test --exclude-tags preview
flutter build web --release
flutter build apk --debug --no-pub
```

Canlı Supabase değişiklikleri, mağaza imzalama ve dağıtım bu yerel kapılardan
ayrıdır; ilgili migration uygulanmadan ya da gerçek release imzası doğrulanmadan
"yayına hazır" kabul edilmez.
