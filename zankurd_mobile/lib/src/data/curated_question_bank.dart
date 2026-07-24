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

/// İlk editoryal dalga: Kurmancî öncelikli, kaynaklı ve bağlamlı sorular.
/// Eski otomatik havuzdan ayrı tutulur; yeni içerik kalite filtresinden geçmiştir.
const curatedQuestionBank = <QuizQuestion>[
  QuizQuestion(
    id: 'curated_movement_0001',
    category: 'Siyaset',
    prompt: 'Di gotina «Jin, Jiyan, Azadî» de «jiyan» çi ye?',
    answers: ['Jin', 'Jiyan', 'Azadî', 'Rêxistin'],
    correctAnswer: 'Jiyan',
    explanation:
        '«Jiyan» di Kurmancî de «jiyan/yaşam» e. Di vê gotinê de sê têgehên jin, jiyan û azadî bi hev ve tên girêdan.',
    difficulty: 1,
    metadata: _anfSource,
  ),
  QuizQuestion(
    id: 'curated_movement_0002',
    category: 'Siyaset',
    prompt: 'Kîjan peyv di Kurmancî de «azadî» tê wate kirin?',
    answers: ['Azadî', 'Berdêl', 'Dîrok', 'Rê'],
    correctAnswer: 'Azadî',
    explanation:
        '«Azadî» wateya azadiyê dide; peyv di slogan û gotûbêja mafan de jî gelek tê bikaranîn.',
    difficulty: 1,
    metadata: _anfSource,
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
    explanation:
        'Jineolojî di edebiyata tevgerê de wek nêzîkatiyek ji bo xwendina jiyana jinan, civakê û têkiliyên hêzê tê pênasekirin.',
    difficulty: 3,
    metadata: _anfSource,
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
    explanation:
        '«Meclîs» civîna hevbeş e. Di modelên xwe-rêxistinkirî de meclîs cihê gotûbêj û biryargirtinê ye.',
    difficulty: 2,
    metadata: _anfSource,
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
    explanation:
        '«Xwe-rêxistin» tê wateya ku kes û kom bi hevkarî kar û biryarên xwe rêxistin dikin.',
    difficulty: 2,
    metadata: _kjarSource,
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
    explanation:
        '«Berxwedan» di vê hevokê de wateya rawestan û li hember zordariyê ragirtinê dide.',
    difficulty: 2,
    metadata: _kjarSource,
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
    explanation:
        '«Serhildan» bi rabûn û hereketeke civakî li hember zordariyê re têkildar e. Wateya wê li gorî kontekstê dikare hinekî biguhere.',
    difficulty: 3,
    metadata: _kjarSource,
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
    explanation:
        'Agirê Newrozê di gelek vegotinên Kurdan de bi ronahî, hêvî û vejîna nû re tê girêdan.',
    difficulty: 2,
    type: QuestionType.visual,
    imageUrl: 'asset://assets/question_images/newroz.webp',
    metadata: _kjarSource,
  ),
  QuizQuestion(
    id: 'curated_movement_0009',
    category: 'Çand',
    prompt: '«Newroz» ji aliyê wateya peyvê ve bi kîjan ravekirinê re nêzîk e?',
    answers: ['Rojê nû', 'Şeva dirêj', 'Bara kevn', 'Dengê bilind'],
    correctAnswer: 'Rojê nû',
    explanation:
        'Newroz bi têgeha «rojê nû» re tê şirovekirin û wek destpêka demsala biharê tê pîroz kirin.',
    difficulty: 2,
    metadata: _kongraStarSource,
  ),
  QuizQuestion(
    id: 'curated_movement_0010',
    category: 'Siyaset',
    prompt:
        'Di wêneyê de sembola siyasî ya kategoriyê heye. Kîjan peyv di Kurmancî de «rêxistin» tê wate kirin?',
    answers: ['Rêxistin', 'Av', 'Pirtûk', 'Baran'],
    correctAnswer: 'Rêxistin',
    explanation: '«Rêxistin» wateya rêkxistin û rêxistina kesan an koman dide.',
    difficulty: 1,
    type: QuestionType.visual,
    imageUrl: 'asset://assets/question_images/cat_siyaset.webp',
    metadata: _kongraStarSource,
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
    explanation:
        'Di nivîsarên tevgerê de ev têgeh bi meclîs, komîn, hevkarî û biryargirtina ji jêr ve tê şirovekirin.',
    difficulty: 4,
    metadata: _kongraStarSource,
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
    explanation:
        'Di zimanê civakî de «dengê xwe bilind kirin» pir caran wateya axaftin û parastina maf û daxwazên xwe dide.',
    difficulty: 3,
    metadata: _kongraStarSource,
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
    explanation:
        'Ziman tenê amûra ragihandinê nîne; ew dikare çîrok, bîranîn û awayê dîtina civakê jî hilgire.',
    difficulty: 3,
    metadata: _jineolojiSource,
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
    explanation:
        'Hevserokî têgehek e ku berpirsiyariya rêveberiyê di navbera du kesan de parve dike; di nîqaşên tevgerê de bi wekheviyê re tê girêdan.',
    difficulty: 4,
    metadata: _jineolojiSource,
  ),
  QuizQuestion(
    id: 'curated_movement_0015',
    category: 'Paradigma',
    prompt:
        'Rast e yan şaş e? «Xwe-rêxistin tenê ji bo kesên ku li bajarên mezin dijîn e.»',
    answers: ['Rast e', 'Şaş e'],
    correctAnswer: 'Şaş e',
    explanation:
        'Xwe-rêxistin têgehek e ku dikare di cihên cuda de, di nav kom û civakan de, bi awayên cuda were bikaranîn.',
    difficulty: 2,
    type: QuestionType.trueFalse,
    metadata: _jineolojiSource,
  ),
  QuizQuestion(
    id: 'curated_movement_0016',
    category: 'Siyaset',
    prompt:
        'Rast e yan şaş e? «Berxwedan» her tim tenê bi awayê çekdarî tê pênasekirin.',
    answers: ['Rast e', 'Şaş e'],
    correctAnswer: 'Şaş e',
    explanation:
        'Berxwedan dikare zimanî, çandî, siyasî, civakî û gelek awayên din hebin; ew ne tenê bi awayekê tê pênasekirin.',
    difficulty: 3,
    type: QuestionType.trueFalse,
    metadata: _jineolojiSource,
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
    explanation:
        'Bîranîn û şahidî dikarin ezmûnên kesên ku di nivîsarên fermî de kêm tên dîtin nîşan bidin.',
    difficulty: 3,
    metadata: _anfSource,
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
    explanation:
        '«Rojava» di Kurmancî de bi wateya rojava û bi navê herêmî yê Rojavayê Kurdistanê tê bikaranîn.',
    difficulty: 2,
    metadata: _kongraStarSource,
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
    explanation:
        'Stran dikare bîranîn, hest û peyamên civakî bi awayekî dengdar û hevpar ragihîne.',
    difficulty: 3,
    metadata: _kjarSource,
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
    explanation:
        'Helbest dikare hest, bîranîn û daxwazên civakî bi zimanekî wêjeyî û xeyalî vegerîne.',
    difficulty: 2,
    metadata: _jineolojiSource,
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
    explanation:
        'Jineolojî ji «jin» û «lojî» (zanist) pêk tê; zanistiya jinê û rêxistinkirina civaka azad e.',
    difficulty: 1,
    metadata: _jineolojiSource,
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
    explanation:
        'Konfederalîzmek modela ku rêxistinên xwe-bixwe yên herêmî yên xwebûn-bixwe li ser wekheviyê tên girêdan e.',
    difficulty: 2,
    metadata: _academikSource,
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
    explanation:
        'Hevaltî peyva ku endamentên rêxistinê li ser wekheviyê dihundirîne, ne serdestiyê.',
    difficulty: 2,
    metadata: _jineolojiSource,
  ),
  QuizQuestion(
    id: 'curated_paradigma_0004',
    category: 'Paradigma',
    prompt: 'Abdullah Öcalan di gotarên xwe de kîjan «-îzm»ê pêşniyar kir?',
    answers: [
      'Konfederalîzma demorkatîk',
      'Fakltîzm',
      'Fermendîzm',
      'Medyatîkdemokrasî',
    ],
    correctAnswer: 'Konfederalîzma demorkatîk',
    explanation:
        'Di «Demokratik Konfederalîzm» de civak bi şiklê rêxistinên xwe-bixwe têne rêxistinkirin, ne dewletî.',
    difficulty: 2,
    metadata: _academikSource,
  ),
  QuizQuestion(
    id: 'curated_paradigma_0005',
    category: 'Paradigma',
    prompt: 'Civaka takekesî li şûna netewe-dewletê çi pêşniyar dike?',
    answers: [
      'Birayên xwe rêxistinbranî',
      'Demorkrasîxerbirîna gelemperî',
      'Hespê ûrikirî ya leşkerî',
      'Hiqûqa malbatê ya nepenî',
    ],
    correctAnswer: 'Demorkrasîxerbirîna gelemperî',
    explanation:
        'Paradîgma demorkratîk a civakî rêxistinên demorkatîk û rihevketa gelemperî hene dihundirîne.',
    difficulty: 3,
    metadata: _academikSource,
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
    explanation:
        'Jineolojî li Rojavayê Kurdistanê bû pîvana rastînên mirovan û azadiya ziman, şoreş û rêxistinên jin.',
    difficulty: 2,
    metadata: _kongraStarSource,
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
    explanation:
        'Ekolojiyê demokratîk dixwaze ku mirov bi xweza re lihevhatî bixwîne, tune serdestiyê.',
    difficulty: 2,
    metadata: _academikSource,
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
    explanation:
        'Biryarên civakî bi şiklê konsensus û şûnartî tên standin, ne bi werdêjin.',
    difficulty: 3,
    metadata: _kongraStarSource,
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
    explanation:
        'Jinên di şerê Kobanî de gayeyên azadî û berxwedanê bi xwe-şehîdî li ber xwe dan û bûne ramana jin, jiyan, azadî.',
    difficulty: 2,
    metadata: _kjarSource,
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
    explanation:
        'Sembola rengîn a jinên parastina jinê ye, ku azadiyê û bicihbûna civakê destnîşan dike.',
    difficulty: 2,
    metadata: _kongraStarSource,
  ),
  // ── Siyaset ─────────────────────────────────────────────────────────────
  QuizQuestion(
    id: 'curated_siyaset_0001',
    category: 'Siyaset',
    prompt: 'Komara Mehabad kengî hat îlan kirin?',
    answers: ['1946', '1925', '1961', '1984'],
    correctAnswer: '1946',
    explanation:
        'Komara Mehabad (22ê Çileya 1946 — 15ê Kanûna 1946) li rojhilatê Kurdistanê yekemîn komara kurdî ye.',
    difficulty: 2,
    metadata: _academikSource,
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
    explanation:
        'Qazî Mihemed (1893 — 1947) serokdarê Komara Mehabadê bû, di 31ê Çele.avê de hatî darvekirin.',
    difficulty: 2,
    metadata: _academikSource,
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
    explanation:
        'Peymana Sêvrê (1920) ji Kurdistanê re xweseriyek soz da û rê li ber serxwebûnê vekir, lê Peymana Lozanê (1923) ev soz betal kir.',
    difficulty: 3,
    metadata: _academikSource,
  ),
  QuizQuestion(
    id: 'curated_siyaset_0004',
    category: 'Siyaset',
    prompt:
        'Herêma Kurdistanê (Îraq) di çi salî de xweseriya xwe bi dest xist?',
    answers: ['1970', '1991', '2003', '2005'],
    correctAnswer: '1970',
    explanation:
        'Di 1970î de Şoreşa Îraqê li herêma Kurdistanê dest bi xweseriyê kir; paşê di 1991î de ew herêm bû herêmî îraqî xwe-bixwe.',
    difficulty: 2,
    metadata: _academikSource,
  ),
  QuizQuestion(
    id: 'curated_siyaset_0005',
    category: 'Siyaset',
    prompt: 'Şerê Kobanê yê li dijî DAIŞê çi salî dest pê kir?',
    answers: ['2014', '2003', '2011', '2017'],
    correctAnswer: '2014',
    explanation:
        'Şerê Kobanê (Îlon 2014 — Adar 2015) roleke girîng lîst di têkoşîna li dijî DAIŞê de.',
    difficulty: 2,
    metadata: _kjarSource,
  ),
  QuizQuestion(
    id: 'curated_siyaset_0006',
    category: 'Siyaset',
    prompt: 'Konfederalîzma demorkratîk li kîjan herêmê peydexandî ye?',
    answers: [
      'Rojavayê Bakurûrê Sûrîyê',
      'Bakurê Kûrdistanê (Tûrkiye)',
      'Başûrê Kurdistanê (Îraq)',
      'Rojhilatê Kurdistanê (Îran)',
    ],
    correctAnswer: 'Rojavayê Bakurûrê Sûrîyê',
    explanation:
        'DMC (Xebûna Demorkatîk a Rojava-Bakurûrê Sûrîyê) li Rojava hat ava kirin, paşê bû Konfederalîzma Demorkatîk a Sûrîyê Bakûr.',
    difficulty: 2,
    metadata: _academikSource,
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
    explanation:
        'Şoreşa Şêx Said (Sibat 1925) yek ji berxwedanên yekem ên girîng ên kurdan li Tirkiyeyê bû, li dijî rakirina xîlafetê û siyasetên yekbûyî yên dewleta nû ya komarê.',
    difficulty: 3,
    metadata: _academikSource,
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
    explanation:
        'Peymana Lozanê (1923) soza xweseriya Peymana Sêvrê betal kir û axa kurdan di navbera çend dewletan de hate parvekirin.',
    difficulty: 3,
    metadata: _academikSource,
  ),
  QuizQuestion(
    id: 'curated_siyaset_0009',
    category: 'Siyaset',
    prompt: 'Kî yekemîn rêberê tevgera Barsanî bû?',
    answers: [
      'Mistefa Barzanî (1903 — 1979)',
      'Mesûd Barzanî',
      'Êlihêçî Kaplan',
      'Celal Talabanî',
    ],
    correctAnswer: 'Mistefa Barzanî (1903 — 1979)',
    explanation:
        'Mistefa Barzanî (1903-1979) yekemîn rêberê tevgera Barsanî bû, di 1979î de li Îranê hate vedîtin.',
    difficulty: 2,
    metadata: _academikSource,
  ),
  QuizQuestion(
    id: 'curated_siyaset_0010',
    category: 'Siyaset',
    prompt: 'Hikûmeta Herêma Kurdistanê (HKK) di çi salî de hat ava kirin?',
    answers: ['1992', '2003', '2005', '2017'],
    correctAnswer: '1992',
    explanation:
        'Di 1992î de piştî rizgarbûnê, HKK (Hikumeta Herêma Kurdistanê) ava kirin; ew yekem hikûmeta kurdîdemorkat a nûdem bû.',
    difficulty: 2,
    metadata: _academikSource,
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
    explanation:
        'Dengbêj stran û çîrokên kevneşopî yên kurdan bi dengê xwe, bê alîkariya enstrumanan, vedibêje.',
    difficulty: 1,
    metadata: _dengbejSource,
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
    explanation:
        'Tembûr amûrekî muzîkê yê kevneşopî yê têlî ye, li herêma Kurdistanê û Rojhilata Navîn belav e.',
    difficulty: 2,
    metadata: _dengbejSource,
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
    explanation:
        'Govend reqseke kollektîf e ku lîstikvan destên hev digirin û bi rêza li pey muzîkê dileyizin; li şahî û dawetan pir belav e.',
    difficulty: 1,
    metadata: _dengbejSource,
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
    explanation:
        'Def/erbane amûrekî lêdanê yê çermî ye ku bi dest tê lêdan; di govend, sema û şahiyên kurdî de bi berfirehî tê bikaranîn.',
    difficulty: 1,
    metadata: _dengbejSource,
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
    explanation:
        'Şivan Perwer stranbêjekî navdar ê kurd e; stranên wî bi giranî li ser berxwedan, sirgûnî, azadî û bîranîna welêt in.',
    difficulty: 2,
    metadata: _dengbejSource,
  ),
];
