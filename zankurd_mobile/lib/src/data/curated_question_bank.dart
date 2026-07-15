import '../models/question_metadata.dart';
import '../models/quiz_question.dart';

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
];
