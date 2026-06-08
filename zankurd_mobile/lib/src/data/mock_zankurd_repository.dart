import 'dart:async';

import '../models/leaderboard_entry.dart';
import '../models/player.dart';
import '../models/quiz_level.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import 'zankurd_repository.dart';

class MockZanKurdRepository implements ZanKurdRepository {
  MockZanKurdRepository();

  @override
  List<String> get categories => const [
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
  ];

  // ignore: long-method
  @override
  List<QuizQuestion> get questions => const [
    // ─── ZİMAN (Dil) ───────────────────────────────────────────────────────────
    QuizQuestion(id: 'z_001', category: 'Ziman', difficulty: 1,
      prompt: 'Di Kurmancî de peyva "zanîn" bi Tirkî çi ye?',
      answers: ['Bilmek', 'Gitmek', 'Okumak', 'Yazmak'],
      correctAnswer: 'Bilmek',
      explanation: '"Zanîn" — bilmek, öğrenmek anlamına gelir.'),
    QuizQuestion(id: 'z_002', category: 'Ziman', difficulty: 1,
      prompt: 'Kurmancî\'de "av" ne anlama gelir?',
      answers: ['Su', 'Ateş', 'Toprak', 'Hava'],
      correctAnswer: 'Su',
      explanation: '"Av" Kurmancî\'de su demektir.'),
    QuizQuestion(id: 'z_003', category: 'Ziman', difficulty: 1,
      prompt: 'Kurmancî\'de "çiya" hangi coğrafi unsuru ifade eder?',
      answers: ['Dağ', 'Nehir', 'Göl', 'Ova'],
      correctAnswer: 'Dağ',
      explanation: '"Çiya" Kurmancî\'de dağ anlamına gelir.'),
    QuizQuestion(id: 'z_004', category: 'Ziman', difficulty: 1,
      prompt: '"Rojbaş" ne zaman kullanılır?',
      answers: ['Günaydın / İyi günler', 'İyi geceler', 'Hoşça kal', 'Teşekkürler'],
      correctAnswer: 'Günaydın / İyi günler',
      explanation: '"Rojbaş" iyi günler, günaydın anlamında bir selamlama sözcüğüdür.'),
    QuizQuestion(id: 'z_005', category: 'Ziman', difficulty: 1,
      prompt: 'Kurmancî\'de "ez" hangi zamiri karşılar?',
      answers: ['Ben', 'Sen', 'O', 'Biz'],
      correctAnswer: 'Ben',
      explanation: '"Ez" birinci tekil şahıs zamiridir, Türkçedeki "ben"e karşılık gelir.'),
    QuizQuestion(id: 'z_006', category: 'Ziman', difficulty: 2,
      prompt: '"Xwendin" sözcüğü ne anlama gelir?',
      answers: ['Okumak', 'Yazmak', 'Konuşmak', 'Dinlemek'],
      correctAnswer: 'Okumak',
      explanation: '"Xwendin" hem okumak hem de öğrenmek anlamına gelir.'),
    QuizQuestion(id: 'z_007', category: 'Ziman', difficulty: 2,
      prompt: 'Kurmancî\'de "heval" ne demektir?',
      answers: ['Arkadaş', 'Düşman', 'Aile', 'Öğretmen'],
      correctAnswer: 'Arkadaş',
      explanation: '"Heval" dost, arkadaş anlamına gelir.'),
    QuizQuestion(id: 'z_008', category: 'Ziman', difficulty: 2,
      prompt: '"Spas" ne anlama gelir?',
      answers: ['Teşekkür', 'Özür dilerim', 'Evet', 'Hayır'],
      correctAnswer: 'Teşekkür',
      explanation: '"Spas" veya "spas dikim" teşekkür ederim demektir.'),
    QuizQuestion(id: 'z_009', category: 'Ziman', difficulty: 2,
      prompt: 'Kurmancî\'de fiil çekiminde "ergatif" yapı hangi zamanlarda kullanılır?',
      answers: ['Geçmiş zaman', 'Geniş zaman', 'Gelecek zaman', 'Emir kipi'],
      correctAnswer: 'Geçmiş zaman',
      explanation: 'Kurmancî ergatif bir dildir; özne geçmiş zamanda hedef duruma girer.',
      type: QuestionType.trueFalse),
    QuizQuestion(id: 'z_010', category: 'Ziman', difficulty: 3,
      prompt: '"Kurmancî Hint-Avrupa dil ailesinin İran koluna ait bir dildir." — Bu ifade doğru mudur?',
      answers: ['Rast', 'Şaş'],
      correctAnswer: 'Rast',
      explanation: 'Kurmancî, Hint-Avrupa ailesinin İranî kolunda yer alan Kürtçenin Kuzeybatı lehçesidir.',
      type: QuestionType.trueFalse),
    QuizQuestion(id: 'z_011', category: 'Ziman', difficulty: 1,
      prompt: '"Sêv" ne demektir?',
      answers: ['Elma', 'Armut', 'Üzüm', 'Kiraz'],
      correctAnswer: 'Elma',
      explanation: '"Sêv" Kurmancî\'de elma demektir.'),
    QuizQuestion(id: 'z_012', category: 'Ziman', difficulty: 2,
      prompt: 'Kurmancî\'de "ser" sözcüğü hangi anlama gelir?',
      answers: ['Baş / Kafa', 'El', 'Ayak', 'Kalp'],
      correctAnswer: 'Baş / Kafa',
      explanation: '"Ser" Kurmancî\'de baş, kafa, tepe anlamına gelir.'),
    QuizQuestion(id: 'z_013', category: 'Ziman', difficulty: 3,
      prompt: '"Kurdî" terimi hangi dil grubunu tanımlamak için kullanılır?',
      answers: ['Kürtçenin tüm lehçeleri', 'Sadece Kurmancî', 'Sadece Zazaca', 'Farsça'],
      correctAnswer: 'Kürtçenin tüm lehçeleri',
      explanation: '"Kurdî" genel olarak Kürtçenin tüm lehçelerini kapsayan üst terimdir.'),
    QuizQuestion(id: 'z_014', category: 'Ziman', difficulty: 1,
      prompt: '"Keç" ne demektir?',
      answers: ['Kız', 'Erkek', 'Çocuk', 'Kadın'],
      correctAnswer: 'Kız',
      explanation: '"Keç" Kurmancî\'de kız demektir.'),
    QuizQuestion(id: 'z_015', category: 'Ziman', difficulty: 2,
      prompt: '"Roj" hangi anlamı taşır?',
      answers: ['Güneş / Gün', 'Ay', 'Yıldız', 'Gece'],
      correctAnswer: 'Güneş / Gün',
      explanation: '"Roj" hem güneş hem de gün anlamına gelir.'),

    // ─── ÇAND (Kültür) ─────────────────────────────────────────────────────────
    QuizQuestion(id: 'c_001', category: 'Çand', difficulty: 1,
      prompt: 'Newroz bi gelemperî kîjan rojê tê pîroz kirin?',
      answers: ['21 Adar', '1 Gulan', '15 Hezîran', '29 Cotmeh'],
      correctAnswer: '21 Adar',
      explanation: 'Newroz, baharın gelişiyle 21 Mart\'ta kutlanır.'),
    QuizQuestion(id: 'c_002', category: 'Çand', difficulty: 1,
      prompt: '"Dengbêj" geleneği ne anlama gelir?',
      answers: ['Sözlü hikaye ve ezgi anlatıcıları', 'Dansçılar', 'Çalgıcılar', 'Çömlekçiler'],
      correctAnswer: 'Sözlü hikaye ve ezgi anlatıcıları',
      explanation: 'Dengbêjler sözlü kültür geleneğini yaşatan ezgili anlatıcılardır.'),
    QuizQuestion(id: 'c_003', category: 'Çand', difficulty: 2,
      prompt: 'Kürt düğünlerinde en çok oynanan halk dansı hangisidir?',
      answers: ['Govend (Halay)', 'Tango', 'Vals', 'Zeybek'],
      correctAnswer: 'Govend (Halay)',
      explanation: 'Govend, el ele tutuşarak oynanan geleneksel Kürt halk dansıdır.'),
    QuizQuestion(id: 'c_004', category: 'Çand', difficulty: 2,
      prompt: '"Serhildan" sözcüğü Kürt kültüründe ne anlama gelir?',
      answers: ['Ayaklanma / Direniş', 'Düğün', 'Hasat bayramı', 'Yeni yıl'],
      correctAnswer: 'Ayaklanma / Direniş',
      explanation: '"Serhildan" kalkış, ayaklanma anlamına gelir.'),
    QuizQuestion(id: 'c_005', category: 'Çand', difficulty: 1,
      prompt: 'Newroz\'da geleneksel olarak ne yakılır?',
      answers: ['Ateş', 'Mum', 'Tütsü', 'Meşale'],
      correctAnswer: 'Ateş',
      explanation: 'Newroz\'da büyük ateşler yakılarak bahar ve yeniden doğuş kutlanır.'),
    QuizQuestion(id: 'c_006', category: 'Çand', difficulty: 3,
      prompt: 'Kürt kıyafetlerinde erkekler genellikle hangi geleneksel kıyafeti giyer?',
      answers: ['Şalvar ve kuşak', 'Kaftan', 'Cüppe', 'Çakşır'],
      correctAnswer: 'Şalvar ve kuşak',
      explanation: 'Geleneksel erkek kıyafeti şalvar, gömlek ve bele bağlanan renkli kuşaktan oluşur.'),
    QuizQuestion(id: 'c_007', category: 'Çand', difficulty: 2,
      prompt: '"Kılam" ne anlama gelir?',
      answers: ['Türkü / Şarkı', 'Dans', 'Hikaye', 'Ağıt'],
      correctAnswer: 'Türkü / Şarkı',
      explanation: '"Kılam" Kurmancî\'de şarkı, türkü demektir.'),
    QuizQuestion(id: 'c_008', category: 'Çand', difficulty: 2,
      prompt: 'Kürt geleneksel müziğinde "bilûr" nedir?',
      answers: ['Flüt benzeri üflemeli çalgı', 'Davul', 'Bağlama', 'Zil'],
      correctAnswer: 'Flüt benzeri üflemeli çalgı',
      explanation: '"Bilûr" kamıştan yapılmış geleneksel bir üflemeli çalgıdır.'),
    QuizQuestion(id: 'c_009', category: 'Çand', difficulty: 1,
      prompt: 'Kürt kültüründe "mêvandar" ne anlama gelir?',
      answers: ['Ev sahibi / Ağırlayan kişi', 'Misafir', 'Köy muhtarı', 'Şair'],
      correctAnswer: 'Ev sahibi / Ağırlayan kişi',
      explanation: '"Mêvandar" misafiri ağırlayan, ev sahipliği yapan kişidir.'),
    QuizQuestion(id: 'c_010', category: 'Çand', difficulty: 3,
      prompt: '"Xwediyê mala" ifadesi ne anlama gelir?',
      answers: ['Evin efendisi / Ev reisi', 'Komşu', 'Misafir', 'Akraba'],
      correctAnswer: 'Evin efendisi / Ev reisi',
      explanation: '"Xwediyê mala" evin sahibi, ev reisi demektir.'),
    QuizQuestion(id: 'c_011', category: 'Çand', difficulty: 2,
      prompt: 'Kürt müziğinde "def" hangi çalgı türüdür?',
      answers: ['Vurmalı çalgı (tef)', 'Üflemeli çalgı', 'Telli çalgı', 'Elektronik çalgı'],
      correctAnswer: 'Vurmalı çalgı (tef)',
      explanation: '"Def" düğün ve törenlerde kullanılan büyük bir tef çeşididir.'),
    QuizQuestion(id: 'c_012', category: 'Çand', difficulty: 1,
      prompt: 'Newroz efsanesinde demirci Kawa kimi yener?',
      answers: ['Dehak / Zühak\'ı', 'İskender\'i', 'Rüstem\'i', 'Feridun\'u'],
      correctAnswer: 'Dehak / Zühak\'ı',
      explanation: 'Efsaneye göre demirci Kawa, halkı ezen zalim Dehak\'a karşı ayaklanır.'),
    QuizQuestion(id: 'c_013', category: 'Çand', difficulty: 2,
      prompt: '"Bijî" sözcüğü nasıl kullanılır?',
      answers: ['Yaşasın! diye bağırarak sevinç belirtmek', 'Elveda demek', 'Yas tutmak', 'Dua etmek'],
      correctAnswer: 'Yaşasın! diye bağırarak sevinç belirtmek',
      explanation: '"Bijî!" yaşasın, viva anlamında coşkulu bir tezahürat sözcüğüdür.'),
    QuizQuestion(id: 'c_014', category: 'Çand', difficulty: 1,
      type: QuestionType.trueFalse,
      prompt: 'Kürt kültüründe ateş, Newroz kutlamalarının merkezindedir.',
      answers: ['Rast', 'Şaş'],
      correctAnswer: 'Rast',
      explanation: 'Newroz ateşi kötülüğün yenilgisini ve baharın gelişini simgeler.'),
    QuizQuestion(id: 'c_015', category: 'Çand', difficulty: 3,
      prompt: '"Govend" dansında halkayı kim yönetir?',
      answers: ['Sergovend', 'Dengbêj', 'Molla', 'Ağa'],
      correctAnswer: 'Sergovend',
      explanation: '"Sergovend" halkayı yöneten, figürleri belirleyen öncü dansçıdır.'),

    // ─── DİROK (Tarih) ─────────────────────────────────────────────────────────
    QuizQuestion(id: 'd_001', category: 'Dîrok', difficulty: 1,
      type: QuestionType.trueFalse,
      prompt: 'Medler Mezopotamya tarihinde önemli bir halktır.',
      answers: ['Rast', 'Şaş'],
      correctAnswer: 'Rast',
      explanation: 'Medler M.Ö. 7. yüzyılda Asur İmparatorluğu\'nu yıkan önemli bir halktır.'),
    QuizQuestion(id: 'd_002', category: 'Dîrok', difficulty: 2,
      prompt: 'Med İmparatorluğu hangi başkentle yönetilirdi?',
      answers: ['Ekbatan (Hamedan)', 'Babil', 'Ninova', 'Persepolis'],
      correctAnswer: 'Ekbatan (Hamedan)',
      explanation: 'Med İmparatorluğu\'nun başkenti Ekbatan, günümüz İran\'ındaki Hamedan\'dır.'),
    QuizQuestion(id: 'd_003', category: 'Dîrok', difficulty: 2,
      prompt: 'Şeyh Said İsyanı hangi yılda gerçekleşti?',
      answers: ['1925', '1914', '1938', '1946'],
      correctAnswer: '1925',
      explanation: 'Şeyh Said İsyanı 1925 yılında Türkiye\'nin güneydoğusunda patlak verdi.'),
    QuizQuestion(id: 'd_004', category: 'Dîrok', difficulty: 3,
      prompt: 'Kürdistan Cumhuriyeti (Mahabad Cumhuriyeti) hangi yılda ilan edildi?',
      answers: ['1946', '1920', '1958', '1991'],
      correctAnswer: '1946',
      explanation: 'Mahabad Cumhuriyeti 1946\'da İran\'da ilan edildi; kısa sürede sona erdi.'),
    QuizQuestion(id: 'd_005', category: 'Dîrok', difficulty: 2,
      prompt: 'Sevr Antlaşması hangi yılda imzalandı?',
      answers: ['1920', '1918', '1923', '1915'],
      correctAnswer: '1920',
      explanation: 'Sevr Antlaşması 1920\'de imzalandı ve Kürtlere özerklik vaat etti; ancak hiç yürürlüğe girmedi.'),
    QuizQuestion(id: 'd_006', category: 'Dîrok', difficulty: 2,
      prompt: 'Lozan Antlaşması Sevr\'in yerini aldı ve Kürdistan maddelerini kaldırdı. Kaç yılında imzalandı?',
      answers: ['1923', '1920', '1925', '1919'],
      correctAnswer: '1923',
      explanation: 'Lozan Antlaşması 1923\'te imzalanarak yeni Türk devletini tanıdı ve Sevr\'i geçersiz kıldı.'),
    QuizQuestion(id: 'd_007', category: 'Dîrok', difficulty: 3,
      prompt: 'Dersim olayları hangi yılda yaşandı?',
      answers: ['1937-38', '1925', '1946', '1960'],
      correctAnswer: '1937-38',
      explanation: 'Dersim olayları 1937-38 yıllarında Türkiye\'nin Dersim (Tunceli) bölgesinde yaşandı.'),
    QuizQuestion(id: 'd_008', category: 'Dîrok', difficulty: 1,
      prompt: 'Asurların yıkılmasında hangi halk büyük rol oynadı?',
      answers: ['Medler', 'Persler', 'Babilliler', 'Hititler'],
      correctAnswer: 'Medler',
      explanation: 'Medler ve Babilliler birleşerek M.Ö. 612\'de Asur başkenti Ninova\'yı yıktı.'),
    QuizQuestion(id: 'd_009', category: 'Dîrok', difficulty: 3,
      prompt: 'Kürt milliyetçiliğinin önemli simgesi olan Xoybûn örgütü ne zaman kuruldu?',
      answers: ['1927', '1920', '1946', '1958'],
      correctAnswer: '1927',
      explanation: 'Xoybûn örgütü 1927\'de kurularak Kürt siyasi mücadelesinde önemli bir rol oynadı.'),
    QuizQuestion(id: 'd_010', category: 'Dîrok', difficulty: 2,
      type: QuestionType.trueFalse,
      prompt: 'Osmanlı İmparatorluğu döneminde Kürtler dört ayrı devlet arasında bölündü.',
      answers: ['Şaş', 'Rast'],
      correctAnswer: 'Şaş',
      explanation: 'Kürtler özellikle 1923 Lozan sonrasında Türkiye, İran, Irak ve Suriye arasında bölündü.'),
    QuizQuestion(id: 'd_011', category: 'Dîrok', difficulty: 2,
      prompt: '"Qazi Muhammed" hangi kısa ömürlü Kürt devletinin lideriydi?',
      answers: ['Mahabad Cumhuriyeti', 'Ararat Cumhuriyeti', 'Kürdistan Krallığı', 'Med İmparatorluğu'],
      correctAnswer: 'Mahabad Cumhuriyeti',
      explanation: 'Qazi Muhammed 1946\'da ilan edilen Mahabad Cumhuriyeti\'nin cumhurbaşkanıydı.'),
    QuizQuestion(id: 'd_012', category: 'Dîrok', difficulty: 3,
      prompt: 'Saladin (Selahattin Eyyubi) hangi halktan gelir?',
      answers: ['Kürt', 'Türk', 'Arap', 'Moğol'],
      correctAnswer: 'Kürt',
      explanation: 'Haçlılara karşı savaşıyla tanınan Selahattin Eyyubi Tikrit\'te doğmuş bir Kürt\'tür.'),
    QuizQuestion(id: 'd_013', category: 'Dîrok', difficulty: 1,
      prompt: 'Selahattin Eyyubi Haçlılardan hangi şehri 1187\'de geri aldı?',
      answers: ['Kudüs', 'Antakya', 'Edessa', 'Trablus'],
      correctAnswer: 'Kudüs',
      explanation: 'Selahattin Eyyubi 1187\'de Hıttin Savaşı\'nda Haçlıları yenerek Kudüs\'ü aldı.'),
    QuizQuestion(id: 'd_014', category: 'Dîrok', difficulty: 2,
      prompt: 'İbrahim Paşa\'nın yönettiği ve güç kazanan aşiret konfederasyonu hangisiydi?',
      answers: ['Milli Aşiret Konfederasyonu', 'Hamidiye Alayları', 'Zaza Birliği', 'Baban Emirliği'],
      correctAnswer: 'Hamidiye Alayları',
      explanation: 'Hamidiye Alayları II. Abdülhamit döneminde Kürt aşiretlerinden oluşturulan düzensiz süvari birlikleriydi.'),
    QuizQuestion(id: 'd_015', category: 'Dîrok', difficulty: 3,
      prompt: 'Botan Mirliği\'nin en tanınan yöneticisi kimdi?',
      answers: ['Bedirhan Beg', 'Şeyh Said', 'İhsan Nuri', 'Mustafa Barzani'],
      correctAnswer: 'Bedirhan Beg',
      explanation: 'Bedirhan Beg 19. yüzyılın ilk yarısında Botan\'ı yöneten güçlü bir Kürt lideriydi.'),

    // ─── EDEBİYAT ───────────────────────────────────────────────────────────────
    QuizQuestion(id: 'e_001', category: 'Edebiyat', difficulty: 1,
      prompt: 'Mem û Zîn kimin eseridir?',
      answers: ['Ehmedê Xanî', 'Cegerxwîn', 'Melayê Cizîrî', 'Feqiyê Teyran'],
      correctAnswer: 'Ehmedê Xanî',
      explanation: 'Mem û Zîn, 17. yüzyılda Ehmedê Xanî tarafından yazılmış klasik bir Kürt epiğidir.'),
    QuizQuestion(id: 'e_002', category: 'Edebiyat', difficulty: 2,
      prompt: 'Ehmedê Xanî\'nin eseri Mem û Zîn hangi yüzyılda yazıldı?',
      answers: ['17. yüzyıl', '15. yüzyıl', '19. yüzyıl', '13. yüzyıl'],
      correctAnswer: '17. yüzyıl',
      explanation: 'Mem û Zîn 1692\'de kaleme alınmıştır.'),
    QuizQuestion(id: 'e_003', category: 'Edebiyat', difficulty: 2,
      prompt: 'Cegerxwîn\'in gerçek adı nedir?',
      answers: ['Şêxmus Hesen', 'Ahmet Yıldız', 'Mela Ehmed', 'Seîd Axayê'],
      correctAnswer: 'Şêxmus Hesen',
      explanation: 'Cegerxwîn takma ad olup asıl adı Şêxmus Hesen\'dir.'),
    QuizQuestion(id: 'e_004', category: 'Edebiyat', difficulty: 3,
      prompt: 'Melayê Cizîrî hangi yüzyılda yaşamıştır?',
      answers: ['16-17. yüzyıl', '14-15. yüzyıl', '18-19. yüzyıl', '13-14. yüzyıl'],
      correctAnswer: '16-17. yüzyıl',
      explanation: 'Melayê Cizîrî yaklaşık 1570-1640 yılları arasında yaşayan ünlü bir Kürt şairidir.'),
    QuizQuestion(id: 'e_005', category: 'Edebiyat', difficulty: 2,
      prompt: '"Hawar" dergisi ilk kez nerede yayımlandı?',
      answers: ['Şam / Suriye', 'Beyrut', 'Kahire', 'Paris'],
      correctAnswer: 'Şam / Suriye',
      explanation: 'Hawar dergisi 1932-1943 yılları arasında Şam\'da yayımlandı ve Kürt edebiyatına büyük katkı sağladı.'),
    QuizQuestion(id: 'e_006', category: 'Edebiyat', difficulty: 2,
      prompt: 'Kurmancî Kürtçe alfabesini kimin standardizasyonu öncülük etti?',
      answers: ['Celadet Alî Bedirxan', 'Qazi Muhammed', 'Cegerxwîn', 'Ehmedê Xanî'],
      correctAnswer: 'Celadet Alî Bedirxan',
      explanation: 'Celadet Alî Bedirxan 1932\'de Hawar dergisiyle birlikte Kürt Latinize alfabesini geliştirdi.'),
    QuizQuestion(id: 'e_007', category: 'Edebiyat', difficulty: 1,
      prompt: 'Kürt edebiyatında "stran" ne anlama gelir?',
      answers: ['Şarkı / Türkü', 'Şiir', 'Roman', 'Hikaye'],
      correctAnswer: 'Şarkı / Türkü',
      explanation: '"Stran" sözlü olarak aktarılan ve ezgiyle söylenen türkü ya da şarkı demektir.'),
    QuizQuestion(id: 'e_008', category: 'Edebiyat', difficulty: 3,
      prompt: 'Feqiyê Teyran\'ın en bilinen halk hikayesi hangisidir?',
      answers: ['Zembîlfiroş', 'Mem û Zîn', 'Siyabend û Xecê', 'Xan û Kurdê'],
      correctAnswer: 'Zembîlfiroş',
      explanation: 'Feqiyê Teyran 17. yüzyılda yaşamış ve Zembîlfiroş gibi halk hikayelerini kaleme almıştır.'),
    QuizQuestion(id: 'e_009', category: 'Edebiyat', difficulty: 2,
      prompt: 'Kürt edebiyatında "dengbêj" kimlere denir?',
      answers: ['Sözlü epik anlatıcılar', 'Roman yazarları', 'Gazeteciler', 'Tiyatrocular'],
      correctAnswer: 'Sözlü epik anlatıcılar',
      explanation: 'Dengbêjler, destanları ve halk masallarını ezgiyle kuşaktan kuşağa aktaran geleneksel anlatıcılardır.'),
    QuizQuestion(id: 'e_010', category: 'Edebiyat', difficulty: 1,
      type: QuestionType.trueFalse,
      prompt: 'Kürt edebiyatının en eski yazılı eserleri Arap harfleriyle kaleme alınmıştır.',
      answers: ['Rast', 'Şaş'],
      correctAnswer: 'Rast',
      explanation: 'Geleneksel Kürt şiiri yüzyıllarca Arap kökenli alfabeyle yazıldı; Latin alfabesi 1932\'de Celadet Bedirxan ile yaygınlaştı.'),
    QuizQuestion(id: 'e_011', category: 'Edebiyat', difficulty: 2,
      prompt: '"Mem û Zîn" hangi türde bir eserdir?',
      answers: ['Epik şiir / Mesnevî', 'Roman', 'Tiyatro', 'Kısa hikaye'],
      correctAnswer: 'Epik şiir / Mesnevî',
      explanation: 'Mem û Zîn, mesnevi biçiminde yazılmış yaklaşık 2650 beyitten oluşan bir epik şiirdir.'),
    QuizQuestion(id: 'e_012', category: 'Edebiyat', difficulty: 3,
      prompt: '"Siyabend û Xecê" hikayesi neyin üzerine kuruludur?',
      answers: ['Yasak aşk ve trajedi', 'Savaş ve zafer', 'Ticaret ve yolculuk', 'Din ve ibadet'],
      correctAnswer: 'Yasak aşk ve trajedi',
      explanation: 'Siyabend û Xecê, Kürt halk edebiyatının en bilinen aşk ve trajedi anlatılarından biridir.'),
    QuizQuestion(id: 'e_013', category: 'Edebiyat', difficulty: 2,
      prompt: 'Yazarı Yaşar Kemal olan ve Kürt kültürünü işleyen ünlü roman hangisidir?',
      answers: ['İnce Memed', 'Yaprak Dökümü', 'Çalıkuşu', 'Saatleri Ayarlama Enstitüsü'],
      correctAnswer: 'İnce Memed',
      explanation: 'İnce Memed, Kürt ve Türk halk geleneğinden beslenen önemli bir Türk romandır.'),
    QuizQuestion(id: 'e_014', category: 'Edebiyat', difficulty: 1,
      prompt: '"Lawik" ne tür bir edebi formdur?',
      answers: ['Lirik şiir / Türkü', 'Destan', 'Ağıt', 'Ninni'],
      correctAnswer: 'Lirik şiir / Türkü',
      explanation: '"Lawik" kısa, lirik ve ezgili bir Kürt şiir ve türkü türüdür.'),
    QuizQuestion(id: 'e_015', category: 'Edebiyat', difficulty: 3,
      prompt: 'Elî Herîrî hangi şehirde doğmuştur?',
      answers: ['Hakkari', 'Duhok', 'Erbil', 'Süleymaniye'],
      correctAnswer: 'Hakkari',
      explanation: 'Elî Herîrî (yaklaşık 1009-1078) Hakkari bölgesinde doğmuş, klasik Kürt edebiyatının öncülerindendir.'),

    // ─── COGRAFYA ───────────────────────────────────────────────────────────────
    QuizQuestion(id: 'g_001', category: 'Cografya', difficulty: 1,
      prompt: '"Çiya" hangi coğrafi terimi ifade eder?',
      answers: ['Dağ', 'Nehir', 'Göl', 'Ova'],
      correctAnswer: 'Dağ',
      explanation: '"Çiya" Kurmancî\'de dağ demektir.'),
    QuizQuestion(id: 'g_002', category: 'Cografya', difficulty: 1,
      prompt: 'Kürdistan bölgesinin en uzun nehri hangisidir?',
      answers: ['Fırat (Firat)', 'Nil', 'Dicle (Dijle)', 'Amuderya'],
      correctAnswer: 'Fırat (Firat)',
      explanation: 'Fırat, Kürdistan dağlarından doğan ve Mezopotamya\'yı sulayan en uzun nehirdir.'),
    QuizQuestion(id: 'g_003', category: 'Cografya', difficulty: 2,
      prompt: 'Dicle nehri Kurmancî\'de nasıl söylenir?',
      answers: ['Dijle', 'Firat', 'Zap', 'Aras'],
      correctAnswer: 'Dijle',
      explanation: '"Dijle" Dicle nehrinin Kurmancî adıdır.'),
    QuizQuestion(id: 'g_004', category: 'Cografya', difficulty: 2,
      prompt: 'Ağrı Dağı Kurmancî\'de nasıl adlandırılır?',
      answers: ['Çiyayê Agirî', 'Çiyayê Zend', 'Çiyayê Qandîl', 'Çiyayê Sêvrek'],
      correctAnswer: 'Çiyayê Agirî',
      explanation: '"Çiyayê Agirî" Ağrı Dağı\'nın Kurmancî adıdır; bölgenin en yüksek zirvesidir (5137 m).'),
    QuizQuestion(id: 'g_005', category: 'Cografya', difficulty: 1,
      prompt: 'Van Gölü hangi ülke sınırları içinde yer almaktadır?',
      answers: ['Türkiye', 'İran', 'Irak', 'Suriye'],
      correctAnswer: 'Türkiye',
      explanation: 'Van Gölü Doğu Türkiye\'de yer alır ve Orta Doğu\'nun en büyük gölüdür.'),
    QuizQuestion(id: 'g_006', category: 'Cografya', difficulty: 2,
      prompt: 'Kuzey Irak\'taki özerk Kürt bölgesinin başkenti neresidir?',
      answers: ['Erbil (Hewlêr)', 'Süleymaniye', 'Duhok', 'Kerkük'],
      correctAnswer: 'Erbil (Hewlêr)',
      explanation: 'Hewlêr (Erbil), Irak Kürdistan Bölgesel Yönetimi\'nin başkentidir.'),
    QuizQuestion(id: 'g_007', category: 'Cografya', difficulty: 2,
      prompt: '"Başûrê Kurdistanê" hangi ülkedeki Kürdistan bölgesini ifade eder?',
      answers: ['Irak', 'İran', 'Suriye', 'Türkiye'],
      correctAnswer: 'Irak',
      explanation: '"Başûr" güney demektir; Güney Kürdistan Irak\'taki Kürt bölgesidir.'),
    QuizQuestion(id: 'g_008', category: 'Cografya', difficulty: 1,
      prompt: '"Rojava" Kurmancî\'de ne anlama gelir?',
      answers: ['Batı', 'Doğu', 'Kuzey', 'Güney'],
      correctAnswer: 'Batı',
      explanation: '"Rojava" Kurmancî\'de batı demektir; Batı Kürdistan olarak Kuzey Suriye\'deki bölgeyi ifade eder.'),
    QuizQuestion(id: 'g_009', category: 'Cografya', difficulty: 3,
      prompt: 'Zap nehri hangi büyük nehre karışır?',
      answers: ['Dicle\'ye (Dijle)', 'Fırat\'a (Firat)', 'Aras\'a', 'Kura\'ya'],
      correctAnswer: 'Dicle\'ye (Dijle)',
      explanation: 'Zap (Zab) nehri Irak\'ta Dicle\'ye karışır; Büyük ve Küçük Zab olmak üzere iki kolu vardır.'),
    QuizQuestion(id: 'g_010', category: 'Cografya', difficulty: 2,
      prompt: 'Qandil Dağları hangi iki ülkenin sınırındadır?',
      answers: ['Irak-İran', 'Türkiye-İran', 'Türkiye-Irak', 'Suriye-Irak'],
      correctAnswer: 'Irak-İran',
      explanation: 'Qandil Dağları Irak-İran sınırında yer alır ve bölgenin önemli dağ silsilelerindendir.'),
    QuizQuestion(id: 'g_011', category: 'Cografya', difficulty: 1,
      prompt: '"Başûr" Kurmancî\'de hangi yönü ifade eder?',
      answers: ['Güney', 'Kuzey', 'Doğu', 'Batı'],
      correctAnswer: 'Güney',
      explanation: '"Başûr" güney, "Bakur" kuzey, "Rojhilat" doğu, "Rojava" batı demektir.'),
    QuizQuestion(id: 'g_012', category: 'Cografya', difficulty: 2,
      prompt: 'Urmiye Gölü hangi ülkededir?',
      answers: ['İran', 'Irak', 'Türkiye', 'Azerbaycan'],
      correctAnswer: 'İran',
      explanation: 'Urmiye Gölü İran\'ın kuzeybatısında yer alan bir tuz gölüdür; son yıllarda ciddi ölçüde küçülmektedir.'),
    QuizQuestion(id: 'g_013', category: 'Cografya', difficulty: 3,
      prompt: '"Hewlêr" hangi antik kentin modern adıdır?',
      answers: ['Erbil', 'Ninova', 'Babil', 'Ur'],
      correctAnswer: 'Erbil',
      explanation: 'Hewlêr (Erbil), dünyanın en eski sürekli iskân edilen kentlerinden biridir.'),
    QuizQuestion(id: 'g_014', category: 'Cografya', difficulty: 2,
      prompt: '"Bakurê Kurdistanê" ifadesi hangi coğrafyayı tanımlar?',
      answers: ['Doğu ve Güneydoğu Türkiye', 'Kuzey Irak', 'Kuzey Suriye', 'Kuzey İran'],
      correctAnswer: 'Doğu ve Güneydoğu Türkiye',
      explanation: '"Bakur" kuzey demektir; Kuzey Kürdistan Türkiye\'deki Kürt nüfusunun yoğun olduğu bölgeyi ifade eder.'),
    QuizQuestion(id: 'g_015', category: 'Cografya', difficulty: 1,
      prompt: 'Diyarbakır şehrinin Kurmancî adı nedir?',
      answers: ['Amed', 'Semsur', 'Riha', 'Serhed'],
      correctAnswer: 'Amed',
      explanation: 'Amed, Diyarbakır\'ın Kürtçe adıdır; Kürt kültürü ve siyaseti açısından önemli bir kenttir.'),

    // ─── MUZİK ──────────────────────────────────────────────────────────────────
    QuizQuestion(id: 'm_001', category: 'Muzîk', difficulty: 1,
      type: QuestionType.trueFalse,
      prompt: 'Dengbêj geleneği sözlü anlatım ve ezgiyle yakından ilişkilidir.',
      answers: ['Rast', 'Şaş'],
      correctAnswer: 'Rast',
      explanation: 'Dengbêjlik, destanları ve hikayeleri ezgiyle aktaran sözlü kültür geleneğidir.'),
    QuizQuestion(id: 'm_002', category: 'Muzîk', difficulty: 1,
      prompt: '"Bilûr" hangi çalgı türüdür?',
      answers: ['Kamıştan yapılmış üflemeli çalgı', 'Davul', 'Bağlama', 'Ud'],
      correctAnswer: 'Kamıştan yapılmış üflemeli çalgı',
      explanation: '"Bilûr" veya "mey" kamıştan yapılmış geleneksel bir üflemeli çalgıdır.'),
    QuizQuestion(id: 'm_003', category: 'Muzîk', difficulty: 2,
      prompt: 'Karim Aga Khan ödüllü dengbêj Şakiro\'nun gerçek adı nedir?',
      answers: ['Şekir Bekir', 'İbrahim Demirci', 'Ali Hasan', 'Mehmed Xan'],
      correctAnswer: 'Şekir Bekir',
      explanation: 'Şakiro (Şekir Bekir) 20. yüzyılın en ünlü dengbêjlerinden biridir.'),
    QuizQuestion(id: 'm_004', category: 'Muzîk', difficulty: 2,
      prompt: '"Govend" müziğinde temel ritim çalgısı hangisidir?',
      answers: ['Davul ve zurna', 'Keman ve flüt', 'Ud ve kanun', 'Saz ve baglama'],
      correctAnswer: 'Davul ve zurna',
      explanation: 'Govend danslarında geleneksel olarak davul ve zurna eşlik eder.'),
    QuizQuestion(id: 'm_005', category: 'Muzîk', difficulty: 1,
      prompt: '"Zurna" hangi çalgı ailesine aittir?',
      answers: ['Çift kamışlı üflemeli çalgılar', 'Telli çalgılar', 'Vurmalı çalgılar', 'Elektronik çalgılar'],
      correctAnswer: 'Çift kamışlı üflemeli çalgılar',
      explanation: 'Zurna, çift kamışlı ahşap bir üflemeli çalgıdır; Kürt müziğinde yaygın kullanılır.'),
    QuizQuestion(id: 'm_006', category: 'Muzîk', difficulty: 3,
      prompt: 'Hangi Kürt sanatçı 1990\'ların dünya müziği sahnesinde uluslararası şöhret kazandı?',
      answers: ['Şivan Perwer', 'Ciwan Haco', 'Nizamettin Ariç', 'Temo'],
      correctAnswer: 'Şivan Perwer',
      explanation: 'Şivan Perwer, Kürt müziğinin dünyaya açılan en önemli seslerinden biridir; sürgünde verdiği konserlerle tanınır.'),
    QuizQuestion(id: 'm_007', category: 'Muzîk', difficulty: 2,
      prompt: '"Lawik" ne tür bir müzik formudur?',
      answers: ['Lirik türkü', 'Marş', 'İlahi', 'Enstrümantal'],
      correctAnswer: 'Lirik türkü',
      explanation: '"Lawik" kısa ve ezgili, genellikle aşk ve özlem temalı lirik bir Kürt türkü formudur.'),
    QuizQuestion(id: 'm_008', category: 'Muzîk', difficulty: 2,
      prompt: 'Kürt müziğinde "dûdûk" ne tür bir çalgıdır?',
      answers: ['Çift kamışlı tahta üflemeli', 'Davul türü', 'Telli saz', 'Metal üflemeli'],
      correctAnswer: 'Çift kamışlı tahta üflemeli',
      explanation: 'Dûdûk kayısı ahşabından yapılmış çift kamışlı bir üflemeli çalgıdır; Ermeni müziğiyle de özdeşleşmiştir.'),
    QuizQuestion(id: 'm_009', category: 'Muzîk', difficulty: 1,
      prompt: '"Kılam" ne anlama gelir?',
      answers: ['Şarkı / Türkü', 'Dans figürü', 'Enstrüman', 'Nota'],
      correctAnswer: 'Şarkı / Türkü',
      explanation: '"Kılam" Kurmancî\'de şarkı veya türkü demektir.'),
    QuizQuestion(id: 'm_010', category: 'Muzîk', difficulty: 3,
      prompt: 'Dengbêjlik geleneği UNESCO\'nun somut olmayan kültürel miras listesinde yer almaktadır.',
      answers: ['Rast', 'Şaş'],
      correctAnswer: 'Şaş',
      explanation: 'Dengbêjlik Türkiye\'nin ulusal kültürel miras listesinde yer alsa da henüz UNESCO listesine girmemiştir.',
      type: QuestionType.trueFalse),
    QuizQuestion(id: 'm_011', category: 'Muzîk', difficulty: 2,
      prompt: '"Stran" sözcüğü müzikte ne anlama gelir?',
      answers: ['Şarkı', 'Enstrüman', 'Ritim', 'Melodi'],
      correctAnswer: 'Şarkı',
      explanation: '"Stran" şarkı, "kilam" da şarkı demektir; ikisi çoğunlukla birbirinin yerine kullanılır.'),
    QuizQuestion(id: 'm_012', category: 'Muzîk', difficulty: 3,
      prompt: 'Kürt halk müziğinde "hîrî" nedir?',
      answers: ['Tek ses eşliğinde söylenen ağıt tarzı', 'Çok sesli koro', 'Davul ritmi', 'Dans figürü'],
      correctAnswer: 'Tek ses eşliğinde söylenen ağıt tarzı',
      explanation: '"Hîrî" yavaş tempo ve tekdüze melodi üzerine kurulu, genellikle yas ve özlem ifade eden bir söyleyiş biçimidir.'),
    QuizQuestion(id: 'm_013', category: 'Muzîk', difficulty: 2,
      prompt: 'Hangi Kürt sanatçı "Kürdistan" isimli şarkısıyla tanınmaktadır?',
      answers: ['Şivan Perwer', 'Ciwan Haco', 'Dilnoza İbragimova', 'Rojin'],
      correctAnswer: 'Şivan Perwer',
      explanation: 'Şivan Perwer, "Kürdistan" adlı şarkısıyla Kürt kimliğinin sembolü haline gelmiştir.'),
    QuizQuestion(id: 'm_014', category: 'Muzîk', difficulty: 1,
      prompt: '"Halay" dansı Kürtçede nasıl adlandırılır?',
      answers: ['Govend', 'Sema', 'Halparke', 'Çoçek'],
      correctAnswer: 'Govend',
      explanation: '"Govend" el ele tutuşularak oynanan Kürt halk dansı, Türkçedeki "halay"a karşılık gelir.'),
    QuizQuestion(id: 'm_015', category: 'Muzîk', difficulty: 2,
      prompt: 'Ciwan Haco hangi şehirde doğmuştur?',
      answers: ['Haseke (Suriye)', 'Diyarbakır', 'Erbil', 'Bakuba'],
      correctAnswer: 'Haseke (Suriye)',
      explanation: 'Ciwan Haco, 1955\'te Kuzey Suriye\'nin Haseke şehrinde doğmuş ünlü bir Kürt müzisyen ve şarkıcıdır.'),
  ];

