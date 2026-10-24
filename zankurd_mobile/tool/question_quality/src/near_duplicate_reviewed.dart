// Jüriyle incelenmiş yakın tekrar adayları (2026-10-24).
//
// Anahtar: kalite kapısının `near_duplicate_candidate` parmak izi
// (her iki sorunun kategori grubu + prompt + doğru cevap + şıklar +
// açıklama bileşenlerinden oluşan sıralı içerik imzası). Değer: çift
// ve karar gerekçesi. Aynı bilgiyi soran çiftlerin biri
// `retired_question_ids.dart`ta emeklidir.
const Map<String, String> reviewedNearDuplicates = {
  '7b786c03020da5612cab264561479b6f':
      "edit_ziman_0003 ~ baslangic_2026_10_06_0002: aynı bilgi (sesli harf sayısı); edit_ziman_0003 emekli (2026-10-23)",
  'e887c7528a31027346b8b27a891e796f':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0034: farklı bilgi: doğru cevaplar farklı",
  '07efec6f3659f937aa897f8b85329cd9':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0037: farklı bilgi: doğru cevaplar farklı",
  'f56c631288f497ffe7d9a242138b7425':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0038: farklı bilgi: doğru cevaplar farklı",
  'f8ab7859c9243859206db3e13acc4d87':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0039: farklı bilgi: doğru cevaplar farklı",
  'ec7a25d6c13abacd19d6e73262da4255':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0040: farklı bilgi: doğru cevaplar farklı",
  'd23c02677d39e2a1e52fa0e99d316d7b':
      "baslangic_2026_10_06_0036 ~ baslangic_2026_10_06_0042: farklı bilgi: doğru cevaplar farklı",
  'ed79051d8c0fcba3c16b265629735d29':
      "baslangic_2026_10_06_0048 ~ baslangic_2026_10_06_0056: farklı bilgi: doğru cevaplar farklı",
  'b1f5bccee9b4f73920fd09b39cec55fb':
      "baslangic_2026_10_06_0050 ~ baslangic_2026_10_06_0066: farklı bilgi: doğru cevaplar farklı",
  '3a4162266f282431b8d9268be914e165':
      "baslangic_2026_10_06_0036 ~ baslangic_2026_10_06_0069: farklı bilgi: doğru cevaplar farklı",
  'c0c618ae160a37111af5e9ce882a8ebf':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0070: farklı bilgi: doğru cevaplar farklı",
  'e8dc40efa1608150f7c2ec288019a14a':
      "baslangic_2026_10_06_0036 ~ baslangic_2026_10_06_0071: farklı bilgi: doğru cevaplar farklı",
  '4703b0877e3ce431ae10a21aa8ee4fa3':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0072: farklı bilgi: doğru cevaplar farklı",
  '48c60f9daa7f9add17305cd972caa717':
      "baslangic_2026_10_06_0041 ~ baslangic_2026_10_06_0073: farklı bilgi: doğru cevaplar farklı",
  '2636c77d42c990653519db69b51b5d81':
      "baslangic_2026_10_06_0041 ~ baslangic_2026_10_06_0074: farklı bilgi: doğru cevaplar farklı",
  'bda3bf83bd76f833308972b095f465b3':
      "baslangic_2026_10_06_0050 ~ baslangic_2026_10_06_0076: farklı bilgi: doğru cevaplar farklı",
  '4b920a901dae76dd1f44f2844b3f4651':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0095: farklı bilgi: doğru cevaplar farklı",
  '80eefd12ad8ca55f2a88ecf293bd3d95':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0096: farklı bilgi: doğru cevaplar farklı",
  '36d3863c926106c3a695248fd97ba381':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0097: farklı bilgi: doğru cevaplar farklı",
  '4778318041e84a8f2efacaded51dcef7':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0098: farklı bilgi: doğru cevaplar farklı",
  'dbcffdea2c4a82f7787659d529d23059':
      "baslangic_2026_10_06_0036 ~ baslangic_2026_10_06_0099: farklı bilgi: doğru cevaplar farklı",
  '8f707967e39fc2e3051692aab8f9d2ce':
      "bosluk_0111 ~ bosluk_0115: farklı bilgi (Grok + ana ajan)",
  'ff0eba85a6539c318185c9e8206bb7ad':
      "ds_cografya_0030 ~ ds_cografya_0017: aynı bilgi (Musul'dan geçen nehir); ds_cografya_0030 emekli (2026-10-24)",
  '4748e2497b970d9fb50185bd955d0cd5':
      "ds_cografya_0052 ~ ds_cografya_0058: farklı bilgi: doğru cevaplar farklı",
  '89d35abe542216ff7b15d37e1d14e298':
      "ds_cografya_0076 ~ ds_cografya_0087: farklı bilgi (Grok + ana ajan)",
  '4abafe2000a9271508aeb708e9e84fdd':
      "ds_cografya_0082 ~ ds_cografya_0084: farklı bilgi: doğru cevaplar farklı",
  '8077c1d67bd06a26eda7ebd29b89c897':
      "ds_cografya_0081 ~ ds_cografya_0083: farklı bilgi: doğru cevaplar farklı",
  '421ab53ef40157c4405bc3ac9cc3d320':
      "ds_cografya_0081 ~ ds_cografya_0089: farklı bilgi (Grok + ana ajan)",
  '4f152b5117b4f2ca55a54368a11bc72e':
      "ds_cografya_0083 ~ ds_cografya_0093: farklı bilgi: doğru cevaplar farklı",
  'dc8f312753f183ef509dd50b91668a9e':
      "ds_cografya_0095 ~ ds_cografya_0099: farklı bilgi: doğru cevaplar farklı",
  'f63da27c666a1976b8c9016e9efecada':
      "ds_cografya_0180 ~ ds_cografya_0183: farklı bilgi: doğru cevaplar farklı",
  '0dba91d59821996dcaca57f514d7fbcd':
      "ds_cografya_0202 ~ ds_cografya_0212: farklı bilgi: doğru cevaplar farklı",
  '6ba24a8a84da1d41fcf9e6f10704c48a':
      "ds_dirok_0010 ~ ds_dirok_0016: farklı bilgi: doğru cevaplar farklı",
  'ff6d6a2a553b66cf9a3d6c90115735ea':
      "ds_dirok_0172 ~ ds_dirok_0174: farklı bilgi: doğru cevaplar farklı",
  '328008f6cd4cee0470a6767bd40b167e':
      "ds_edebiyat_0106 ~ ds_edebiyat_0108: farklı bilgi: doğru cevaplar farklı",
  '4bd88ed25f23e964b718b85db8292ce2':
      "ds_edebiyat_0106 ~ ds_edebiyat_0110: farklı bilgi: doğru cevaplar farklı",
  '78cb05447d3cd1e4916205f256e8b344':
      "ds_edebiyat_0106 ~ ds_edebiyat_0112: farklı bilgi: doğru cevaplar farklı",
  'd4dacc90e1f74cede09f756a3499b1b4':
      "ds_edebiyat_0106 ~ ds_edebiyat_0116: farklı bilgi: doğru cevaplar farklı",
  '2bb77a945c0db40d36fc725688d8db3c':
      "ds_edebiyat_0106 ~ ds_edebiyat_0122: farklı bilgi: doğru cevaplar farklı",
  '69eed95c2419e23212919c05b78c9103':
      "ds_edebiyat_0106 ~ ds_edebiyat_0124: farklı bilgi: doğru cevaplar farklı",
  'beec01e503e829ce9e5d34217cc440fd':
      "ds_edebiyat_0203 ~ ds_edebiyat_0206: farklı bilgi: doğru cevaplar farklı",
  '4c33e312c49a2d39fa15f01a4f1ec1ea':
      "ds_edebiyat_0203 ~ ds_edebiyat_0214: farklı bilgi: doğru cevaplar farklı",
  '626515a1b963f8a93903de48bebc6156':
      "ds_edebiyat_0203 ~ ds_edebiyat_0218: farklı bilgi: doğru cevaplar farklı",
  'a4a684eaac8fdffac7347bee0d4b05c1':
      "ds_edebiyat_0203 ~ ds_edebiyat_0220: farklı bilgi: doğru cevaplar farklı",
  '487a831de0ed72443210489f0ee1dfe4':
      "ds_edebiyat_0203 ~ ds_edebiyat_0222: farklı bilgi: doğru cevaplar farklı",
  'fbbda17cee829d138092ecf18c7a4b43':
      "ds_edebiyat_0203 ~ ds_edebiyat_0224: farklı bilgi: doğru cevaplar farklı",
  'e4c96bfc1f55846c1f7c4072b02dd9ea':
      "ds_muzik_0004 ~ ds_muzik_0009: farklı bilgi: doğru cevaplar farklı",
  'e5fe42f6dba90dd9b2e3f813f3aa95b3':
      "ds_muzik_0037 ~ ds_muzik_0045: farklı bilgi: doğru cevaplar farklı",
  '8f3a62b8e899d62a7e0d809146cdcfc0':
      "ds_muzik_0039 ~ ds_muzik_0047: farklı bilgi: doğru cevaplar farklı",
  'f702e76a7f3b1d115261213f1c82e751':
      "ds_muzik_0063 ~ ds_muzik_0061: farklı bilgi: doğru cevaplar farklı",
  '94753763cdb6046a719a110b43b52bd9':
      "ds_muzik_0109 ~ ds_muzik_0110: farklı bilgi: doğru cevaplar farklı",
  '8097f2765b61db5046befda2e1153f48':
      "ds_muzik_0109 ~ ds_muzik_0112: farklı bilgi: doğru cevaplar farklı",
  '4829293fe62aa4a55aaaec70e0ac019f':
      "ds_muzik_0127 ~ ds_muzik_0134: farklı bilgi: doğru cevaplar farklı",
  'c211da25b85850c6f27246146358caaf':
      "ds_muzik_0127 ~ ds_muzik_0145: farklı bilgi (Grok + ana ajan)",
  'afed6101347acdd34d3bdb5573041bb2':
      "ds_muzik_0132 ~ ds_muzik_0143: farklı bilgi: doğru cevaplar farklı",
  'f150e7cb319d394163844c577f50154f':
      "ds_muzik_0135 ~ ds_muzik_0150: farklı bilgi: doğru cevaplar farklı",
  '4c463676cf427cf8fc2876abdfbf3ae2':
      "ds_teknoloji_0035 ~ ds_teknoloji_0009: farklı bilgi: doğru cevaplar farklı",
  '030ab8b1c32d75636fc84db48a9aae51':
      "ds_teknoloji_0073 ~ ds_teknoloji_0066: farklı bilgi (Grok + ana ajan)",
  'b7211486fa74582259d7e6c1f5e7b6eb':
      "ds_teknoloji_0066 ~ ds_teknoloji_0054: farklı bilgi: doğru cevaplar farklı",
  '6977f1aad775533e23f7da2a0a54beb8':
      "ds_teknoloji_0073 ~ ds_teknoloji_0055: farklı bilgi: doğru cevaplar farklı",
  'e8ee82cd2f4dc08a4faa97daafa31d72':
      "ds_teknoloji_0083 ~ ds_teknoloji_0087: farklı bilgi: doğru cevaplar farklı",
  '27e60f11278a9e9b5e62da01d5025a90':
      "ds_teknoloji_0083 ~ ds_teknoloji_0093: farklı bilgi: doğru cevaplar farklı",
  'e52835c6fd2bc73820ad5842480a60c8':
      "ds_teknoloji_0236 ~ ds_teknoloji_0242: farklı bilgi (Grok + ana ajan)",
  'a9e05fec39324062bd709640c21894cd':
      "ds_teknoloji_0260 ~ ds_teknoloji_0266: farklı bilgi: doğru cevaplar farklı",
  'db37ac8530993ccc02ac607ba7ed1f5a':
      "ds_cand_0036 ~ ds_cand_0041: farklı bilgi (Grok + ana ajan)",
  'd1a820dced7f4aed4e06f838d37a3f73':
      "ds_cand_0090 ~ ds_cand_0096: farklı bilgi: doğru cevaplar farklı",
  '3d76783dd7bce3dc37b50b66b34b68a8':
      "ds_ziman_0027 ~ ds_ziman_1031: farklı bilgi: doğru cevaplar farklı",
  '58e66740553d5b0f0c5e275fcecd24d6':
      "ds_ziman_0027 ~ ds_ziman_0035: farklı bilgi: doğru cevaplar farklı",
  'ea69a5e3a490d83f646e4e3e5ee1349c':
      "ds_ziman_0027 ~ ds_ziman_0039: farklı bilgi: doğru cevaplar farklı",
  'cbabb36fbf7dd33f1c57a2c781f7b025':
      "ds_ziman_1106 ~ ds_ziman_0110: farklı bilgi: doğru cevaplar farklı",
  'b1d240f6b9f4a36170972beb666520dc':
      "ds_ziman_1106 ~ ds_ziman_0114: farklı bilgi: doğru cevaplar farklı",
  'daf825a1331485f57360078d7d75093a':
      "ds_ziman_1106 ~ ds_ziman_0121: farklı bilgi: doğru cevaplar farklı",
  '724a0a9a0e74e5bbd340ef586e09ff81':
      "ds_ziman_0150 ~ ds_ziman_0152: farklı bilgi: doğru cevaplar farklı",
  'f167d05599da60355efec3f23818e8b6':
      "ds_ziman_0150 ~ ds_ziman_0153: farklı bilgi: doğru cevaplar farklı",
  '17e7f6e8624d3ab31072185493e36635':
      "ds_cand_0007 ~ ds_cand_0021: farklı bilgi: doğru cevaplar farklı",
  '42238f4821e794a6b871a23b97930f15':
      "ds_cand_0084 ~ ds_cand_1090: farklı bilgi: doğru cevaplar farklı",
  '2aaf7e28f4da2f1709177284f8eb68cf':
      "ds_cand_1169 ~ ds_cand_0159: farklı bilgi: doğru cevaplar farklı",
  '3470a7e26784fb973c8141e3ee1a6cdb':
      "ds_cand_1169 ~ ds_cand_1165: farklı bilgi: doğru cevaplar farklı",
  'ce2892576c82e4c1f72846032ff24c23':
      "ds_cand_1169 ~ ds_cand_0251: farklı bilgi: doğru cevaplar farklı",
  '53592ea17adc28277b75ef9859308d8a':
      "ds_cand_0238 ~ ds_cand_0242: farklı bilgi: doğru cevaplar farklı",
  '96523981347bdd714335f1a0c934c987':
      "ds_cand_0226 ~ ds_cand_0240: farklı bilgi: doğru cevaplar farklı",
  '6d21a964d7e9610d4b9b4b009df2a4b2':
      "ds_cografya_0095 ~ ds_cografya_0076: farklı bilgi: doğru cevaplar farklı",
  'b5cea464070b253ce6ff217ebe43e80d':
      "ds_cografya_0109 ~ ds_cografya_0111: farklı bilgi: doğru cevaplar farklı",
  '5e9c8270896c621a48dcd09f782c8f11':
      "ds_cografya_0109 ~ ds_cografya_0113: farklı bilgi: doğru cevaplar farklı",
  'a86d9ec928ffe8c86bc8e5ebd262bebc':
      "ds_cografya_0109 ~ ds_cografya_0115: farklı bilgi: doğru cevaplar farklı",
  'af87cba0d1219787a0d44a661174a660':
      "ds_cografya_0109 ~ ds_cografya_0119: farklı bilgi: doğru cevaplar farklı",
  '45702bfaa6979ea02f0a87363210542d':
      "ds_cografya_0109 ~ ds_cografya_0125: farklı bilgi: doğru cevaplar farklı",
  'eecba40a04a7ad5d5a6d6156b49c65ed':
      "ds_cografya_0205 ~ ds_cografya_0223: farklı bilgi: doğru cevaplar farklı",
  '62d9547a9922a693b31637703dd2f075':
      "ds_dirok_0055 ~ ds_dirok_0072: farklı bilgi: doğru cevaplar farklı",
  '5a8e22005b7ed425e4092d586b0ce993':
      "ds_dirok_0055 ~ ds_dirok_0091: farklı bilgi: doğru cevaplar farklı",
  '7c4f99ad031101be8d308606a94b3a27':
      "ds_edebiyat_0114 ~ ds_edebiyat_0106: farklı bilgi: doğru cevaplar farklı",
  '9b1269a60918da038c2062d497d1c08f':
      "ds_edebiyat_0207 ~ ds_edebiyat_0213: farklı bilgi: doğru cevaplar farklı",
  '8242a540e648ed082e44ec21dbf2351b':
      "ds_edebiyat_0207 ~ ds_edebiyat_0221: farklı bilgi: doğru cevaplar farklı",
  '0a2d96a27943ad634cc127161944a66a':
      "ds_cografya_0007 ~ ds_cografya_0030: farklı bilgi: doğru cevaplar farklı",
  '78f82fafc07ab266b15431cde8f09eb9':
      "ds_cografya_0109 ~ ds_cografya_0101: farklı bilgi: doğru cevaplar farklı",
  'd3bab71dd9f146100bf719b73bef3bf7':
      "ds_cografya_0109 ~ ds_cografya_0103: farklı bilgi: doğru cevaplar farklı",
  'ae98a6426e4a1dab1b365d7ba5888d04':
      "ds_cografya_0102 ~ ds_cografya_0104: farklı bilgi: doğru cevaplar farklı",
  '4714da7a93baa5c96245ddc7fad7d371':
      "ds_cografya_0109 ~ ds_cografya_0107: farklı bilgi: doğru cevaplar farklı",
  'b9f0bfd61f697298c27cf1c69c6dbe8f':
      "ds_cografya_0106 ~ ds_cografya_0108: farklı bilgi: doğru cevaplar farklı",
  'edaad810403b1c6b94b6c3115665c513':
      "ds_cografya_0106 ~ ds_cografya_0112: farklı bilgi: doğru cevaplar farklı",
  '66fdd962b68adffb0e72053e560f6480':
      "ds_cografya_0106 ~ ds_cografya_0114: farklı bilgi: doğru cevaplar farklı",
  'efac58f0b0f1127c3632a6e42db0f788':
      "ds_cografya_0109 ~ ds_cografya_0117: farklı bilgi: doğru cevaplar farklı",
  'cfb50a89f454d31a1498ee423bb6f514':
      "ds_cografya_0106 ~ ds_cografya_0118: farklı bilgi: doğru cevaplar farklı",
  'f6aa67ec6e19971e55739ba7ce0e85e5':
      "ds_cografya_0116 ~ ds_cografya_0120: farklı bilgi: doğru cevaplar farklı",
  'e54221f76de9edd14d2e3e9c91cfb8d7':
      "ds_cografya_0106 ~ ds_cografya_0122: farklı bilgi: doğru cevaplar farklı",
  'a7750a993490f055d47a9d4603df3792':
      "ds_cografya_0109 ~ ds_cografya_0123: farklı bilgi: doğru cevaplar farklı",
  '14cf71d880fab9c9bfc8ab145be7acb8':
      "ds_cografya_0106 ~ ds_cografya_0124: farklı bilgi: doğru cevaplar farklı",
  'ec0e3d8709214663c10691c48d446925':
      "ds_cografya_0129 ~ ds_cografya_0133: aynı bilgi; biri emekli (Grok + ana ajan)",
  '5464f0baf0eabbc579f31e5721c72b1c':
      "ds_cografya_0152 ~ ds_cografya_0154: farklı bilgi: doğru cevaplar farklı",
  '4c879ef2ce55e34f89ca85c854822608':
      "ds_cografya_0192 ~ ds_cografya_0179: farklı bilgi: doğru cevaplar farklı",
  '911a1435e537a7b70fabdc242d63fe5d':
      "ds_cografya_0205 ~ ds_cografya_0218: farklı bilgi: doğru cevaplar farklı",
  'e6d4bb48ce304990114bae5eed672a27':
      "ds_dirok_0131 ~ ds_dirok_0145: farklı bilgi: doğru cevaplar farklı",
  '538564be48aaf873a5604c799e229c4b':
      "ds_muzik_0015 ~ ds_muzik_0023: farklı bilgi: doğru cevaplar farklı",
  'edd987660690a821b05ed61b0c0cbecb':
      "ds_muzik_0008 ~ ds_muzik_0011: farklı bilgi: doğru cevaplar farklı",
  '5e04d6ea574902eaa99f40178262d89d':
      "ds_muzik_0102 ~ ds_muzik_0101: farklı bilgi: doğru cevaplar farklı",
  '35169b18fc0b7ea744a93cdee94eaa3a':
      "ds_muzik_0133 ~ ds_muzik_0144: aynı bilgi; biri emekli (Grok + ana ajan)",
  'c7821071e801bab974cba24e35f19263':
      "ds_muzik_0195 ~ ds_muzik_0182: farklı bilgi: doğru cevaplar farklı",
  '795308e4b4c86626a358c5a41360cf5e':
      "ds_teknoloji_0073 ~ ds_teknoloji_0068: farklı bilgi: doğru cevaplar farklı",
  '72cef56864b185bfd068e3615508c78d':
      "ds_teknoloji_0073 ~ ds_teknoloji_0071: farklı bilgi: doğru cevaplar farklı",
  'b47d5abc510a80e62cee0a2ef27dcecc':
      "ds_teknoloji_0066 ~ ds_teknoloji_0060: farklı bilgi: doğru cevaplar farklı",
  '2597c290732da0f1e3990d57d338ca95':
      "ds_teknoloji_0084 ~ ds_teknoloji_0084: aynı kimliğin iki kaynaktaki kopyası; çalışma anında kimliğe göre tek",
  '32aec94547f85cf5302409cf091db485':
      "ds_teknoloji_0088 ~ ds_teknoloji_0088: aynı kimliğin iki kaynaktaki kopyası; çalışma anında kimliğe göre tek",
  'eb33223db47b499c9a7fd63a3831e89e':
      "ds_teknoloji_0177 ~ ds_teknoloji_0189: farklı bilgi: doğru cevaplar farklı",
  '6d9bca897ca339bfa52fb627869abdc7':
      "ds_teknoloji_0191 ~ ds_teknoloji_0191: aynı kimliğin iki kaynaktaki kopyası; çalışma anında kimliğe göre tek",
  '328c5da664e8690f0642791e49b200ec':
      "ds_teknoloji_0187 ~ ds_teknoloji_0195: farklı bilgi: doğru cevaplar farklı",
  '3ed7a8434dbec92e247773ab18219bc4':
      "ds_teknoloji_0177 ~ ds_teknoloji_0197: farklı bilgi: doğru cevaplar farklı",
  '059f7a0bebe231bfc63e6026b46c70cf':
      "ds_teknoloji_0269 ~ ds_teknoloji_0273: farklı bilgi: doğru cevaplar farklı",
  '80ed31d20b35c7065fcee95115f9f47d':
      "ds_cand_0036 ~ ds_cand_0028: farklı bilgi: doğru cevaplar farklı",
  'b7e142aee1308bb75ad053d596f81898':
      "ds_cand_0005 ~ ds_cand_0016: farklı bilgi: doğru cevaplar farklı",
  'e5a2101446f993bde7c6cae8f23e813f':
      "ds_cand_0018 ~ ds_cand_0012: farklı bilgi: doğru cevaplar farklı",
  'a49844452b813b19d1900f7f68cd166d':
      "ds_cand_0092 ~ ds_cand_0092: aynı kimliğin iki kaynaktaki kopyası; çalışma anında kimliğe göre tek",
  '7ac7f375003714f529e24bf46177426d':
      "ds_cand_0235 ~ ds_cand_0235: aynı kimliğin iki kaynaktaki kopyası; çalışma anında kimliğe göre tek",
  'b058e9300749f4ed07590abd4b4a6607':
      "ds_cand_0207 ~ ds_cand_0239: farklı bilgi: doğru cevaplar farklı",
  'a4c492bfa03bb7c3310f6751d1223d48':
      "dersler2_2026_10_08_0020 ~ dersler2_2026_10_08_0021: farklı bilgi: doğru cevaplar farklı",
  'f66a6bb1b3487ceba9639b70b5344a66':
      "dersler2_2026_10_08_0020 ~ dersler2_2026_10_08_0022: farklı bilgi: doğru cevaplar farklı",
  '7c7cd10d477ec692ce9edfea1b040ff3':
      "dersler2_2026_10_08_0020 ~ dersler2_2026_10_08_0023: farklı bilgi: doğru cevaplar farklı",
  '0388fcee5b958231e38d2435746dc39e':
      "dersler2_2026_10_08_0020 ~ dersler2_2026_10_08_0024: farklı bilgi: doğru cevaplar farklı",
  '3298a73bcdd5a13a9e4a253d71641730':
      "dersler2_2026_10_08_0020 ~ dersler2_2026_10_08_0025: farklı bilgi: doğru cevaplar farklı",
  'c6369589ae40fef554d10942f90096e5':
      "baslangic_2026_10_06_0033 ~ dersler2_2026_10_08_0047: farklı bilgi: doğru cevaplar farklı",
  '171c922e52a50454cfea63b99c011b33':
      "dersler2_2026_10_08_0059 ~ dersler2_2026_10_08_0061: farklı bilgi: doğru cevaplar farklı",
  'e9cbf90ab4a8d22fb659182b9e1e1054':
      "dersler2_2026_10_08_0063 ~ dersler2_2026_10_08_0064: farklı bilgi: doğru cevaplar farklı",
  '582bc93b262b39eb4d1f48a93e1ae947':
      "baslangic_2026_10_06_0068 ~ dersler3_2026_10_08_0008: aynı bilgi; biri emekli (Grok + ana ajan)",
  '5c99acc7ed4f7d6215be5e550de33509':
      "dersler2_2026_10_08_0081 ~ dersler3_2026_10_08_0023: farklı bilgi: doğru cevaplar farklı",
  '5de9b19099106124df4f1be063b72b1a':
      "baslangic_2026_10_06_0033 ~ dersler3_2026_10_08_0043: farklı bilgi: doğru cevaplar farklı",
  '5cf44e32047c75e9097a41133bc37cf9':
      "baslangic_2026_10_06_0094 ~ dersler3_2026_10_08_0044: farklı bilgi: doğru cevaplar farklı",
  '6cb03c4f3de415f5445e24a3a9b7d8db':
      "baslangic_2026_10_06_0033 ~ dersler3_2026_10_08_0047: farklı bilgi: doğru cevaplar farklı",
  '2610dae08e340adf90b60316616cb97d':
      "baslangic_2026_10_06_0050 ~ dersler3_2026_10_08_0062: farklı bilgi: doğru cevaplar farklı",
  '5bfedbfb7ee529ebddbc292a39db7dbd':
      "dersler3_2026_10_08_0132 ~ dersler3_2026_10_08_0066: farklı bilgi: doğru cevaplar farklı",
  'adaa32317c1e748db9f520ee54e372d3':
      "baslangic_2026_10_06_0050 ~ dersler3_2026_10_08_0080: farklı bilgi: doğru cevaplar farklı",
  'ccf648f6c14f1a2365084aef959407f3':
      "dersler3_2026_10_08_0007 ~ dersler3_2026_10_08_0081: farklı bilgi: doğru cevaplar farklı",
  'e6c29daf61154dce15f9dd617677b9ac':
      "ders_2026_10_01_0051 ~ dersler3_2026_10_08_0088: farklı bilgi: doğru cevaplar farklı",
  'f310b8388e67ab379b283b08eeca7455':
      "baslangic_2026_10_06_0033 ~ dersler3_2026_10_08_0098: farklı bilgi: doğru cevaplar farklı",
  '10d970482203cecf7726b448157e9dcb':
      "dersler3_2026_10_08_0107 ~ dersler3_2026_10_08_0108: farklı bilgi: doğru cevaplar farklı",
  'c60cf0797183e9007fb884abbd2453f6':
      "dersler3_2026_10_08_0107 ~ dersler3_2026_10_08_0109: farklı bilgi: doğru cevaplar farklı",
  'e7510f1720d1372e0dd7fd8c208871d5':
      "dersler3_2026_10_08_0133 ~ dersler3_2026_10_08_0138: farklı bilgi: doğru cevaplar farklı",
  '4484a58fc68fdc783733ff848192979d':
      "ds_dirok_0029 ~ edit_dirok_0001: aynı bilgi; biri emekli (Grok + ana ajan)",
  '9aba12358be157a9bbe31f1f1a6efb85':
      "ds_cografya_0235 ~ edit_cografya_0008: farklı bilgi: doğru cevaplar farklı",
  '68c49f0c86162959113ff666dbcd5e0f':
      "edit_cografya_0017 ~ edit_cografya_0013: farklı bilgi: doğru cevaplar farklı",
  '1d738f7fd6156aec3b528842d53cffc1':
      "edit_cografya_0017 ~ edit_cografya_0014: farklı bilgi: doğru cevaplar farklı",
  'd477289aeac34c90f53a9cbd9d1a1295':
      "edit_cografya_0017 ~ edit_cografya_0028: farklı bilgi: doğru cevaplar farklı",
  'bd7687409c927ca2ac8e3a24bdd3f428':
      "edit_cografya_0017 ~ edit_cografya_0033: farklı bilgi (Grok + ana ajan)",
  '1b015eaab8756979fe9b7b36843e6846':
      "edit_cografya_0017 ~ edit_cografya_0037: farklı bilgi: doğru cevaplar farklı",
  'b03f543d58e52a39ce294eda87ccd29a':
      "ex28_sinor_duma_002 ~ ex28_sinor_duma_003: farklı bilgi: doğru cevaplar farklı",
  'c85fa3742af482fd0cfd01b68ab457b1':
      "hat_0001 ~ hat_0007: farklı bilgi: doğru cevaplar farklı",
  'f5f511c5d8c988274982e3db5cafbc78':
      "hat_0007 ~ hat_0008: farklı bilgi: doğru cevaplar farklı",
  'ec3601b77e3196e2c9eabe11aca22153':
      "hat_0019 ~ hat_0020: farklı bilgi: doğru cevaplar farklı",
  '6fe51ca036cc17484fdef3852b28ccfe':
      "ex28_yilmaz_guney_005 ~ hat_0043: aynı bilgi; biri emekli (Grok + ana ajan)",
  '86df564c81b1fb0f753ee591ee03ae8f':
      "ds_cografya_0007 ~ hat_0062: farklı bilgi: doğru cevaplar farklı",
  '52bb4a9643b9b5fb989142ebb338542b':
      "ds_cografya_0030 ~ hat_0071: farklı bilgi (Grok + ana ajan)",
  '5cd623ee48f1dc24049ce25c4c872918':
      "hat_0081 ~ hat_0084: farklı bilgi: doğru cevaplar farklı",
  '569a57e90483b13f9f156e63efa4bc32':
      "hat_0092 ~ hat_0097: farklı bilgi: doğru cevaplar farklı",
  'd5e74f1142ff5aceefe00bd32c916f2b':
      "hat_0104 ~ hat_0109: aynı bilgi; biri emekli (Grok + ana ajan)",
  '5b25fb12f59c8f01ab997f05d1a58a26':
      "hat_0105 ~ hat_0112: aynı bilgi; biri emekli (Grok + ana ajan)",
  'e9c1dbf380d7feb135f81b40725c93d4':
      "hat_0107 ~ hat_0118: aynı bilgi; biri emekli (Grok + ana ajan)",
  '134cd48a2cd10391ff4b7ef05d5cc2a2':
      "offline_0748 ~ offline_0756: farklı bilgi: doğru cevaplar farklı",
  '7da0ebbf325c25d9a459388c8de8103b':
      "offline_2092 ~ offline_2106: farklı bilgi: doğru cevaplar farklı",
  '522b62671fd9ca5c05a5855ab8b53222':
      "edit_cografya_0017 ~ offline_2175: farklı bilgi: doğru cevaplar farklı",
  'a48ff1fe9005d4d1e2361a6c5c1a4e1c':
      "edit_cografya_0017 ~ offline_2354: farklı bilgi: doğru cevaplar farklı",
  'a3935f8939d50829d3f285807eaf71e4':
      "edit_dirok_0028 ~ offline_2668: farklı bilgi: doğru cevaplar farklı",
  '313f4f0f57687faba6b35cebeada6071':
      "ds_cografya_0005 ~ restore_2026_08_07_0007: farklı bilgi: doğru cevaplar farklı",
  '4235bbbb016988b89cd09a60f2766ee0':
      "edit_cografya_0017 ~ restore_2026_08_07_0014: farklı bilgi: doğru cevaplar farklı",
  '9f0d334bb50108f58b4c13e1b0f2883f':
      "edit_cografya_0031 ~ restore_2026_08_07_0015: farklı bilgi: doğru cevaplar farklı",
  'a8d64c44017542a43a82b7c9e2b4d57b':
      "sf_nat_0006 ~ sf_nat_0007: farklı bilgi: doğru cevaplar farklı",
  '1ed6b714dfc51753f8a6d3021b0ec73b':
      "baslangic_2026_10_06_0002 ~ ziman_x_0005: farklı bilgi (dengdêr sayısı 8 / bütün tîp sayısı 31)",
};
