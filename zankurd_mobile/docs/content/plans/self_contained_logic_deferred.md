# Kol A — kendi içinde çözülebilir mantık içeriği: DEFERRED

Durum: `DEFERRED_NO_RUNTIME_CATEGORY` (2026-08-06). Soru üretilmedi.

## Gerekçe

Runtime kategorileri sabit ve genel mantık için biri yok:

    Ziman, Cografya, Muzîk, Çand, Dîrok, Edebiyat, Siyaset, Paradigma,
    Teknolojî, Sînema

`Paradigma` genel mantık kategorisi DEĞİLDİR. İçeriği ölçüldü: jineolojî,
demokratik konfederalizm, toplumsal ekoloji, «Jin, jiyan, azadî» gibi
düşünsel ve toplumsal içerik. Mantık/örüntü/matematik sorusu oraya konursa
kategori anlamını kaybeder ve oyuncu bir kategoriden başka bir şey görür.

Yeni kategori açmak UI ve kategori sistemi değişikliği demektir; bu turda
kapsam dışı bırakıldı.

## Karar gerektiren nokta (kullanıcıya ait)

İki yol var; ikisi de teknik değil ürün kararı:

1. **Kategori sistemi genişletilsin** — mantık/akıl yürütme için yeni bir
   kategori (UI, ikon, çeviri, kategori testleri dâhil).
2. **İçerik mevcut bir kategoriye gerçekten uysun** — ör. `Ziman` içinde
   dil-mantığı (sözcük sıralama, dilbilgisi çıkarımı). Bu durumda içerik
   genel mantık değil DİL içeriği olur ve buna göre yazılmalıdır; runtime
   zaten `wordOrdering` tipini destekliyor.

İkinci yol yeni sistem gerektirmez ve `Ziman` bankanın en büyük kategorisi
(211 aktif soru). Ama içerik "mantık sorusu" olarak değil "dil sorusu"
olarak tasarlanmalıdır — aradaki fark kozmetik değil.

## Bu turda yapılmayan

Hiçbir mantık sorusu yazılmadı, hiçbir kategoriye zorla yerleştirilmedi ve
kategori sistemi değiştirilmedi.