  String _mockName = 'ZanKurd Oyuncusu';

  @override
  Future<void> ensureProfile() async {}

  @override
  Future<String> getProfileName() async => _mockName;

  @override
  Future<void> updateProfileName(String name) async {
    _mockName = name;
  }

  @override
  Future<LeaderboardEntry?> getPlayerStats() async {
    return const LeaderboardEntry(
      rank: 1,
      playerId: 'mock_self',
      displayName: 'ZanKurd Oyuncusu',
      totalScore: 0,
      bestStreak: 0,
      roomsPlayed: 0,
    );
  }

  @override
  Future<List<String>> loadCategories() async => categories;

  @override
  Future<List<QuizQuestion>> loadQuestions({
    String? categoryId,
    int limit = 10,
  }) async {
    return questions.take(limit).toList();
  }

  @override
  List<QuizLevel> levelsForCategory(String category) {
    return [
      QuizLevel(
        number: 1,
        title: 'Destpêk',
        category: category,
        difficultyMin: 1,
        difficultyMax: 1,
        questionCount: 10,
      ),
      QuizLevel(
        number: 2,
        title: 'Bingeh',
        category: category,
        difficultyMin: 1,
        difficultyMax: 2,
        questionCount: 10,
      ),
      QuizLevel(
        number: 3,
        title: 'Navîn',
        category: category,
        difficultyMin: 2,
        difficultyMax: 3,
        questionCount: 12,
      ),
      QuizLevel(
        number: 4,
        title: 'Pêşketî',
        category: category,
        difficultyMin: 3,
        difficultyMax: 4,
        questionCount: 12,
      ),
      QuizLevel(
        number: 5,
        title: 'Mamoste',
        category: category,
        difficultyMin: 4,
        difficultyMax: 5,
        questionCount: 15,
      ),
    ];
  }

