// Jüriyle incelenmiş yakın tekrar adayları (2026-10-22).
//
// Anahtar: kalite kapısının `near_duplicate_candidate` parmak izi (ikinci
// sorunun kategori grubu + normalize metni). Metin değişirse parmak izi
// değişir ve çift yeniden uyarı olur. Değer: çift ve karar gerekçesi.
// Aynı bilgiyi soran çiftlerin biri `retired_question_ids.dart`ta emeklidir.
const Map<String, String> reviewedNearDuplicates = {
  '7180533b7192c919331a20b7f75e30f5':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0034: farklı bilgi: doğru cevaplar farklı",
  '5264d0024b2ccf52ebb9978dd05c3829':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0037: farklı bilgi: doğru cevaplar farklı",
  '5a380f5efd0b4e6e23675b7b90353d9b':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0038: farklı bilgi: doğru cevaplar farklı",
  'bb167156b6910492c8db33429f1baa35':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0039: farklı bilgi: doğru cevaplar farklı",
  '97d04a9fc8893666fdbdc87a3ca1e408':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0040: farklı bilgi: doğru cevaplar farklı",
  '5077ee7b17453f666adec5ff79147df5':
      "baslangic_2026_10_06_0036 ~ baslangic_2026_10_06_0042: farklı bilgi: doğru cevaplar farklı",
  '2385010039cf8629e65219983db4a583':
      "baslangic_2026_10_06_0048 ~ baslangic_2026_10_06_0056: farklı bilgi: doğru cevaplar farklı",
  'ad438a5f1d22ee66f78c3f5e571206a7':
      "baslangic_2026_10_06_0050 ~ baslangic_2026_10_06_0066: farklı bilgi: doğru cevaplar farklı",
  '7246da0020c9a56ab08c54334fb58734':
      "baslangic_2026_10_06_0036 ~ baslangic_2026_10_06_0069: farklı bilgi: doğru cevaplar farklı",
  '4f07567cd134f947a89fa707083f56de':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0070: farklı bilgi: doğru cevaplar farklı",
  'be591e3821ada1a551cd6aaf5b952aab':
      "baslangic_2026_10_06_0036 ~ baslangic_2026_10_06_0071: farklı bilgi: doğru cevaplar farklı",
  '72d4a04527e0836428214a14003731bb':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0072: farklı bilgi: doğru cevaplar farklı",
  '6eb3a14096347a36dc1913c4903572e4':
      "baslangic_2026_10_06_0041 ~ baslangic_2026_10_06_0073: farklı bilgi: doğru cevaplar farklı",
  '8f614b5ab9b1af0d8267b335d3f5075e':
      "baslangic_2026_10_06_0041 ~ baslangic_2026_10_06_0074: farklı bilgi: doğru cevaplar farklı",
  '6ebd8bccadd9cb8a78adf86fa6b54a70':
      "baslangic_2026_10_06_0050 ~ baslangic_2026_10_06_0076: farklı bilgi: doğru cevaplar farklı",
  '95b3f62d5b9952fc2a7633d7d5ea9f10':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0095: farklı bilgi: doğru cevaplar farklı",
  'b228861298a67e6a96ac1cd91423d98b':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0096: farklı bilgi: doğru cevaplar farklı",
  'd8748ce26cd0944864cfeaadadfeeaa3':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0097: farklı bilgi: doğru cevaplar farklı",
  'b790ae9b6dd56eeabbe79568ce86dd7c':
      "baslangic_2026_10_06_0033 ~ baslangic_2026_10_06_0098: farklı bilgi: doğru cevaplar farklı",
  '33dec36bf7142b8daa495b046bf065fe':
      "baslangic_2026_10_06_0036 ~ baslangic_2026_10_06_0099: farklı bilgi: doğru cevaplar farklı",
  '06787e1e2852a34ad712c06d5401ab11':
      "bosluk_0111 ~ bosluk_0115: farklı bilgi (Grok + ana ajan)",
  '776446ef8b512b1ff07b2b9c213a6114':
      "ds_cografya_0030 ~ ds_cografya_0017: farklı bilgi: doğru cevaplar farklı",
  '231207ebdbb283b6fbd809d7a7f1242a':
      "ds_cografya_0052 ~ ds_cografya_0058: farklı bilgi: doğru cevaplar farklı",
  '8ce7abd80293e120a81d3b3860f4b580':
      "ds_cografya_0076 ~ ds_cografya_0087: farklı bilgi (Grok + ana ajan)",
  '6bea6b7173797234f9532c0620b454b3':
      "ds_cografya_0082 ~ ds_cografya_0084: farklı bilgi: doğru cevaplar farklı",
  '7a65878511915f32d327a0e2fbedf04b':
      "ds_cografya_0081 ~ ds_cografya_0083: farklı bilgi: doğru cevaplar farklı",
  '9b15a05db307294605101a99075c4db9':
      "ds_cografya_0081 ~ ds_cografya_0089: farklı bilgi (Grok + ana ajan)",
  '5e590e4fa83479cd52e7580b5fd65fb2':
      "ds_cografya_0083 ~ ds_cografya_0093: farklı bilgi: doğru cevaplar farklı",
  'e1cfea49ae85b6ce4379f27d41790db3':
      "ds_cografya_0095 ~ ds_cografya_0099: farklı bilgi: doğru cevaplar farklı",
  '6e59d28ea0df502eb75f8f80b6001d59':
      "ds_cografya_0180 ~ ds_cografya_0183: farklı bilgi: doğru cevaplar farklı",
  '08933284f4cb234bc37cdd19961b194a':
      "ds_cografya_0202 ~ ds_cografya_0212: farklı bilgi: doğru cevaplar farklı",
  'e813b908278eed1a8a89d159dbea5a75':
      "ds_dirok_0010 ~ ds_dirok_0016: farklı bilgi: doğru cevaplar farklı",
  '316f174b35f2ca056ad7bfaf13eabb11':
      "ds_dirok_0172 ~ ds_dirok_0174: farklı bilgi: doğru cevaplar farklı",
  '013357ed85c8f211e42a2fd9aff887b1':
      "ds_edebiyat_0106 ~ ds_edebiyat_0108: farklı bilgi: doğru cevaplar farklı",
  '39426fa64c1736b6c888fbc462c5c241':
      "ds_edebiyat_0106 ~ ds_edebiyat_0110: farklı bilgi: doğru cevaplar farklı",
  '36080af4020c5e4baf8ed80aeb5aaac0':
      "ds_edebiyat_0106 ~ ds_edebiyat_0112: farklı bilgi: doğru cevaplar farklı",
  'c9453fe2da6844f63281df21752a9545':
      "ds_edebiyat_0106 ~ ds_edebiyat_0116: farklı bilgi: doğru cevaplar farklı",
  '78471129f9e0b384a617f3e0db20b008':
      "ds_edebiyat_0106 ~ ds_edebiyat_0122: farklı bilgi: doğru cevaplar farklı",
  '13363a87f7f0f1e7972982069c4b2e63':
      "ds_edebiyat_0106 ~ ds_edebiyat_0124: farklı bilgi: doğru cevaplar farklı",
  '9dd97b427118784264956f9805de6801':
      "ds_edebiyat_0203 ~ ds_edebiyat_0206: farklı bilgi: doğru cevaplar farklı",
  '8cf269280a873cf2e2fd49c72da04614':
      "ds_edebiyat_0203 ~ ds_edebiyat_0214: farklı bilgi: doğru cevaplar farklı",
  '4ed3408a8ed716ea127e7ea988b1dd2a':
      "ds_edebiyat_0203 ~ ds_edebiyat_0218: farklı bilgi: doğru cevaplar farklı",
  '96f097d6a4c844b6af0e70e6c5ceb076':
      "ds_edebiyat_0203 ~ ds_edebiyat_0220: farklı bilgi: doğru cevaplar farklı",
  '9b1ff10b8471f22e0fc739068aaf7bd8':
      "ds_edebiyat_0203 ~ ds_edebiyat_0222: farklı bilgi: doğru cevaplar farklı",
  '55c87714c5be87ddb915f684b7701872':
      "ds_edebiyat_0203 ~ ds_edebiyat_0224: farklı bilgi: doğru cevaplar farklı",
  '79f8aeb4c08593ca9f3ea4731674476c':
      "ds_muzik_0004 ~ ds_muzik_0009: farklı bilgi: doğru cevaplar farklı",
  'a35853934b826f1a3cb71faa7ed3932d':
      "ds_muzik_0037 ~ ds_muzik_0045: farklı bilgi: doğru cevaplar farklı",
  '93b6e3e92f933e892b04ee3f0c3a72a1':
      "ds_muzik_0039 ~ ds_muzik_0047: farklı bilgi: doğru cevaplar farklı",
  '1c4fcc38277bd71a000b0eb123e34223':
      "ds_muzik_0063 ~ ds_muzik_0061: farklı bilgi: doğru cevaplar farklı",
  '102a7844b811db50bc60475a74a837ab':
      "ds_muzik_0109 ~ ds_muzik_0110: farklı bilgi: doğru cevaplar farklı",
  '6ae0c3fbc1fc6f4f75d6246b9fd6d0ff':
      "ds_muzik_0109 ~ ds_muzik_0112: farklı bilgi: doğru cevaplar farklı",
  'e1cf8c2a3f5a5c3c53e95c825fb08a1c':
      "ds_muzik_0127 ~ ds_muzik_0134: farklı bilgi: doğru cevaplar farklı",
  '9698613410e0012a65e52892c30bf4b1':
      "ds_muzik_0127 ~ ds_muzik_0145: farklı bilgi (Grok + ana ajan)",
  'e9b4e6dcd82e8c876b02a221d577c57a':
      "ds_muzik_0132 ~ ds_muzik_0143: farklı bilgi: doğru cevaplar farklı",
  '48cafeece0575bfd53a813e22aee0067':
      "ds_muzik_0135 ~ ds_muzik_0150: farklı bilgi: doğru cevaplar farklı",
  '6161f8f6f42d4c4ed4ed184c3d8ab067':
      "ds_teknoloji_0035 ~ ds_teknoloji_0009: farklı bilgi: doğru cevaplar farklı",
  'fd53bbad9abd644e58ceadf4690418bf':
      "ds_teknoloji_0073 ~ ds_teknoloji_0066: farklı bilgi (Grok + ana ajan)",
  '0eaaa11a348144d8265174d57fa47de5':
      "ds_teknoloji_0066 ~ ds_teknoloji_0054: farklı bilgi: doğru cevaplar farklı",
  '1c7fc748cff4204bdefb116af40bee26':
      "ds_teknoloji_0073 ~ ds_teknoloji_0055: farklı bilgi: doğru cevaplar farklı",
  'cc70aca1558a8b68bddee2e14bc3e524':
      "ds_teknoloji_0083 ~ ds_teknoloji_0087: farklı bilgi: doğru cevaplar farklı",
  '5a9cc9adb9753f59cb2d6d3d067a2dd5':
      "ds_teknoloji_0083 ~ ds_teknoloji_0093: farklı bilgi: doğru cevaplar farklı",
  '6f34eac48f496579644995f81d80b5cf':
      "ds_teknoloji_0236 ~ ds_teknoloji_0242: farklı bilgi (Grok + ana ajan)",
  '46817f6aace074c5cab6e7353fddd4a9':
      "ds_teknoloji_0260 ~ ds_teknoloji_0266: farklı bilgi: doğru cevaplar farklı",
  'ac0a640d93423fceb27466a5097e7ec9':
      "ds_cand_0036 ~ ds_cand_0041: farklı bilgi (Grok + ana ajan)",
  '450b5184d59c7d247713824f35dcb232':
      "ds_cand_0090 ~ ds_cand_0096: farklı bilgi: doğru cevaplar farklı",
  'a644342385c68ce21c2002c86763619c':
      "ds_ziman_0027 ~ ds_ziman_1031: farklı bilgi: doğru cevaplar farklı",
  '0b870b77c79a2b47cea041cbd7223bd2':
      "ds_ziman_0027 ~ ds_ziman_0035: farklı bilgi: doğru cevaplar farklı",
  'f181b7e5bf61d0a8955bd7df51ebc801':
      "ds_ziman_0027 ~ ds_ziman_0039: farklı bilgi: doğru cevaplar farklı",
  '051d84e974cafb30e590b9053d128804':
      "ds_ziman_1106 ~ ds_ziman_0110: farklı bilgi: doğru cevaplar farklı",
  'e16cd966b47e36f7a8c43fea53380d0b':
      "ds_ziman_1106 ~ ds_ziman_0114: farklı bilgi: doğru cevaplar farklı",
  '4961fb72943d428dd91ffa30023df12f':
      "ds_ziman_1106 ~ ds_ziman_0121: farklı bilgi: doğru cevaplar farklı",
  'e8c96badbdf515046146dd77ee1ba790':
      "ds_ziman_0150 ~ ds_ziman_0152: farklı bilgi: doğru cevaplar farklı",
  '8390376489bdbccb2e919e56b58b8c89':
      "ds_ziman_0150 ~ ds_ziman_0153: farklı bilgi: doğru cevaplar farklı",
  '29bac9edf75d150d2d54f33d65ecad34':
      "ds_cand_0007 ~ ds_cand_0021: farklı bilgi: doğru cevaplar farklı",
  'd792e404c8ea704e78c21c7582cd0acc':
      "ds_cand_0084 ~ ds_cand_1090: farklı bilgi: doğru cevaplar farklı",
  '0089dc59c4fd2b4ac0d907fcdc1a427c':
      "ds_cand_1169 ~ ds_cand_0159: farklı bilgi: doğru cevaplar farklı",
  'b9fc2cf6441b241a297b3ef775d0b34a':
      "ds_cand_1169 ~ ds_cand_1165: farklı bilgi: doğru cevaplar farklı",
  '1d41b429585ad5413c6891859aac45a3':
      "ds_cand_1169 ~ ds_cand_0251: farklı bilgi: doğru cevaplar farklı",
  '4ef7788a689d580a5bf2f0116e2e066a':
      "ds_cand_0238 ~ ds_cand_0242: farklı bilgi: doğru cevaplar farklı",
  '8f0690c1086c9a2d7cac48971f376d49':
      "ds_cand_0226 ~ ds_cand_0240: farklı bilgi: doğru cevaplar farklı",
  '787a43538237a11c9ac0f376c5ce7e7c':
      "ds_cografya_0095 ~ ds_cografya_0076: farklı bilgi: doğru cevaplar farklı",
  '03d46220a1bd7805748492ea45702c48':
      "ds_cografya_0109 ~ ds_cografya_0111: farklı bilgi: doğru cevaplar farklı",
  'd81f05001ebb6e29ba8377fb0daafcee':
      "ds_cografya_0109 ~ ds_cografya_0113: farklı bilgi: doğru cevaplar farklı",
  '4b922028f4a9b4a4e6aee278d5b29d0c':
      "ds_cografya_0109 ~ ds_cografya_0115: farklı bilgi: doğru cevaplar farklı",
  '90afdc336d8fb5b5ff0762bf434d13a7':
      "ds_cografya_0109 ~ ds_cografya_0119: farklı bilgi: doğru cevaplar farklı",
  '339cf72b7f258659b1ac4003f700d307':
      "ds_cografya_0109 ~ ds_cografya_0125: farklı bilgi: doğru cevaplar farklı",
  '64b6e4849d571988e1ecc0fccf4e2858':
      "ds_cografya_0205 ~ ds_cografya_0223: farklı bilgi: doğru cevaplar farklı",
  'd18772f137cd64050056751b36ef645f':
      "ds_dirok_0055 ~ ds_dirok_0072: farklı bilgi: doğru cevaplar farklı",
  '308cb1862f4535c1032f8415c29e90ea':
      "ds_dirok_0055 ~ ds_dirok_0091: farklı bilgi: doğru cevaplar farklı",
  '36dab43fbfb406557d48d3f891b34cee':
      "ds_edebiyat_0114 ~ ds_edebiyat_0106: farklı bilgi: doğru cevaplar farklı",
  '58697412fbde436b466ab3fec9a907c9':
      "ds_edebiyat_0207 ~ ds_edebiyat_0213: farklı bilgi: doğru cevaplar farklı",
  '77c89401f36726e645006e3b8fdbcfa4':
      "ds_edebiyat_0207 ~ ds_edebiyat_0221: farklı bilgi: doğru cevaplar farklı",
  '800bcfbd240a0966b87ca5317d32bfbf':
      "ds_cografya_0007 ~ ds_cografya_0030: farklı bilgi: doğru cevaplar farklı",
  '746048dc1fadb4198f1a2bdfc8760c6a':
      "ds_cografya_0109 ~ ds_cografya_0101: farklı bilgi: doğru cevaplar farklı",
  'f42bbd85828aa566aa846ede917718dd':
      "ds_cografya_0109 ~ ds_cografya_0103: farklı bilgi: doğru cevaplar farklı",
  'a3bba3805ab2674f9c7b1e4339294462':
      "ds_cografya_0102 ~ ds_cografya_0104: farklı bilgi: doğru cevaplar farklı",
  '03a6e53634d278cc33157c8f051165a4':
      "ds_cografya_0109 ~ ds_cografya_0107: farklı bilgi: doğru cevaplar farklı",
  'a7ed098d7384278dea365fd0723fd995':
      "ds_cografya_0106 ~ ds_cografya_0108: farklı bilgi: doğru cevaplar farklı",
  'ec80a1a0afae5e9fc37757aa39d6ebd7':
      "ds_cografya_0106 ~ ds_cografya_0112: farklı bilgi: doğru cevaplar farklı",
  'baf95478e142ff26d9cc58302d0d7d0d':
      "ds_cografya_0106 ~ ds_cografya_0114: farklı bilgi: doğru cevaplar farklı",
  '0b341f84a4622ef6b1819af2f270f7d7':
      "ds_cografya_0109 ~ ds_cografya_0117: farklı bilgi: doğru cevaplar farklı",
  'd96a487d42eb25b1e985396252dabdcb':
      "ds_cografya_0106 ~ ds_cografya_0118: farklı bilgi: doğru cevaplar farklı",
  '6aa96ef51061d4585a640d56e0ce8763':
      "ds_cografya_0116 ~ ds_cografya_0120: farklı bilgi: doğru cevaplar farklı",
  '102e41c961b930c3efd5dd9168a98a5e':
      "ds_cografya_0106 ~ ds_cografya_0122: farklı bilgi: doğru cevaplar farklı",
  '6f4ab6ca84c401dd25ff94613ad97877':
      "ds_cografya_0109 ~ ds_cografya_0123: farklı bilgi: doğru cevaplar farklı",
  '3b2b997ee123f949ab345a4325f88941':
      "ds_cografya_0106 ~ ds_cografya_0124: farklı bilgi: doğru cevaplar farklı",
  'cfccad2fd1edf8c5ecd826c1fa70ee41':
      "ds_cografya_0129 ~ ds_cografya_0133: farklı bilgi (Grok + ana ajan)",
  '7fceb00a2fbe4f5c9a3470f6b22f2322':
      "ds_cografya_0152 ~ ds_cografya_0154: farklı bilgi: doğru cevaplar farklı",
  '5cbd478e04609581745f63ae7206f2d3':
      "ds_cografya_0192 ~ ds_cografya_0179: farklı bilgi: doğru cevaplar farklı",
  '6ad0833e5d6376ceb1d0c5cf163065c0':
      "ds_cografya_0205 ~ ds_cografya_0218: farklı bilgi: doğru cevaplar farklı",
  '636f8e2500558e279f4540fbe41d28a5':
      "ds_dirok_0131 ~ ds_dirok_0145: farklı bilgi: doğru cevaplar farklı",
  'b9c005cb8d396c2ff0bda7bae6ea5978':
      "ds_muzik_0015 ~ ds_muzik_0023: farklı bilgi: doğru cevaplar farklı",
  '136950e9eb21214edffc9805ba66eb25':
      "ds_muzik_0008 ~ ds_muzik_0011: farklı bilgi: doğru cevaplar farklı",
  'c0827ecd4cf3d3dd097f550709651ff0':
      "ds_muzik_0102 ~ ds_muzik_0101: farklı bilgi: doğru cevaplar farklı",
  'c0bdcb60162f60a0e077fd7a72673483':
      "ds_muzik_0133 ~ ds_muzik_0144: aynı bilgi; biri emekli (Grok + ana ajan)",
  'c27e2b72fcbf1b4914eb48d2333369a7':
      "ds_muzik_0195 ~ ds_muzik_0182: farklı bilgi: doğru cevaplar farklı",
  '9ca838cafe03bf9dfcbcfd70eb6a983e':
      "ds_teknoloji_0073 ~ ds_teknoloji_0068: farklı bilgi: doğru cevaplar farklı",
  '35331723cd0f1537ed6d34796c25346b':
      "ds_teknoloji_0073 ~ ds_teknoloji_0071: farklı bilgi: doğru cevaplar farklı",
  '152d9517cc70f441487b85617798e55d':
      "ds_teknoloji_0066 ~ ds_teknoloji_0060: farklı bilgi: doğru cevaplar farklı",
  '878baefe72ae5e402f8aa5988dbf3225':
      "ds_teknoloji_0084 ~ ds_teknoloji_0084: aynı kimliğin iki kaynaktaki kopyası; çalışma anında kimliğe göre tek",
  '5d1a62eb2bb4bf31a12125628b80077d':
      "ds_teknoloji_0088 ~ ds_teknoloji_0088: aynı kimliğin iki kaynaktaki kopyası; çalışma anında kimliğe göre tek",
  '206963a7c6a4f037e6dd4f33df52318d':
      "ds_teknoloji_0177 ~ ds_teknoloji_0189: farklı bilgi: doğru cevaplar farklı",
  'e789196e100d4b43390ea904abdb18ff':
      "ds_teknoloji_0191 ~ ds_teknoloji_0191: aynı kimliğin iki kaynaktaki kopyası; çalışma anında kimliğe göre tek",
  '53ad3c1d409472d76313aab27ad493ca':
      "ds_teknoloji_0187 ~ ds_teknoloji_0195: farklı bilgi: doğru cevaplar farklı",
  '67fce737717f81844f354ca1ed65d07e':
      "ds_teknoloji_0177 ~ ds_teknoloji_0197: farklı bilgi: doğru cevaplar farklı",
  '0408ea18e9d279eec3135bf57005dcb8':
      "ds_teknoloji_0269 ~ ds_teknoloji_0273: farklı bilgi: doğru cevaplar farklı",
  'f40019f072006c0a0295e1665424ee76':
      "ds_cand_0036 ~ ds_cand_0028: farklı bilgi: doğru cevaplar farklı",
  'fa549202c57f3a25595e316b498e097b':
      "ds_cand_0005 ~ ds_cand_0016: farklı bilgi: doğru cevaplar farklı",
  'bca251fd5a6fdbd4dbc98632b02612e6':
      "ds_cand_0018 ~ ds_cand_0012: farklı bilgi: doğru cevaplar farklı",
  '3388278e7da55474946b4797a16f4fca':
      "ds_cand_0092 ~ ds_cand_0092: aynı kimliğin iki kaynaktaki kopyası; çalışma anında kimliğe göre tek",
  'dff46667d1d2bb84c125ec5de30f7280':
      "ds_cand_0235 ~ ds_cand_0235: aynı kimliğin iki kaynaktaki kopyası; çalışma anında kimliğe göre tek",
  'ef777923870d0416cbea958f49e7cf24':
      "ds_cand_0207 ~ ds_cand_0239: farklı bilgi: doğru cevaplar farklı",
  '2f1d2644527a127d7c4d3e3207ea08da':
      "dersler2_2026_10_08_0020 ~ dersler2_2026_10_08_0021: farklı bilgi: doğru cevaplar farklı",
  '45a9e0e6621375bd257fdf1561549521':
      "dersler2_2026_10_08_0020 ~ dersler2_2026_10_08_0022: farklı bilgi: doğru cevaplar farklı",
  '54da8975fe4486bccea92254688df7f6':
      "dersler2_2026_10_08_0020 ~ dersler2_2026_10_08_0023: farklı bilgi: doğru cevaplar farklı",
  'aef2106c39ca0d50abf5da41a7cd5100':
      "dersler2_2026_10_08_0020 ~ dersler2_2026_10_08_0024: farklı bilgi: doğru cevaplar farklı",
  '72110a5a8e2996505ba0d247dd04d2a6':
      "dersler2_2026_10_08_0020 ~ dersler2_2026_10_08_0025: farklı bilgi: doğru cevaplar farklı",
  'ef472713b25d6e66b8eb738ca7c22dd8':
      "baslangic_2026_10_06_0033 ~ dersler2_2026_10_08_0047: farklı bilgi: doğru cevaplar farklı",
  'ad6db8df0e1c056f079abbd864b94d8e':
      "dersler2_2026_10_08_0059 ~ dersler2_2026_10_08_0061: farklı bilgi: doğru cevaplar farklı",
  '219c4a59c7bf44a138bb84d9122b5bf5':
      "dersler2_2026_10_08_0063 ~ dersler2_2026_10_08_0064: farklı bilgi: doğru cevaplar farklı",
  'c02cf882a4ae721ac58484ff452ecad8':
      "baslangic_2026_10_06_0068 ~ dersler3_2026_10_08_0008: aynı bilgi; biri emekli (Grok + ana ajan)",
  '2d089f895e54d7f68af485c61afea64c':
      "dersler2_2026_10_08_0081 ~ dersler3_2026_10_08_0023: farklı bilgi: doğru cevaplar farklı",
  '3f0db99d7867d23c88a49b1451d8a223':
      "baslangic_2026_10_06_0033 ~ dersler3_2026_10_08_0043: farklı bilgi: doğru cevaplar farklı",
  'b95f47549e3c3259eef7f70fdd041817':
      "baslangic_2026_10_06_0094 ~ dersler3_2026_10_08_0044: farklı bilgi: doğru cevaplar farklı",
  '1499109cb4c8c7e1f7cb197105d991b8':
      "baslangic_2026_10_06_0033 ~ dersler3_2026_10_08_0047: farklı bilgi: doğru cevaplar farklı",
  '5450553d42f3d862b1add7ddecef391f':
      "baslangic_2026_10_06_0050 ~ dersler3_2026_10_08_0062: farklı bilgi: doğru cevaplar farklı",
  '06ef99d0ba824aee8eafc1ed770b7247':
      "dersler3_2026_10_08_0132 ~ dersler3_2026_10_08_0066: farklı bilgi: doğru cevaplar farklı",
  '7a0fe0df16f50f3e2151662a05fe60fb':
      "baslangic_2026_10_06_0050 ~ dersler3_2026_10_08_0080: farklı bilgi: doğru cevaplar farklı",
  '170ae57418880bd441a7bcd3a1e62dee':
      "dersler3_2026_10_08_0007 ~ dersler3_2026_10_08_0081: farklı bilgi: doğru cevaplar farklı",
  '6ab88f5a4df4bfc1868a7bfaf3ef08b3':
      "ders_2026_10_01_0051 ~ dersler3_2026_10_08_0088: farklı bilgi: doğru cevaplar farklı",
  '428fde0bd0651adc0c7f4191cf568221':
      "baslangic_2026_10_06_0033 ~ dersler3_2026_10_08_0098: farklı bilgi: doğru cevaplar farklı",
  'c956a11d7636d7d2d7e58132b8da4fe2':
      "dersler3_2026_10_08_0107 ~ dersler3_2026_10_08_0108: farklı bilgi: doğru cevaplar farklı",
  '617e4b5b880b6284c1979b513fe4d49a':
      "dersler3_2026_10_08_0107 ~ dersler3_2026_10_08_0109: farklı bilgi: doğru cevaplar farklı",
  '0ca1c5853b43b054f736218820e175b7':
      "dersler3_2026_10_08_0133 ~ dersler3_2026_10_08_0138: farklı bilgi: doğru cevaplar farklı",
  '606f21b282084c3f6c0384bf24695b7b':
      "ds_dirok_0029 ~ edit_dirok_0001: aynı bilgi; biri emekli (Grok + ana ajan)",
  '3dfd8003aa49d90f64d0d03d85449f06':
      "ds_cografya_0235 ~ edit_cografya_0008: farklı bilgi: doğru cevaplar farklı",
  'c8c9b90a8af4c615ecf83bd8ffeda0ac':
      "edit_cografya_0017 ~ edit_cografya_0013: farklı bilgi: doğru cevaplar farklı",
  '5eb4cef5f05f150a50d44685a2364275':
      "edit_cografya_0017 ~ edit_cografya_0014: farklı bilgi: doğru cevaplar farklı",
  '6e29296849d602e658738533c82400c0':
      "edit_cografya_0017 ~ edit_cografya_0028: farklı bilgi: doğru cevaplar farklı",
  '40c7fc5187b706a07a9f6474ae61bf0e':
      "edit_cografya_0017 ~ edit_cografya_0033: farklı bilgi (Grok + ana ajan)",
  '1457694107cba46930480139af2134f7':
      "edit_cografya_0017 ~ edit_cografya_0037: farklı bilgi: doğru cevaplar farklı",
  '1281fe8f446b928936689d0cfb6a7640':
      "ex28_sinor_duma_002 ~ ex28_sinor_duma_003: farklı bilgi: doğru cevaplar farklı",
  '31c63c3d1e89f1d049dcf3ae06a86dc4':
      "hat_0001 ~ hat_0007: farklı bilgi: doğru cevaplar farklı",
  '2acdc4faf5c71f5885eddff37a0dcf0e':
      "hat_0007 ~ hat_0008: farklı bilgi: doğru cevaplar farklı",
  '5317dde88c31c1dcd7feb46df9be9cfe':
      "hat_0019 ~ hat_0020: farklı bilgi: doğru cevaplar farklı",
  'b33978de4a74b44c4c7105eb422b97c1':
      "ex28_yilmaz_guney_005 ~ hat_0043: aynı bilgi; biri emekli (Grok + ana ajan)",
  'cea9b50f8b7b7fd6542ad5229d4e30f8':
      "ds_cografya_0007 ~ hat_0062: farklı bilgi: doğru cevaplar farklı",
  '85123766e00fdfdc15bb6f3b21883288':
      "ds_cografya_0030 ~ hat_0071: farklı bilgi (Grok + ana ajan)",
  '7bafbd3cf5cdfe66393f17953bf1114d':
      "hat_0081 ~ hat_0084: farklı bilgi: doğru cevaplar farklı",
  '81b3fdca044bb0e15181743c308d9d68':
      "hat_0092 ~ hat_0097: farklı bilgi: doğru cevaplar farklı",
  'bc4fdb661ffb25b844fc0ca7be98995f':
      "hat_0104 ~ hat_0109: aynı bilgi; biri emekli (Grok + ana ajan)",
  '5f07f5a5aeb53aea2c4bec5eff9408b5':
      "hat_0105 ~ hat_0112: aynı bilgi; biri emekli (Grok + ana ajan)",
  'cf11a9c762377e3894d0a24f0bc1b80a':
      "hat_0107 ~ hat_0118: aynı bilgi; biri emekli (Grok + ana ajan)",
  'ae18e17a115955973296c7aff7f6a8c0':
      "offline_0748 ~ offline_0756: farklı bilgi: doğru cevaplar farklı",
  '8f0be426fa4da27b97f39c598dd09614':
      "offline_2092 ~ offline_2106: farklı bilgi: doğru cevaplar farklı",
  '25b885be344f71dd0da383f38ff15005':
      "edit_cografya_0017 ~ offline_2175: farklı bilgi: doğru cevaplar farklı",
  'af6f23bde1f88fb880159ed2dc2a7abe':
      "edit_cografya_0017 ~ offline_2354: farklı bilgi: doğru cevaplar farklı",
  '1f75300955f50bf8442524fd8b4ed100':
      "edit_dirok_0028 ~ offline_2668: farklı bilgi: doğru cevaplar farklı",
  '0e9fd52869003818705ea935cfb60644':
      "ds_cografya_0005 ~ restore_2026_08_07_0007: farklı bilgi: doğru cevaplar farklı",
  '83f754c14eb19a17bd9342edf89aa7f6':
      "edit_cografya_0017 ~ restore_2026_08_07_0014: farklı bilgi: doğru cevaplar farklı",
  '3ce5b8209dc4bbab2708c6b4cc593bd5':
      "edit_cografya_0031 ~ restore_2026_08_07_0015: farklı bilgi: doğru cevaplar farklı",
  '2dc9f1105dcbf0a712d7503f28a8ca4b':
      "sf_nat_0006 ~ sf_nat_0007: farklı bilgi: doğru cevaplar farklı",
  'a3504f33c0f49444e5770a6cb848a70c':
      'baslangic_2026_10_06_0002 ~ ziman_x_0005: farklı bilgi (dengdêr sayısı 8 / bütün tîp sayısı 31)',
};
