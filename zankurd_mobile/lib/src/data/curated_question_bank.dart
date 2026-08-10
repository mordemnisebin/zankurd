import '../models/question_metadata.dart';
import '../models/quiz_question.dart';

// İkincil kültürel/tarihî kaynaklar — genel Kürt halk bilgisi, vakıf
// yayınları, edebiyat antolojileri. Soruların temel gerçeklerini
// akademik ansiklopedilerle destekler.
const _academikSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle:
      'Ansiklopedîk çavkanî (Kürt Ansiklopedisi, Encyclopaedia Britannica — Kurdish)',
  sourceReference:
      'https://www.britannica.com/topic/Kurd; Kürt Ansiklopedisi (2009-2012 cild I-VI)',
  qualityVersion: 1,
);

const _dengbejSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Dengbêjî û mûzîka kurdî ya devkî',
  sourceReference:
      'İbrahim Güçlü, Dengbêjler (2012); Mehmet Uzun, Dengbêj Üslubu Hakkında',
  qualityVersion: 1,
);

// Birincil kaynaklar: hareketin kendi kurumları ve medyası. Akademik kaynak
// yalnızca destekleyici çapraz kontroldür; hareketin öz-tanımı bağımsız bir
// olgu gibi sunulmaz. Sorular tek bir kaynağa yığılmasın diye kaynak ailesi
// soru kümelerine dağıtılır.
const _anfSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'ANF movement media + supporting academic context',
  sourceReference:
      'https://anfenglishmobile.com/kadin/k-176492; Cambridge History of the Kurds, Kurdish Women’s Freedom Movement chapter',
  qualityVersion: 1,
);

const _kjarSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'KJAR movement statement + supporting academic context',
  sourceReference:
      'https://anfenglishmobile.com/kurdIstan/kjar-dan-10-boyutlu-bir-devrim-projesi-177521; Cambridge History of the Kurds, Kurdish Women’s Freedom Movement chapter',
  qualityVersion: 1,
);

const _kongraStarSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Kongra Star institutional publications + supporting research',
  sourceReference:
      'https://kongra-star.org/eng/about/; https://kongra-star.org/eng/wp-content/uploads/2025/01/Annual-Newsletter-of-the-Womens-Revolution.pdf; Cambridge History of the Kurds, Kurdish Women’s Freedom Movement chapter',
  qualityVersion: 1,
);

const _jineolojiSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Jineolojî movement media + supporting academic context',
  sourceReference:
      'https://anfenglishmobile.com/features/twitterkurds-takes-the-civil-disobedience-campaign-online-3254; https://kongra-star.org/eng/wp-content/uploads/2025/01/Annual-Newsletter-of-the-Womens-Revolution.pdf; Cambridge, Beyond Feminism? Jineolojî and the Kurdish Women’s Freedom Movement',
  qualityVersion: 1,
);

/// Kurmancîsi bozuk olduğu için oyuncuya gösterilmeyen kayıtların kaynağı.
///
/// 2026-07-30 dil taraması: bu dosyadaki yedi soruda `prompt` ve `answers`
/// alanları Kurmancîde var **olmayan** sözcükler taşıyordu — "Fakltîzm",
/// "Demorkrasîxerbirîna", "Hespê ûrikirî ya leşkerî", "Kîmoka zîvkirî",
/// "Kom-xwebûn rêxistin", "şûnartî", "kendê". Aynı kayıtların
/// `explanationKu`/`explanationTr` alanları düzgün yazılmış; yani bir
/// önceki elden geçirme açıklamaları onarmış, soru ve şıkları atlamış.
///
/// Kurmancî öğreten bir uygulamada oyuncuya uydurma sözcüğü **doğru cevap**
/// diye göstermek, sorunun hiç sorulmamasından kötüdür: oyuncu yanlışı
/// öğrenir ve öğrendiğinden emin olur. Sorular silinmedi — şıkları gerçek
/// Kurmancîyle yeniden yazılana dek inceleme kuyruğunda bekliyor.
/// Geri açmak için: metnini düzelt, `reviewStatus`u `approved` yap.
const _bozukKurmanciBekliyor = QuestionMetadata(
  reviewStatus: ReviewStatus.needsReview,
  dialect: 'Kurmancî',
  sourceTitle: 'Kurmancî metni yeniden yazılmayı bekliyor (2026-07-30)',
  sourceReference:
      'Şıklar ve soru gövdesi Kurmancîde var olmayan sözcükler taşıyor; '
      'açıklama alanları sağlam. copy_language_test bekçisi bkz.',
  qualityVersion: 1,
);