  @override
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    int limit = 10,
  }) async {
    final filtered = questions
        .where(
          (question) =>
              question.category == category &&
              question.difficulty >= difficultyMin &&
              question.difficulty <= difficultyMax,
        )
        .toList();

    return (filtered.isEmpty ? questions : filtered).take(limit).toList();
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    return questions.take(room.questionCount).toList();
  }

  @override
  GameRoom createRoom({String category = 'Ziman'}) {
    return GameRoom(
      name: 'Hevalên Zanînê',
      code: 'ZK-${DateTime.now().millisecond.toString().padLeft(3, '0')}',
      category: category,
      questionCount: 10,
      status: RoomStatus.lobby,
      players: const [
        Player(name: 'Tu', score: 0, state: 'Hazır', streak: 0),
        Player(name: 'Rojda', score: 1240, state: 'Hazır', streak: 4),
        Player(name: 'Baran', score: 1180, state: 'Cevapladı', streak: 3),
        Player(name: 'Dilan', score: 960, state: 'Bekliyor', streak: 2),
      ],
    );
  }

  @override
  GameRoom joinRoom(String code) {
    final cleanCode = code.trim().isEmpty
        ? 'ZK-4821'
        : code.trim().toUpperCase();
    return createRoom().copyWith(code: cleanCode);
  }

  @override
  Future<GameRoom> createOnlineRoom({String category = 'Ziman'}) async {
    return createRoom(category: category);
  }

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    return joinRoom(code);
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    return room.players;
  }

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    return Stream.value(room.players);
  }

  @override
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room) {
    return Stream.value(room.status);
  }

  @override
  Future<void> updateReady(GameRoom room, bool isReady) async {}

  @override
  Future<void> startGame(GameRoom room) async {}

  @override
  Future<void> finishGame(GameRoom room) async {}

  @override
  Future<int> getProfileCoins() async => 2450;

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    int responseMs = 2000,
  }) async {
    final correctIndex = question.answers.indexOf(question.correctAnswer);
    final correctOptionKey = switch (correctIndex) {
      0 => 'A',
      1 => 'B',
      2 => 'C',
      _ => 'D',
    };

    final isCorrect = selectedOptionOptionKey == correctOptionKey;
    return {'is_correct': isCorrect, 'points': isCorrect ? 100 : 0};
  }

  @override
  Future<bool> toggleFavoriteQuestion(
    QuizQuestion question,
    bool favorite,
  ) async {
    return favorite;
  }

  @override
  Future<void> reportQuestion(QuizQuestion question, String reason) async {}

  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async {
    return questions.take(3).toList();
  }

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({int limit = 50}) async {
    const entries = [
      LeaderboardEntry(
        rank: 1,
        playerId: 'mock_rojda',
        displayName: 'Rojda',
        totalScore: 12840,
        bestStreak: 11,
        roomsPlayed: 18,
      ),
      LeaderboardEntry(
        rank: 2,
        playerId: 'mock_baran',
        displayName: 'Baran',
        totalScore: 11720,
        bestStreak: 9,
        roomsPlayed: 16,
      ),
      LeaderboardEntry(
        rank: 3,
        playerId: 'mock_dilan',
        displayName: 'Dilan',
        totalScore: 10490,
        bestStreak: 8,
        roomsPlayed: 14,
      ),
      LeaderboardEntry(
        rank: 4,
        playerId: 'mock_azad',
        displayName: 'Azad',
        totalScore: 9360,
        bestStreak: 7,
        roomsPlayed: 12,
      ),
      LeaderboardEntry(
        rank: 5,
        playerId: 'mock_berfin',
        displayName: 'Berfin',
        totalScore: 8840,
        bestStreak: 6,
        roomsPlayed: 11,
      ),
    ];

    return entries.take(limit).toList();
  }
}
