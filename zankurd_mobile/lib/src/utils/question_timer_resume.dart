/// Arka plandan dönüldüğünde soru sayacı sürdürülmeli mi?
///
/// ## Kusur
///
/// Bu karar bir zamanlar iki koşuldan ibaretti: sayaç DURUYOR ve değeri
/// sıfırdan büyük. Koşul, "duruyorsa demek ki duraklatılmıştır" varsayımına
/// dayanıyordu ve o varsayım yanlıştı.
///
/// `AnimationController` 1.0 değeriyle kurulur. Yani soru daha AÇILMAMIŞKEN
/// de sayaç "duruyor" ve "değeri sıfırdan büyük"tür. Soru açılışı gerçekten
/// bekleyebilir: görselli sorularda akış görsel yüklenene kadar kapıda
/// durur, ilk turda oyuncu iki adımlı rehber örtüsünü okur. O pencerede
/// uygulamayı arka plana atıp dönen oyuncunun sayacı başlıyordu — soru
/// ekranda yokken süre işliyor, yavaş bir görselde soru hiç görülmeden
/// süresi dolabiliyordu (2026-08-12 denetimi).
///
/// Sessizdi çünkü mutlu yol kusursuzdu: soru açıldıktan sonra duraklat ve
/// sürdür doğru çalışıyordu, testlerin hepsi soruyu açılmış hâlde kuruyordu.
///
/// Doğru ölçüt "duruyor mu" değil, **"biz mi durdurduk"**. [pausedByLifecycle]
/// yalnız uygulama arka plana giderken işleyen bir sayacı durdurduğumuzda
/// doğrudur; başka hiçbir yol onu doğru yapmaz.
///
/// Kalan iki koşul korunuyor: arada başka bir yol sayacı yeniden başlattıysa
/// ([isAnimating]) ikinci kez başlatmayız, ve süresi dolmuş bir sayacı
/// ([timerValue] sıfır) sürdürmeyiz — onun sonu ayrı bir yolda karara bağlanır.
bool shouldResumeQuestionTimer({
  required bool pausedByLifecycle,
  required bool isAnimating,
  required double timerValue,
}) {
  if (!pausedByLifecycle) return false;
  if (isAnimating) return false;
  return timerValue > 0;
}