/// İlk editoryal dalga: Kurmancî öncelikli, kaynaklı ve bağlamlı sorular.
/// Eski otomatik havuzdan ayrı tutulur; yeni içerik kalite filtresinden geçmiştir.
const curatedQuestionBank = <QuizQuestion>[
  QuizQuestion(
    id: 'curated_movement_0001',
    category: 'Siyaset',
    // Gövde terimi soruyor, doğru cevap da terimin kendisiydi: soru
    // okumaktan başka bir şey ölçmüyordu (2026-07-26 denetimi). Artık
    // terimin Türkçe karşılığı sorulur.
    prompt: 'Di gotina «Jin, Jiyan, Azadî» de «jiyan» bi Tirkî çi ye?',
    answers: ['yaşam', 'kadın', 'özgürlük', 'örgüt'],
    correctAnswer: 'yaşam',
    promptTr: '«Jin, Jiyan, Azadî» sözündeki «jiyan» Türkçede ne demektir?',
    answersTr: ['yaşam', 'kadın', 'özgürlük', 'örgüt'],
    correctAnswerTr: 'yaşam',
    explanation:
        '«Jiyan» bi Tirkî «yaşam» e. Di vê gotinê de sê têgeh — jin, jiyan û azadî — bi hev ve tên girêdan.',
    difficulty: 1,
    metadata: _anfSource,
    explanationKu:
        '«Jiyan» bi Tirkî «yaşam» e. Di vê gotinê de sê têgeh — jin, jiyan '
        'û azadî — bi hev ve tên girêdan.',
    explanationTr:
        '«Jiyan» Türkçede «yaşam» demektir. Bu sözde üç kavram — kadın, '
        'yaşam ve özgürlük — birbirine bağlanır.',
  ),
  QuizQuestion(
    id: 'curated_movement_0002',
    category: 'Siyaset',
    prompt: 'Peyva Kurmancî «azadî» bi Tirkî çi tê gotin?',
    answers: ['özgürlük', 'takas', 'tarih', 'yol'],
    correctAnswer: 'özgürlük',
    promptTr: 'Kurmancî «azadî» sözcüğü Türkçede ne denir?',
    answersTr: ['özgürlük', 'takas', 'tarih', 'yol'],
    correctAnswerTr: 'özgürlük',
    explanation:
        '«Azadî» wateya azadiyê dide; peyv di slogan û gotûbêja mafan de jî gelek tê bikaranîn.',
    difficulty: 1,
    metadata: _anfSource,
    explanationKu:
        '«Azadî» wateya azadiyê dide; peyv di slogan û gotûbêja mafan de '
        'gelek tê bikaranîn.',
    explanationTr:
        '«Azadî» özgürlük demektir; sözcük sloganlarda ve hak '
        'tartışmalarında sıkça kullanılır.',
  ),
  QuizQuestion(
    id: 'curated_movement_0003',
    category: 'Paradigma',
    prompt:
        'Di gotûbêja jinan de «jineolojî» bi kîjan ravekirinê re zêdetir tê girêdan?',
    answers: [
      'Nêzîkatiya zanistî ya li ser jiyana jinan û civakê',
      'Tenê zanista astronomiyê',
      'Rêbazek ji bo hesabkirina pereyan',
      'Navê celebekî muzîkê',
    ],
    correctAnswer: 'Nêzîkatiya zanistî ya li ser jiyana jinan û civakê',
    promptTr:
        'Kadın tartışmasında «jineolojî» hangi tanımla daha çok ilişkilendirilir?',
    answersTr: [
      'Kadın yaşamı ve toplum üzerine bilimsel yaklaşım',
      'Yalnızca gökbilim',
      'Para hesaplamak için bir yöntem',
      'Bir müzik türünün adı',
    ],
    correctAnswerTr: 'Kadın yaşamı ve toplum üzerine bilimsel yaklaşım',
    explanation:
        'Jineolojî di edebiyata tevgerê de wek nêzîkatiyek ji bo xwendina jiyana jinan, civakê û têkiliyên hêzê tê pênasekirin.',
    difficulty: 3,
    metadata: _anfSource,
    explanationKu:
        'Jineolojî wek nêzîkatiyek ji bo xwendina jiyana jinan, civakê û '
        'têkiliyên hêzê tê pênasekirin.',
    explanationTr:
        'Jineolojî; kadınların yaşamını, toplumu ve güç ilişkilerini okumak '
        'için bir yaklaşım olarak tanımlanır.',
  ),
  QuizQuestion(
    id: 'curated_movement_0004',
    category: 'Siyaset',
    prompt: 'Di civakê de meclîs çi dike?',
    answers: [
      'Cihê ku endam li ser pirsgirêkan diaxivin û biryaran didin',
      'Cihê ku tenê stran têne guhdarîkirin',
      'Navê aliyekî werzîşê',
      'Cihê ku pirtûk bê xwendin tên veşartin',
    ],
    correctAnswer: 'Cihê ku endam li ser pirsgirêkan diaxivin û biryaran didin',
    promptTr: 'Toplumda meclis ne yapar?',
    answersTr: [
      'Üyelerin sorunları konuşup karar aldığı yer',
      'Yalnızca şarkı dinlenen yer',
      'Bir spor dalının adı',
      'Kitapların okunmadan saklandığı yer',
    ],
    correctAnswerTr: 'Üyelerin sorunları konuşup karar aldığı yer',
    explanation:
        '«Meclîs» civîna hevbeş e. Di modelên xwe-rêxistinkirî de meclîs cihê gotûbêj û biryargirtinê ye.',
    difficulty: 2,
    metadata: _anfSource,
    explanationKu:
        '«Meclîs» civîna hevbeş e. Di modelên xwe-rêxistinkirî de meclîs '
        'cihê gotûbêj û biryargirtinê ye.',
    explanationTr:
        '«Meclîs» ortak toplantı demektir. Öz örgütlü modellerde meclis, '
        'tartışma ve karar yeridir.',
  ),
  QuizQuestion(
    id: 'curated_movement_0005',
    category: 'Paradigma',
    prompt: 'Kîjan ravekirin ji bo «xwe-rêxistin» rast e?',
    answers: [
      'Maf û erkên xwe bi hevkarî rêxistin kirin',
      'Biryarên hemû kesan ji kesekê re hiştin',
      'Ji civakê dûrketin',
      'Tenê li ser navên kesan nivîsandin',
    ],
    correctAnswer: 'Maf û erkên xwe bi hevkarî rêxistin kirin',
    promptTr: '«Öz örgütlenme» için hangi tanım doğrudur?',
    answersTr: [
      'Hak ve görevleri dayanışmayla örgütlemek',
      'Herkesin kararını tek kişiye bırakmak',
      'Toplumdan uzaklaşmak',
      'Yalnızca kişi adlarını yazmak',
    ],
    correctAnswerTr: 'Hak ve görevleri dayanışmayla örgütlemek',
    explanation:
        '«Xwe-rêxistin» tê wateya ku kes û kom bi hevkarî kar û biryarên xwe rêxistin dikin.',
    difficulty: 2,
    metadata: _kjarSource,
    explanationKu:
        '«Xwe-rêxistin» tê wateya ku kes û kom bi hevkarî kar û biryarên '
        'xwe bi xwe rêxistin dikin.',
    explanationTr:
        '«Xwe-rêxistin», kişi ve grupların işlerini ve kararlarını '
        'dayanışmayla kendilerinin örgütlemesidir.',
  ),
  QuizQuestion(
    id: 'curated_movement_0006',
    category: 'Paradigma',
    prompt:
        'Di vê hevokê de peyva «berxwedan» çi dide zanîn? «Berxwedana wan dom kir.»',
    answers: [
      'Ragirtina li hember zordariyê',
      'Rêwîtiya bi balafirê',
      'Kirîna tiştan',
      'Xwarina taştê',
    ],
    correctAnswer: 'Ragirtina li hember zordariyê',
    promptTr: 'Şu cümlede «berxwedan» ne anlatır? «Berxwedana wan dom kir.»',
    answersTr: [
      'Baskıya karşı direnmek',
      'Uçakla yolculuk',
      'Alışveriş yapmak',
      'Kahvaltı etmek',
    ],
    correctAnswerTr: 'Baskıya karşı direnmek',
    explanation:
        '«Berxwedan» di vê hevokê de wateya rawestan û li hember zordariyê ragirtinê dide.',
    difficulty: 2,
    metadata: _kjarSource,
    explanationKu:
        '«Berxwedan» di vê hevokê de wateya rawestan û li hember zordariyê '
        'ragirtinê dide.',
    explanationTr:
        '«Berxwedan» bu cümlede direnmek ve baskı karşısında ayakta kalmak '
        'anlamındadır.',
  ),
  QuizQuestion(
    id: 'curated_movement_0007',
    category: 'Siyaset',
    prompt: 'Di zimanê tevgerên civakî de «serhildan» bi kîjan têgehê nêzîk e?',
    answers: [
      'Rakirina civakî li hember zordariyê',
      'Rojekî bêbaran',
      'Lîstikekî zarokan',
      'Rengê kesk',
    ],
    correctAnswer: 'Rakirina civakî li hember zordariyê',
    promptTr:
        'Toplumsal hareketlerin dilinde «serhildan» hangi kavrama yakındır?',
    answersTr: [
      'Baskıya karşı toplumsal ayağa kalkış',
      'Yağmursuz bir gün',
      'Bir çocuk oyunu',
      'Yeşil rengi',
    ],
    correctAnswerTr: 'Baskıya karşı toplumsal ayağa kalkış',
    explanation:
        '«Serhildan» bi rabûn û hereketeke civakî li hember zordariyê re têkildar e. Wateya wê li gorî kontekstê dikare hinekî biguhere.',
    difficulty: 3,
    metadata: _kjarSource,
    explanationKu:
        '«Serhildan» bi rabûn û tevgereke civakî ya li hember zordariyê re '
        'têkildar e; wateya wê li gorî kontekstê diguhere.',
    explanationTr:
        '«Serhildan», baskıya karşı ayaklanma ve toplumsal hareketle '
        'ilgilidir; anlamı bağlama göre değişir.',
  ),
  QuizQuestion(
    id: 'curated_movement_0008',
    category: 'Çand',
    prompt:
        'Di wêneyê de agirê Newrozê tê dîtin. Di çand û hafizaya civakî de agir bi kîjan têgehê re zêdetir tê girêdan?',
    answers: [
      'Hêvî û vejîn',
      'Bêdengî û ji bîrkirin',
      'Bazar û bazirgani',
      'Zivistan û sarma',
    ],
    correctAnswer: 'Hêvî û vejîn',
    promptTr:
        'Görselde Newroz ateşi görünüyor. Kültürde ve toplumsal bellekte ateş hangi kavramla daha çok ilişkilendirilir?',
    answersTr: [
      'Umut ve yeniden doğuş',
      'Sessizlik ve unutuş',
      'Pazar ve ticaret',
      'Kış ve soğuk',
    ],
    correctAnswerTr: 'Umut ve yeniden doğuş',
    explanation:
        'Agirê Newrozê di gelek vegotinên Kurdan de bi ronahî, hêvî û vejîna nû re tê girêdan.',
    difficulty: 2,
    type: QuestionType.visual,
    imageUrl: 'asset://assets/question_images/newroz.webp',
    metadata: _kjarSource,
    explanationKu:
        'Agirê Newrozê di gelek vegotinên kurdan de bi ronahî, hêvî û '
        'vejîna nû re tê girêdan.',
    explanationTr:
        'Newroz ateşi birçok Kürt anlatısında ışıkla, umutla ve yeniden '
        'doğuşla ilişkilendirilir.',
  ),
  QuizQuestion(
    id: 'curated_movement_0009',
    category: 'Çand',
    prompt: '«Newroz» ji aliyê wateya peyvê ve bi kîjan ravekirinê re nêzîk e?',
    answers: ['Roja nû', 'Şeva dirêj', 'Bara kevn', 'Dengê bilind'],
    correctAnswer: 'Roja nû',
    promptTr: '«Newroz» sözcük anlamı bakımından hangi karşılığa yakındır?',
    answersTr: ['Yeni gün', 'Uzun gece', 'Eski yük', 'Yüksek ses'],
    correctAnswerTr: 'Yeni gün',
    explanation:
        'Newroz bi têgeha «roja nû» re tê şirovekirin û wek destpêka demsala biharê tê pîroz kirin.',
    difficulty: 2,
    metadata: _kongraStarSource,
    explanationKu:
        'Newroz bi têgeha «roja nû» re tê şirovekirin û wek destpêka '
        'demsala biharê tê pîrozkirin.',
    explanationTr:
        'Newroz «yeni gün» kavramıyla açıklanır ve baharın başlangıcı '
        'olarak kutlanır.',
  ),
  QuizQuestion(
    id: 'curated_movement_0010',
    category: 'Siyaset',
    prompt: 'Peyva Kurmancî «rêxistin» bi Tirkî çi tê gotin?',
    answers: ['örgüt', 'su', 'kitap', 'yağmur'],
    correctAnswer: 'örgüt',
    promptTr: 'Kurmancî «rêxistin» sözcüğü Türkçede ne denir?',
    answersTr: ['örgüt', 'su', 'kitap', 'yağmur'],
    correctAnswerTr: 'örgüt',
    explanation: '«Rêxistin» wateya rêkxistin û rêxistina kesan an koman dide.',
    difficulty: 1,
    type: QuestionType.visual,
    imageUrl: 'asset://assets/question_images/cat_siyaset.webp',
    metadata: _kongraStarSource,
    explanationKu:
        '«Rêxistin» wateya rêkxistinê û rêxistina kes an koman dide.',
    explanationTr:
        '«Rêxistin», düzenleme ve kişilerin ya da grupların örgütlenmesi'
        'anlamına gelir.',
  ),
  QuizQuestion(
    id: 'curated_movement_0011',
    category: 'Paradigma',
    prompt:
        'Kîjan hevok li ser «demokratîk konfederalîzm» bi awayekî herî rast têgihiştinê dide?',
    answers: [
      'Modela hevkarî û meclîsan a ku ji civakê ber bi jor ve ava dibe',
      'Rêbazek ku hemû biryarên civakê dide destê yek kesî',
      'Tenê rêbazek ji bo hilbijartina futbolê',
      'Navê pergaleke meteorolojiyê',
    ],
    correctAnswer:
        'Modela hevkarî û meclîsan a ku ji civakê ber bi jor ve ava dibe',
    promptTr:
        '«Demokratik konfederalizm» için hangi cümle en doğru anlayışı verir?',
    answersTr: [
      'Toplumdan yukarı doğru kurulan meclis ve dayanışma modeli',
      'Toplumun bütün kararlarını tek kişiye veren yöntem',
      'Yalnızca futbol seçimi için bir yöntem',
      'Bir meteoroloji sisteminin adı',
    ],
    correctAnswerTr:
        'Toplumdan yukarı doğru kurulan meclis ve dayanışma modeli',
    explanation:
        'Di nivîsarên tevgerê de ev têgeh bi meclîs, komîn, hevkarî û biryargirtina ji jêr ve tê şirovekirin.',
    difficulty: 4,
    metadata: _kongraStarSource,
    explanationKu:
        'Ev têgeh bi meclîs, komîn, hevkarî û biryargirtina ji jêr ve tê '
        'şirovekirin.',
    explanationTr:
        'Bu kavram meclis, komün, dayanışma ve aşağıdan karar almayla '
        'açıklanır.',
  ),
  QuizQuestion(
    id: 'curated_movement_0012',
    category: 'Siyaset',
    prompt:
        'Di hevoka «Jin di meclîsê de dengê xwe bilind kir» de «dengê xwe bilind kir» çi tê wate kirin?',
    answers: [
      'Raman û daxwaza xwe eşkere kir',
      'Bi dengê muzîkê razî bû',
      'Ji meclîsê derket',
      'Pirtûkek danî serê xwe',
    ],
    correctAnswer: 'Raman û daxwaza xwe eşkere kir',
    promptTr:
        '«Jin di meclîsê de dengê xwe bilind kir» cümlesinde «dengê xwe bilind kir» ne anlama gelir?',
    answersTr: [
      'Düşüncesini ve talebini açıkça dile getirdi',
      'Müziğin sesine razı oldu',
      'Meclisten çıktı',
      'Başına kitap koydu',
    ],
    correctAnswerTr: 'Düşüncesini ve talebini açıkça dile getirdi',
    explanation:
        'Di zimanê civakî de «dengê xwe bilind kirin» pir caran wateya axaftin û parastina maf û daxwazên xwe dide.',
    difficulty: 3,
    metadata: _kongraStarSource,
    explanationKu:
        'Di zimanê civakî de «dengê xwe bilind kirin» pir caran wateya '
        'axaftin û parastina maf û daxwazên xwe dide.',
    explanationTr:
        'Toplumsal dilde «sesini yükseltmek» çoğu zaman konuşmak ve kendi '
        'hak ve taleplerini savunmak demektir.',
  ),
  QuizQuestion(
    id: 'curated_movement_0013',
    category: 'Ziman',
    prompt:
        'Kîjan hevok ji bo fêmkirina têkiliya ziman û nasnameyê herî guncaw e?',
    answers: [
      'Ziman dikare hafiza, çand û nasnameya civakê hilgire',
      'Ziman tenê ji bo hesabkirinê ye',
      'Ziman bi çandê re têkiliya nîne',
      'Hemû ziman di hemû cihan de yek in',
    ],
    correctAnswer: 'Ziman dikare hafiza, çand û nasnameya civakê hilgire',
    promptTr:
        'Dil ile kimlik arasındaki ilişkiyi anlamak için hangi cümle en uygundur?',
    answersTr: [
      'Dil toplumun belleğini, kültürünü ve kimliğini taşıyabilir',
      'Dil yalnızca hesap yapmak içindir',
      'Dilin kültürle ilişkisi yoktur',
      'Bütün diller her yerde aynıdır',
    ],
    correctAnswerTr:
        'Dil toplumun belleğini, kültürünü ve kimliğini taşıyabilir',
    explanation:
        'Ziman tenê amûra ragihandinê nîne; ew dikare çîrok, bîranîn û awayê dîtina civakê jî hilgire.',
    difficulty: 3,
    metadata: _jineolojiSource,
    explanationKu:
        'Ziman tenê amûra ragihandinê nîne; ew çîrok, bîranîn û awayê '
        'dîtina civakê jî hildigire.',
    explanationTr:
        'Dil yalnızca bir iletişim aracı değildir; hikâyeyi, hafızayı ve '
        'toplumun bakış biçimini de taşır.',
  ),
  QuizQuestion(
    id: 'curated_movement_0014',
    category: 'Siyaset',
    prompt:
        '«Hevserokî» di rêxistina civakî de bi kîjan armancê re têkildar e?',
    answers: [
      'Parvekirina berpirsiyariyê di navbera du hevserokan de',
      'Hilweşandina hemû meclîsan',
      'Bijartina tenê yek deng',
      'Rêxistina çalakiyên werzîşê',
    ],
    correctAnswer: 'Parvekirina berpirsiyariyê di navbera du hevserokan de',
    promptTr: 'Toplumsal örgütlenmede «eşbaşkanlık» hangi amaçla ilgilidir?',
    answersTr: [
      'Sorumluluğun iki eşbaşkan arasında paylaşılması',
      'Bütün meclislerin dağıtılması',
      'Yalnızca tek bir sesin seçilmesi',
      'Spor etkinliklerinin düzenlenmesi',
    ],
    correctAnswerTr: 'Sorumluluğun iki eşbaşkan arasında paylaşılması',
    explanation:
        'Hevserokî têgehek e ku berpirsiyariya rêveberiyê di navbera du kesan de parve dike; di nîqaşên tevgerê de bi wekheviyê re tê girêdan.',
    difficulty: 4,
    metadata: _jineolojiSource,
    explanationKu:
        'Hevserokî berpirsiyariya rêveberiyê di navbera du kesan de parve '
        'dike; bi wekheviyê re tê girêdan.',
    explanationTr:
        'Eş başkanlık, yönetim sorumluluğunu iki kişi arasında paylaştırır '
        've eşitlikle ilişkilendirilir.',
  ),
  QuizQuestion(
    id: 'curated_movement_0015',
    category: 'Paradigma',
    prompt:
        'Rast e yan şaş e? «Xwe-rêxistin tenê ji bo kesên ku li bajarên mezin dijîn e.»',
    answers: ['Rast e', 'Şaş e'],
    correctAnswer: 'Şaş e',
    promptTr:
        'Doğru mu yanlış mı? «Öz örgütlenme yalnızca büyük şehirlerde yaşayanlar içindir.»',
    answersTr: ['Doğru', 'Yanlış'],
    correctAnswerTr: 'Yanlış',
    explanation:
        'Xwe-rêxistin têgehek e ku dikare di cihên cuda de, di nav kom û civakan de, bi awayên cuda were bikaranîn.',
    difficulty: 2,
    type: QuestionType.trueFalse,
    metadata: _jineolojiSource,
    explanationKu:
        'Xwe-rêxistin di cihên cuda de, di nav kom û civakan de bi awayên '
        'cuda tê bikaranîn.',
    explanationTr:
        'Öz örgütlenme; farklı yerlerde, farklı grup ve toplumlarda farklı '
        'biçimlerde uygulanır.',
  ),
  QuizQuestion(
    id: 'curated_movement_0016',
    category: 'Siyaset',
    prompt:
        'Rast e yan şaş e? «Berxwedan» her tim tenê bi awayê çekdarî tê pênasekirin.',
    answers: ['Rast e', 'Şaş e'],
    correctAnswer: 'Şaş e',
    promptTr:
        'Doğru mu yanlış mı? «Direniş» her zaman yalnızca silahlı biçimde tanımlanır.',
    answersTr: ['Doğru', 'Yanlış'],
    correctAnswerTr: 'Yanlış',
    explanation:
        'Berxwedan dikare zimanî, çandî, siyasî, civakî û gelek awayên din hebin; ew ne tenê bi awayekê tê pênasekirin.',
    difficulty: 3,
    type: QuestionType.trueFalse,
    metadata: _jineolojiSource,
    explanationKu:
        'Berxwedan dikare zimanî, çandî, siyasî an civakî be; ew ne tenê bi '
        'awayekî tê pênasekirin.',
    explanationTr:
        'Direniş dilsel, kültürel, siyasal ya da toplumsal olabilir; tek '
        'bir biçimle tanımlanmaz.',
  ),
  QuizQuestion(
    id: 'curated_movement_0017',
    category: 'Dîrok',
    prompt:
        'Di nivîsandina dîroka tevgera jinan de, çima şahidî û bîranînên jinan girîng in?',
    answers: [
      'Ji ber ku ezmûn û dengê jinan di dîrokê de xuya dikin',
      'Ji ber ku tenê navên bajarên mezin têne nivîsandin',
      'Ji ber ku hemû bîranîn wek hev in',
      'Ji ber ku dîrok ne pêdivî ye ku were lêkolînkirin',
    ],
    correctAnswer: 'Ji ber ku ezmûn û dengê jinan di dîrokê de xuya dikin',
    promptTr:
        'Kadın hareketinin tarihi yazılırken kadınların tanıklığı ve anıları niçin önemlidir?',
    answersTr: [
      'Kadınların deneyimi ve sesi tarihte görünür olduğu için',
      'Yalnızca büyük şehirlerin adları yazıldığı için',
      'Bütün anılar birbirinin aynı olduğu için',
      'Tarihin araştırılmasına gerek olmadığı için',
    ],
    correctAnswerTr: 'Kadınların deneyimi ve sesi tarihte görünür olduğu için',
    explanation:
        'Bîranîn û şahidî dikarin ezmûnên kesên ku di nivîsarên fermî de kêm tên dîtin nîşan bidin.',
    difficulty: 3,
    metadata: _anfSource,
    explanationKu:
        'Bîranîn û şahidî dikarin ezmûnên kesên ku di nivîsarên fermî de '
        'kêm tên dîtin nîşan bidin.',
    explanationTr:
        'Hafıza ve tanıklık, resmî metinlerde az görünen kişilerin '
        'deneyimlerini görünür kılabilir.',
  ),
  QuizQuestion(
    id: 'curated_movement_0018',
    category: 'Cografya',
    prompt:
        '«Rojava» di navbera têgehên herêmî de bi kîjan aliyê re têkildar e?',
    answers: [
      'Rojavayê Kurdistanê',
      'Rojhilatê Kurdistanê',
      'Bakurê Kurdistanê',
      'Başûrê Kurdistanê',
    ],
    correctAnswer: 'Rojavayê Kurdistanê',
    promptTr: '«Rojava» bölge kavramları arasında hangi yönle ilgilidir?',
    answersTr: [
      'Rojavayê Kurdistanê',
      'Rojhilatê Kurdistanê',
      'Bakurê Kurdistanê',
      'Başûrê Kurdistanê',
    ],
    correctAnswerTr: 'Rojavayê Kurdistanê',
    explanation:
        '«Rojava» di Kurmancî de bi wateya rojava û bi navê herêmî yê Rojavayê Kurdistanê tê bikaranîn.',
    difficulty: 2,
    metadata: _kongraStarSource,
    explanationKu:
        '«Rojava» di Kurmancî de hem aliyê rojava hem navê herêmî yê '
        'Rojavayê Kurdistanê ye.',
    explanationTr:
        '«Rojava» Kurmancîde hem batı yönü hem de Batı Kürdistan’ın '
        'bölgesel adıdır.',
  ),
  QuizQuestion(
    id: 'curated_movement_0019',
    category: 'Muzîk',
    prompt: 'Di çand û berxwedanê de stran dikare çi bike?',
    answers: [
      'Bîranîn û peyamê bi dengê bigihîne',
      'Tenê navê amûran biguhere',
      'Hemû zimanên civakê ji holê rake',
      'Ragihandina di navbera mirovan de qebûl neke',
    ],
    correctAnswer: 'Bîranîn û peyamê bi dengê bigihîne',
    promptTr: 'Kültürde ve direnişte şarkı ne yapabilir?',
    answersTr: [
      'Belleği ve mesajı sesle taşıyabilir',
      'Yalnızca çalgıların adını değiştirir',
      'Toplumun bütün dillerini ortadan kaldırır',
      'İnsanlar arasındaki iletişimi reddeder',
    ],
    correctAnswerTr: 'Belleği ve mesajı sesle taşıyabilir',
    explanation:
        'Stran dikare bîranîn, hest û peyamên civakî bi awayekî dengdar û hevpar ragihîne.',
    difficulty: 3,
    metadata: _kjarSource,
    explanationKu:
        'Stran dikare bîranîn, hest û peyamên civakî bi awayekî dengdar û '
        'hevpar ragihîne.',
    explanationTr:
        'Şarkı; hafızayı, duyguyu ve toplumsal mesajı sesle ve ortaklaşa '
        'iletebilir.',
  ),
  QuizQuestion(
    id: 'curated_movement_0020',
    category: 'Edebiyat',
    prompt:
        'Kîjan cureyê nivîsê dikare hestên azadî û bîranînê bi zimanê hunerî vegerîne?',
    answers: [
      'Helbest',
      'Raporê hesabê',
      'Lîsteya bazarê',
      'Rêbernameya rêwîtiyê',
    ],
    correctAnswer: 'Helbest',
    promptTr:
        'Hangi yazı türü özgürlük ve bellek duygusunu sanatsal dille aktarabilir?',
    answersTr: [
      'Şiir',
      'Hesap raporu',
      'Alışveriş listesi',
      'Yolculuk rehberi',
    ],
    correctAnswerTr: 'Şiir',
    explanation:
        'Helbest dikare hest, bîranîn û daxwazên civakî bi zimanekî wêjeyî û xeyalî vegerîne.',
    difficulty: 2,
    metadata: _jineolojiSource,
    explanationKu:
        'Helbest dikare hest, bîranîn û daxwazên civakî bi zimanekî wêjeyî '
        'vebêje.',
    explanationTr:
        'Şiir; duyguyu, hafızayı ve toplumsal talebi edebî bir dille '
        'anlatabilir.',
  ),
  // ── Paradigma ────────────────────────────────────────────────────────────
  QuizQuestion(
    id: 'curated_paradigma_0001',
    category: 'Paradigma',
    prompt: 'Peyva «jineolojî» çi dihundirîne?',
    answers: [
      'Zanistiya jinê',
      'Zanistiya azadiyê',
      'Zanistiya xwezayê',
      'Zanistiya hunerê',
    ],
    correctAnswer: 'Zanistiya jinê',
    promptTr: '«Jineolojî» sözcüğü neyi içerir?',
    answersTr: [
      'Kadın bilimi',
      'Özgürlük bilimi',
      'Doğa bilimi',
      'Sanat bilimi',
    ],
    correctAnswerTr: 'Kadın bilimi',
    explanation:
        'Jineolojî ji «jin» û «lojî» (zanist) pêk tê; zanistiya jinê û rêxistinkirina civaka azad e.',
    difficulty: 1,
    metadata: _bozukKurmanciBekliyor,
    explanationKu:
        'Jineolojî ji «jin» û «lojî» (zanist) pêk tê; zanistiya jinê û '
        'rêxistinkirina civaka azad e.',
    explanationTr:
        'Jineolojî «jin» (kadın) ve «loji» (bilim) sözcüklerinden oluşur; '
        'kadın bilimi ve özgür toplumun örgütlenmesidir.',
  ),
  QuizQuestion(
    id: 'curated_paradigma_0002',
    category: 'Paradigma',
    prompt: 'Kîjan têgeh bi "konfederalîzm"ê re herî nêzîk e?',
    answers: [
      'Kom-xwebûn rêxistin',
      'Bikarhnêrîn',
      'Hukmêkerek',
      'Kolonyalîzm',
    ],
    correctAnswer: 'Kom-xwebûn rêxistin',
    promptTr: 'Hangi kavram «konfederalizm»e en yakındır?',
    answersTr: [
      'Topluluk özyönetimi örgütlenmesi',
      'Tüketicilik',
      'Tek bir yönetici',
      'Sömürgecilik',
    ],
    correctAnswerTr: 'Topluluk özyönetimi örgütlenmesi',
    explanation:
        'Konfederalîzmek modela ku rêxistinên xwe-bixwe yên herêmî yên xwebûn-bixwe li ser wekheviyê tên girêdan e.',
    difficulty: 2,
    metadata: _bozukKurmanciBekliyor,
    explanationKu:
        'Konfederalîzm modelek e ku rêxistinên herêmî yên xwe-bi-xwe li ser '
        'bingeha wekheviyê bi hev ve girê dide.',
    explanationTr:
        'Konfederalizm, yerel öz örgütlenmeleri eşitlik temelinde birbirine '
        'bağlayan bir modeldir.',
  ),
  QuizQuestion(
    id: 'curated_paradigma_0003',
    category: 'Paradigma',
    prompt: '«Hevaltî» di vê paradîgmayê de çi dixwaze?',
    answers: [
      'Wekhevî û pîvana rêxistinê',
      'Tenê pûl bi pûl',
      'Betalbûna hemû endamên rêxistinê',
      'Mîrata dadwerî',
    ],
    correctAnswer: 'Wekhevî û pîvana rêxistinê',
    promptTr: 'Bu paradigmada «hevaltî» (yoldaşlık) neyi amaçlar?',
    answersTr: [
      'Eşitlik ve örgütlenme ölçüsü',
      'Yalnızca puan puan ilerlemek',
      'Örgütün bütün üyelerinin ayrılması',
      'Yargı mirası',
    ],
    correctAnswerTr: 'Eşitlik ve örgütlenme ölçüsü',
    explanation:
        'Hevaltî endamên rêxistinê li ser bingeha wekheviyê digihîne hev, ne li ser serdestiyê.',
    difficulty: 2,
    metadata: _jineolojiSource,
    explanationKu:
        'Hevaltî endamên rêxistinê li ser bingeha wekheviyê digihîne hev, '
        'ne li ser serdestiyê.',
    explanationTr:
        'Yoldaşlık, örgüt üyelerini tahakküm üzerine değil eşitlik üzerine '
        'birleştirir.',
  ),
  QuizQuestion(
    id: 'curated_paradigma_0004',
    category: 'Paradigma',
    prompt: 'Abdullah Öcalan di gotarên xwe de kîjan «-îzm»ê pêşniyar kir?',
    answers: [
      'Konfederalîzma demokratîk',
      'Fakltîzm',
      'Fermendîzm',
      'Medyatîkdemokrasî',
    ],
    correctAnswer: 'Konfederalîzma demokratîk',
    promptTr: 'Abdullah Öcalan yazılarında hangi «-izm»i önerdi?',
    answersTr: [
      'Demokratik konfederalizm',
      'Faklitizm',
      'Fermendizm',
      'Medyatik demokrasi',
    ],
    correctAnswerTr: 'Demokratik konfederalizm',
    explanation:
        'Di «Demokratik Konfederalîzm» de civak bi şiklê rêxistinên xwe-bixwe têne rêxistinkirin, ne dewletî.',
    difficulty: 2,
    metadata: _bozukKurmanciBekliyor,
    explanationKu:
        'Di konfederalîzma demokratîk de civak bi rêxistinên xwe-bi-xwe tê '
        'organîzekirin, ne bi dewletê.',
    explanationTr:
        'Demokratik konfederalizmde toplum devletle değil, öz '
        'örgütlenmelerle düzenlenir.',
  ),
  QuizQuestion(
    id: 'curated_paradigma_0005',
    category: 'Paradigma',
    prompt: 'Civaka takekesî li şûna netewe-dewletê çi pêşniyar dike?',
    answers: [
      'Birayên xwe rêxistinbranî',
      'Demokrasîxerbirîna gelemperî',
      'Hespê ûrikirî ya leşkerî',
      'Hiqûqa malbatê ya nepenî',
    ],
    correctAnswer: 'Demokrasîxerbirîna gelemperî',
    promptTr: 'Ulus-devlet yerine hangi model önerilir?',
    answersTr: [
      'Kardeşliğin örgütsel dağıtımı',
      'Toplumun geneline yayılan demokratikleşme',
      'Askerî hiyerarşi',
      'Gizli aile hukuku',
    ],
    correctAnswerTr: 'Toplumun geneline yayılan demokratikleşme',
    explanation:
        'Paradîgma demokratîk a civakî rêxistinên demokratîk û rihevketa gelemperî hene dihundirîne.',
    difficulty: 3,
    metadata: _bozukKurmanciBekliyor,
    explanationKu:
        'Paradîgmaya civaka demokratîk rêxistinên demokratîk û biryardana '
        'gelemperî digire nav xwe.',
    explanationTr:
        'Demokratik toplum paradigması, demokratik örgütlenmeleri ve ortak '
        'karar almayı kapsar.',
  ),
  QuizQuestion(
    id: 'curated_paradigma_0006',
    category: 'Paradigma',
    prompt: 'Jineolojî di Şoreşa Rojavayê de çi rollî leyîst?',
    answers: [
      'Avakirina parastina jinê û şoreşa civakî',
      'Tenê kontrolên leşkerî',
      'Dîrok-Nivîskarî',
      'Peydakerî û bazirganî',
    ],
    correctAnswer: 'Avakirina parastina jinê û şoreşa civakî',
    promptTr: 'Jineolojî Rojava Devrimi\'nde hangi rolü oynadı?',
    answersTr: [
      'Kadın savunmasının ve toplumsal devrimin kurulması',
      'Yalnızca askerî denetim',
      'Tarih yazıcılığı',
      'Tedarik ve ticaret',
    ],
    correctAnswerTr: 'Kadın savunmasının ve toplumsal devrimin kurulması',
    explanation:
        'Jineolojî li Rojavayê Kurdistanê bû pîvana rastînên mirovan û azadiya ziman, şoreş û rêxistinên jin.',
    difficulty: 2,
    metadata: _kongraStarSource,
    explanationKu:
        'Jineolojî li Rojavayê Kurdistanê bû pîvana azadiya jinê, ziman û '
        'rêxistinbûna wan.',
    explanationTr:
        'Jineolojî, Batı Kürdistan’da kadın özgürlüğünün, dilinin ve '
        'örgütlenmesinin ölçüsü hâline geldi.',
  ),
  QuizQuestion(
    id: 'curated_paradigma_0007',
    category: 'Paradigma',
    prompt: 'Bê "ekolojî" di paradîgmayê de çi wateye?',
    answers: [
      'Hemahengbûna jiyanê bi xwezayê re (ne serdestî)',
      'Tenê kimya',
      'Bazirganîna aboriyê',
      'Veşartina topan',
    ],
    correctAnswer: 'Hemahengbûna jiyanê bi xwezayê re (ne serdestî)',
    promptTr: 'Paradigmada «ekoloji» ne anlama gelir?',
    answersTr: [
      'Yaşamın doğayla uyumu (tahakküm değil)',
      'Yalnızca kimya',
      'Ekonomik ticaret',
      'Topların saklanması',
    ],
    correctAnswerTr: 'Yaşamın doğayla uyumu (tahakküm değil)',
    explanation:
        'Ekolojiyê demokratîk dixwaze ku mirov bi xweza re lihevhatî bixwîne, tune serdestiyê.',
    difficulty: 2,
    metadata: _academikSource,
    explanationKu:
        'Ekolojiya demokratîk dixwaze mirov bi xwezayê re lihevhatî bijî, '
        'ne bi serdestiyê.',
    explanationTr:
        'Demokratik ekoloji, insanın doğaya tahakküm etmeden onunla uyum '
        'içinde yaşamasını ister.',
  ),
  QuizQuestion(
    id: 'curated_paradigma_0008',
    category: 'Paradigma',
    prompt:
        'Peyva "pîvana rast" ji bo rêxistinkirina civaka demokratîk çi tê wateyek?',
    answers: [
      'Yekserîn û şiklê radestî',
      'Konsensus û şûnartî',
      'Hiqûqa serdestê meclîsê',
      'Girtinên gelemperî yên girtîgehê',
    ],
    correctAnswer: 'Konsensus û şûnartî',
    promptTr: 'Demokratik toplumu örgütlemede «doğru ölçü» ne anlama gelir?',
    answersTr: [
      'Tek elden buyruk ve teslimiyet',
      'Uzlaşı ve yerinden karar',
      'Meclis başkanının üstünlüğü',
      'Toplu tutuklamalar',
    ],
    correctAnswerTr: 'Uzlaşı ve yerinden karar',
    explanation:
        'Biryarên civakî bi şiklê konsensus û şûnartî tên standin, ne bi werdêjin.',
    difficulty: 3,
    metadata: _bozukKurmanciBekliyor,
    explanationKu:
        'Biryarên civakî bi rêya lihevkirin û gotûbêjê tên girtin, ne bi '
        'ferzkirinê.',
    explanationTr:
        'Toplumsal kararlar dayatmayla değil, uzlaşı ve tartışmayla alınır.',
  ),
  QuizQuestion(
    id: 'curated_paradigma_0009',
    category: 'Paradigma',
    prompt: 'Kîjan bûyer bi sloganê "Jin, Jiyan, Azadî" re pir girêdayî ye?',
    answers: [
      'Berxwedana jinên Kobanî (2014)',
      'Peymana Lozanê (1923)',
      'Şoreşa Şêx Said (1925)',
      'Damezirandina Komara Mehabadê (1946)',
    ],
    correctAnswer: 'Berxwedana jinên Kobanî (2014)',
    promptTr: 'Hangi olay «Jin, Jiyan, Azadî» sloganıyla çok bağlantılıdır?',
    answersTr: [
      'Kobanê\'de kadınların direnişi (2014)',
      'Lozan Antlaşması (1923)',
      'Şêx Said Hareketi (1925)',
      'Mehabad Cumhuriyeti\'nin kuruluşu (1946)',
    ],
    correctAnswerTr: 'Kobanê\'de kadınların direnişi (2014)',
    explanation:
        'Jinên di şerê Kobanî de gayeyên azadî û berxwedanê bi xwe-şehîdî li ber xwe dan û bûne ramana jin, jiyan, azadî.',
    difficulty: 2,
    metadata: _kjarSource,
    explanationKu:
        'Jinên di berxwedana Kobanê de bûne sembola gotina «jin, jiyan, '
        'azadî».',
    explanationTr:
        'Kobanê direnişindeki kadınlar «jin, jiyan, azadî» sözünün simgesi '
        'hâline geldi.',
  ),
  QuizQuestion(
    id: 'curated_paradigma_0010',
    category: 'Paradigma',
    prompt: 'Sembola jinên Şoreşa Rojavayê aliyê çi li ser kendê ye?',
    answers: [
      'Saltê rengîn',
      'Hirça mezin',
      'Li xebatê rengîn û alîserdestiyê jin',
      'Kîmoka zîvkirî',
    ],
    correctAnswer: 'Li xebatê rengîn û alîserdestiyê jin',
    promptTr: 'Rojava Devrimi\'nde kadınların simgesi neyi öne çıkarır?',
    answersTr: [
      'Renkli bir kumaş',
      'Büyük bir ayı',
      'Emekte ve öz savunmada yer alan kadın',
      'Gümüş bir takı',
    ],
    correctAnswerTr: 'Emekte ve öz savunmada yer alan kadın',
    explanation:
        'Sembola rengîn a jinên parastina jinê ye, ku azadiyê û bicihbûna civakê destnîşan dike.',
    difficulty: 2,
    metadata: _bozukKurmanciBekliyor,
    explanationKu:
        'Sembol nîşana parastina jinê ye û azadî û cihgirtina wê ya civakî '
        'destnîşan dike.',
    explanationTr:
        'Simge, kadın savunmasının işaretidir ve kadının özgürlüğünü ile '
        'toplumsal yerini gösterir.',
  ),
  // ── Siyaset ─────────────────────────────────────────────────────────────
  QuizQuestion(
    id: 'curated_siyaset_0001',
    category: 'Siyaset',
    prompt: 'Komara Mehabad kengî hat îlan kirin?',
    answers: ['1946', '1925', '1961', '1984'],
    correctAnswer: '1946',
    promptTr: 'Mehabad Cumhuriyeti ne zaman ilan edildi?',
    answersTr: ['1946', '1925', '1961', '1984'],
    correctAnswerTr: '1946',
    explanation:
        'Komara Mehabad (22ê Çileya 1946 — 15ê Kanûna 1946) li rojhilatê Kurdistanê yekemîn komara kurdî ye.',
    difficulty: 2,
    metadata: _academikSource,
    explanationKu:
        'Komara Mehabadê (1946) li rojhilatê Kurdistanê yekem komara kurdî '
        'ye.',
    explanationTr:
        'Mehabad Cumhuriyeti (1946), Doğu Kürdistan’daki ilk Kürt '
        'cumhuriyetidir.',
  ),
  QuizQuestion(
    id: 'curated_siyaset_0002',
    category: 'Siyaset',
    prompt: 'Komara Mehabadê aliyê kê ve hat serokîtî?',
    answers: [
      'Qazî Mihemed',
      'Şêx Mehmûd Berzencî',
      'Simko Şikak',
      'Mistefa Barzanî',
    ],
    correctAnswer: 'Qazî Mihemed',
    promptTr: 'Mehabad Cumhuriyeti\'ne kim başkanlık etti?',
    answersTr: [
      'Qazî Mihemed',
      'Şêx Mehmûd Berzencî',
      'Simko Şikak',
      'Mistefa Barzanî',
    ],
    correctAnswerTr: 'Qazî Mihemed',
    explanation:
        'Qazî Mihemed (1893 — 1947) serokdarê Komara Mehabadê bû, di 31ê Adara 1947an de hat darvekirin.',
    difficulty: 2,
    metadata: _academikSource,
    explanationKu:
        'Qazî Mihemed (1893–1947) serokê Komara Mehabadê bû û piştî '
        'hilweşandina komarê hat îdamkirin.',
    explanationTr:
        'Qazî Mihemed (1893–1947) Mehabad Cumhuriyeti’nin lideriydi ve '
        'cumhuriyetin yıkılışından sonra idam edildi.',
  ),
  QuizQuestion(
    id: 'curated_siyaset_0003',
    category: 'Siyaset',
    prompt: 'Peymana Sêvrê (1920) ji bo kurdan soza çi da?',
    answers: [
      'Xweseriya herêmî û îhtîmala serxwebûnê',
      'Tekasîkirina bajarên kurdan',
      'Rakirina zimanê kurdî',
      'Girêdana Kurdistanê bi Fransayê ve',
    ],
    correctAnswer: 'Xweseriya herêmî û îhtîmala serxwebûnê',
    promptTr: 'Sevr Antlaşması (1920) Kürtlere neyin sözünü verdi?',
    answersTr: [
      'Bölgesel özerklik ve bağımsızlık ihtimali',
      'Kürt şehirlerinin birleştirilmesi',
      'Kürtçenin kaldırılması',
      'Kurdistanê\'nin Fransa\'ya bağlanması',
    ],
    correctAnswerTr: 'Bölgesel özerklik ve bağımsızlık ihtimali',
    explanation:
        'Peymana Sêvrê (1920) ji Kurdistanê re xweseriyek soz da û rê li ber serxwebûnê vekir, lê Peymana Lozanê (1923) ev soz betal kir.',
    difficulty: 3,
    metadata: _academikSource,
    explanationKu:
        'Peymana Sevrê (1920) ji kurdan re xweserî soz da, lê Peymana '
        'Lozanê (1923) ev soz betal kir.',
    explanationTr:
        'Sevr Antlaşması (1920) Kürtlere özerklik sözü verdi, ancak Lozan '
        'Antlaşması (1923) bu sözü geçersiz kıldı.',
  ),
  QuizQuestion(
    id: 'curated_siyaset_0004',
    category: 'Siyaset',
    prompt:
        'Herêma Kurdistanê (Îraq) di çi salî de xweseriya xwe bi dest xist?',
    answers: ['1970', '1991', '2003', '2005'],
    correctAnswer: '1970',
    promptTr:
        'Kurdistan Bölgesi (Irak) hangi yılki anlaşmayla özerklik sözü aldı?',
    answersTr: ['1970', '1991', '2003', '2005'],
    correctAnswerTr: '1970',
    explanation:
        'Di 1970î de Şoreşa Îraqê li herêma Kurdistanê dest bi xweseriyê kir; paşê di 1991î de ew herêm bû herêmî îraqî xwe-bixwe.',
    difficulty: 2,
    metadata: _academikSource,
    explanationKu:
        'Di 1970î de li Iraqê ji bo Kurdistanê xweserî hat pejirandin; di '
        '1991ê de herêm bi rastî xwe bi xwe rêve bir.',
    explanationTr:
        '1970’te Irak’ta Kürdistan için özerklik kabul edildi; 1991’de '
        'bölge fiilen kendi kendini yönetmeye başladı.',
  ),
  QuizQuestion(
    id: 'curated_siyaset_0005',
    category: 'Siyaset',
    prompt: 'Şerê Kobanê yê li dijî DAIŞê çi salî dest pê kir?',
    answers: ['2014', '2003', '2011', '2017'],
    correctAnswer: '2014',
    promptTr: 'Kobanê\'de DAİŞ\'e karşı savaş hangi yıl başladı?',
    answersTr: ['2014', '2003', '2011', '2017'],
    correctAnswerTr: '2014',
    explanation:
        'Şerê Kobanê (Îlon 2014 — Adar 2015) roleke girîng lîst di têkoşîna li dijî DAIŞê de.',
    difficulty: 2,
    metadata: _kjarSource,
    explanationKu:
        'Berxwedana Kobanê (2014–2015) di têkoşîna li dijî DAIŞê de roleke '
        'girîng lîst.',
    explanationTr:
        'Kobanê direnişi (2014–2015), IŞİD’e karşı mücadelede önemli bir '
        'rol oynadı.',
  ),
  QuizQuestion(
    id: 'curated_siyaset_0006',
    category: 'Siyaset',
    prompt: 'Konfederalîzma demokratîk li kîjan herêmê peydexandî ye?',
    answers: [
      'Rojavayê Bakurûrê Sûrîyê',
      'Bakurê Kûrdistanê (Tûrkiye)',
      'Başûrê Kurdistanê (Îraq)',
      'Rojhilatê Kurdistanê (Îran)',
    ],
    correctAnswer: 'Rojavayê Bakurûrê Sûrîyê',
    promptTr: 'Demokratik konfederalizm hangi bölgede uygulandı?',
    answersTr: [
      'Rojava (Kuzey Suriye)',
      'Bakurê Kurdistanê (Türkiye)',
      'Başûrê Kurdistanê (Irak)',
      'Rojhilatê Kurdistanê (İran)',
    ],
    correctAnswerTr: 'Rojava (Kuzey Suriye)',
    explanation:
        'DMC (Xebûna Demokratîk a Rojava-Bakurûrê Sûrîyê) li Rojava hat ava kirin, paşê bû Konfederalîzma Demokratîk a Sûrîyê Bakûr.',
    difficulty: 2,
    metadata: _bozukKurmanciBekliyor,
    explanationKu:
        'Rêveberiya xweser a Rojava piştre wek konfederalîzmeke herêmî ya '
        'bakurê Sûriyê hat berfirehkirin.',
    explanationTr:
        'Rojava’daki özerk yönetim, sonradan Kuzey Suriye’nin bölgesel bir '
        'konfederalizmi olarak genişletildi.',
  ),
  QuizQuestion(
    id: 'curated_siyaset_0007',
    category: 'Siyaset',
    prompt: 'Sedema sereke ya Şoreşa Şêx Said (1925) çi bû?',
    answers: [
      'Berxwedan li dijî rakirina xîlafetê û siyasetên yekbûyî yên dewleta nû',
      'Nakokiyek li ser erdê çandiniyê',
      'Guherîna pereyê neteweyî',
      'Peymana bazirganiya rêwîtiyê',
    ],
    correctAnswer:
        'Berxwedan li dijî rakirina xîlafetê û siyasetên yekbûyî yên dewleta nû',
    promptTr: 'Şêx Said Hareketi\'nin (1925) temel nedeni neydi?',
    answersTr: [
      'Hilafetin kaldırılmasına ve yeni devletin tekleştirici siyasetine karşı direniş',
      'Tarım arazisi üzerine bir anlaşmazlık',
      'Ulusal paranın değişmesi',
      'Bir ticaret ve ulaşım anlaşması',
    ],
    correctAnswerTr:
        'Hilafetin kaldırılmasına ve yeni devletin tekleştirici siyasetine karşı direniş',
    explanation:
        'Şoreşa Şêx Said (Sibat 1925) yek ji berxwedanên yekem ên girîng ên kurdan li Tirkiyeyê bû, li dijî rakirina xîlafetê û siyasetên yekbûyî yên dewleta nû ya komarê.',
    difficulty: 3,
    metadata: _academikSource,
    explanationKu:
        'Serhildana Şêx Seîd (1925) yek ji berxwedanên yekem ên girîng ên '
        'kurdan li Tirkiyeyê bû.',
    explanationTr:
        'Şeyh Said ayaklanması (1925), Kürtlerin Türkiye’deki ilk büyük '
        'direnişlerinden biriydi.',
  ),
  QuizQuestion(
    id: 'curated_siyaset_0008',
    category: 'Siyaset',
    prompt: 'Peymana Lozanê (1923) di derheqê kurdan de çi encam da?',
    answers: [
      'Betalkirina soza xweseriya Peymana Sêvrê',
      'Pejirandina mafên zimanî yên kurdî',
      'Damezirandina herêmeke xweser a kurdan',
      'Vekirina sînorekî nû li Rojhilata Navîn',
    ],
    correctAnswer: 'Betalkirina soza xweseriya Peymana Sêvrê',
    promptTr: 'Lozan Antlaşması (1923) Kürtler açısından neyle sonuçlandı?',
    answersTr: [
      'Sevr\'in özerklik sözünün geçersiz kılınması',
      'Kürtçe dil haklarının tanınması',
      'Özerk bir Kürt bölgesinin kurulması',
      'Ortadoğu\'da yeni bir sınırın açılması',
    ],
    correctAnswerTr: 'Sevr\'in özerklik sözünün geçersiz kılınması',
    explanation:
        'Peymana Lozanê (1923) soza xweseriya Peymana Sêvrê betal kir û axa kurdan di navbera çend dewletan de hate parvekirin.',
    difficulty: 3,
    metadata: _academikSource,
    explanationKu:
        'Peymana Lozanê (1923) soza Sevrê betal kir û axa kurdan di navbera '
        'çend dewletan de hat parvekirin.',
    explanationTr:
        'Lozan Antlaşması (1923) Sevr’in sözünü geçersiz kıldı ve Kürtlerin '
        'toprağı birkaç devlet arasında bölündü.',
  ),
  QuizQuestion(
    id: 'curated_siyaset_0009',
    category: 'Siyaset',
    prompt: 'Kî yekemîn rêberê tevgera Barzanî bû?',
    answers: [
      'Mistefa Barzanî (1903 — 1979)',
      'Mesûd Barzanî',
      'Êlihêçî Kaplan',
      'Celal Talabanî',
    ],
    correctAnswer: 'Mistefa Barzanî (1903 — 1979)',
    promptTr: 'Barzanî hareketinin ilk önderi kimdi?',
    answersTr: [
      'Mistefa Barzanî (1903 — 1979)',
      'Mesûd Barzanî',
      'Êlihêçî Kaplan',
      'Celal Talabanî',
    ],
    correctAnswerTr: 'Mistefa Barzanî (1903 — 1979)',
    explanation:
        'Mistefa Barzanî (1903-1979) yekemîn rêberê tevgera neteweyî ya başûr bû û di 1979an de koça dawî kir.',
    difficulty: 2,
    metadata: _academikSource,
    explanationKu:
        'Mistefa Barzanî (1903–1979) rêberê tevgera neteweyî ya başûr bû û '
        'di 1979ê de koça dawî kir.',
    explanationTr:
        'Mustafa Barzani (1903–1979) güneydeki ulusal hareketin önderiydi '
        've 1979’da hayatını kaybetti.',
  ),
  QuizQuestion(
    id: 'curated_siyaset_0010',
    category: 'Siyaset',
    prompt: 'Hikûmeta Herêma Kurdistanê (HKK) di çi salî de hat ava kirin?',
    answers: ['1992', '2003', '2005', '2017'],
    correctAnswer: '1992',
    promptTr: 'Kurdistan Bölgesel Hükümeti (KBH) hangi yıl kuruldu?',
    answersTr: ['1992', '2003', '2005', '2017'],
    correctAnswerTr: '1992',
    explanation:
        'Di 1992î de piştî rizgarbûnê, HKK (Hikumeta Herêma Kurdistanê) ava kirin; ew yekem hikûmeta kurdî ya nûdem bû.',
    difficulty: 2,
    metadata: _academikSource,
    explanationKu:
        'Piştî 1991ê Hikûmeta Herêma Kurdistanê hat avakirin; ew yekem '
        'hikûmeta kurdî ya nûdem bû.',
    explanationTr:
        '1991’den sonra Kürdistan Bölgesel Hükümeti kuruldu; bu, modern '
        'dönemin ilk Kürt hükümetiydi.',
  ),
  // ── Muzîk ────────────────────────────────────────────────────────────────
  QuizQuestion(
    id: 'curated_muzik_0001',
    category: 'Muzîk',
    prompt: 'Dengbêj di çanda kurdî de çi kes e?',
    answers: [
      'Stranbêj-çîrokbêjê ku bê enstruman distirê',
      'Lîstikvanê tembûrê yê profesyonel',
      'Rêxistînerê govendan',
      'Nivîskarê stranên nûjen',
    ],
    correctAnswer: 'Stranbêj-çîrokbêjê ku bê enstruman distirê',
    promptTr: 'Kürt kültüründe dengbêj kimdir?',
    answersTr: [
      'Çalgısız söyleyen anlatıcı-şarkıcı',
      'Profesyonel tembûr icracısı',
      'Halay düzenleyicisi',
      'Modern şarkı yazarı',
    ],
    correctAnswerTr: 'Çalgısız söyleyen anlatıcı-şarkıcı',
    explanation:
        'Dengbêj stran û çîrokên kevneşopî yên kurdan bi dengê xwe, bê alîkariya enstrumanan, vedibêje.',
    difficulty: 1,
    metadata: _dengbejSource,
    explanationKu:
        'Dengbêj stran û çîrokên kevneşopî bi dengê xwe, bêyî amûrê '
        'vedibêje.',
    explanationTr:
        'Dengbêj, geleneksel şarkı ve hikâyeleri çalgı olmadan, yalnız '
        'sesiyle anlatır.',
  ),
  QuizQuestion(
    id: 'curated_muzik_0002',
    category: 'Muzîk',
    prompt: 'Tembûr çi cure amûrek muzîkê ye?',
    answers: [
      'Amûrek têlî',
      'Amûrek bayî',
      'Amûrek çermî ya lêdanê',
      'Amûrek zengilan',
    ],
    correctAnswer: 'Amûrek têlî',
    promptTr: 'Tembûr ne tür bir çalgıdır?',
    answersTr: [
      'Telli çalgı',
      'Üflemeli çalgı',
      'Derili vurmalı çalgı',
      'Zilli çalgı',
    ],
    correctAnswerTr: 'Telli çalgı',
    explanation:
        'Tembûr amûrekî muzîkê yê kevneşopî yê têlî ye, li herêma Kurdistanê û Rojhilata Navîn belav e.',
    difficulty: 2,
    metadata: _dengbejSource,
    explanationKu:
        'Tembûr amûrek muzîkê ya kevneşopî ya têlî ye; li Kurdistanê û '
        'Rojhilata Navîn belav e.',
    explanationTr:
        'Tembûr geleneksel telli bir çalgıdır; Kürdistan’da ve Ortadoğu’da '
        'yaygındır.',
  ),
  QuizQuestion(
    id: 'curated_muzik_0003',
    category: 'Muzîk',
    prompt: 'Govend di şahî û dawetên kurdan de çi ye?',
    answers: [
      'Reqsa kollektîf a bi dest-gihîştin',
      'Awazek bê deng',
      'Rêxistineke fermî ya dewletê',
      'Amûrekî muzîkê yê têlî',
    ],
    correctAnswer: 'Reqsa kollektîf a bi dest-gihîştin',
    promptTr: 'Govend, Kürt şenlik ve düğünlerinde nedir?',
    answersTr: [
      'El ele tutuşularak oynanan toplu oyun',
      'Sessiz bir ezgi',
      'Resmî bir devlet kurumu',
      'Telli bir çalgı',
    ],
    correctAnswerTr: 'El ele tutuşularak oynanan toplu oyun',
    explanation:
        'Govend reqseke kollektîf e ku lîstikvan destên hev digirin û bi rêza li pey muzîkê dileyizin; li şahî û dawetan pir belav e.',
    difficulty: 1,
    metadata: _dengbejSource,
    explanationKu:
        'Govend reqsek komî ye: lîstikvan destên hev digirin û bi rêz li '
        'pey muzîkê dilîzin.',
    explanationTr:
        'Govend toplu bir danstır: oyuncular el ele tutuşur ve sıra hâlinde '
        'müziğe eşlik eder.',
  ),
  QuizQuestion(
    id: 'curated_muzik_0004',
    category: 'Muzîk',
    prompt: 'Def (erbane) çi cure amûrek muzîkê ye?',
    answers: [
      'Amûrekî çermî yê lêdanê (defê destan)',
      'Amûrekî têlî',
      'Amûrekî bayî yê zirnayê mîna',
      'Amûrekî elektronîkî',
    ],
    correctAnswer: 'Amûrekî çermî yê lêdanê (defê destan)',
    promptTr: 'Def (erbane) ne tür bir çalgıdır?',
    answersTr: [
      'Elde çalınan derili vurmalı çalgı',
      'Telli çalgı',
      'Zurna gibi üflemeli çalgı',
      'Elektronik çalgı',
    ],
    correctAnswerTr: 'Elde çalınan derili vurmalı çalgı',
    explanation:
        'Def/erbane amûrekî lêdanê yê çermî ye ku bi dest tê lêdan; di govend, sema û şahiyên kurdî de bi berfirehî tê bikaranîn.',
    difficulty: 1,
    metadata: _dengbejSource,
    explanationKu:
        'Def/erbane amûrek lêdanê ya çermî ye ku bi dest tê lêxistin; di '
        'govend û şahiyan de belav e.',
    explanationTr:
        'Def/erbane elle çalınan derili bir vurmalı çalgıdır; halay ve '
        'şenliklerde yaygındır.',
  ),
  QuizQuestion(
    id: 'curated_muzik_0005',
    category: 'Muzîk',
    prompt: 'Stranên Şivan Perwer bi giranî li ser çi mijaran in?',
    answers: [
      'Berxwedan, xerîbî, azadî û bîranîna welêt',
      'Tenê muzîka dansê ya nûjen',
      'Reklama bazirganî',
      'Rêbernameyên rêwîtiyê',
    ],
    correctAnswer: 'Berxwedan, xerîbî, azadî û bîranîna welêt',
    promptTr: 'Şivan Perwer\'in şarkıları ağırlıklı olarak hangi konulardadır?',
    answersTr: [
      'Direniş, gurbet, özgürlük ve memleket özlemi',
      'Yalnızca modern dans müziği',
      'Ticari reklam',
      'Yolculuk rehberleri',
    ],
    correctAnswerTr: 'Direniş, gurbet, özgürlük ve memleket özlemi',
    explanation:
        'Şivan Perwer stranbêjekî navdar ê kurd e; stranên wî bi giranî li ser berxwedan, sirgûnî, azadî û bîranîna welêt in.',
    difficulty: 2,
    metadata: _dengbejSource,
    explanationKu:
        'Şivan Perwer stranbêjekî navdar ê kurd e; stranên wî li ser '
        'berxwedan, sirgûnî û bîranîna welêt in.',
    explanationTr:
        'Şivan Perwer tanınmış bir Kürt şarkıcıdır; şarkıları direniş, '
        'sürgün ve memleket hasreti üzerinedir.',
  ),
];
