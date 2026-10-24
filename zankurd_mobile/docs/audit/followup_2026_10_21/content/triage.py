"""Rebuild a sidecar review; never writes production sources or quality baseline."""
import collections, csv, hashlib, json, pathlib, re
ROOT = pathlib.Path(__file__).resolve().parents[4]
OUT = pathlib.Path(__file__).resolve().parent
snapshot = json.loads((OUT/'gate_snapshot.json').read_text())
cache = {}
def rows(path):
    if path not in cache:
        data = json.loads((ROOT/path).read_text())
        cache[path] = data if isinstance(data,list) else data['questions']
    return cache[path]
def locate(path, id):
    found = [q for q in rows(path) if q.get('id') == id]
    assert len(found) == 1, (path,id)
    return found[0]
LESSONS = ['alphabet_1','everyday_1','greetings_2','everyday_2','intro_1','family_1','everyday_3']
REDUNDANT = {
'ds_muzik_0144':'Aynı besteci ve aynı Bavê Senfoniyê lakabı soruluyor; yanıt iki kayıtta Joseph Haydn. leqeba/navê anlatım farkı yeni öğrenme hedefi eklemiyor.',
'ds_dirok_0091':'İki kök Enlil tapınağının merkezi olan aynı kenti soruyor. Nîppur/Nippur yalnız yazım varyantı; Mezopotamya/Sümer bağlamı aynı olguya çıkıyor.',
'edit_dirok_0001':'İki kök Hawar dergisinin yayına başlangıç yılını soruyor; her ikisinin yanıtı 1932. Yazım/fiil farkı yeni hedef eklemiyor.',
'hat_0109':'Aynı Xoybûn kuruluş yılı, aynı 1927 yanıtı; hatiye/hate farkı ayrı olgu ölçmüyor.',
'hat_0112':'Aynı Şêx Seîd isyanı başlangıç yılı, aynı 1925 yanıtı; kiriye/kir farkı ayrı olgu ölçmüyor.',
'hat_0118':'Aynı HDP kuruluş yılı, aynı 2012 yanıtı; hatiye/hate farkı ayrı olgu ölçmüyor.',
'hat_0043':'Aynı Yılmaz Güney doğum yılı, aynı 1937 yanıtı; bûye/bû farkı ayrı olgu ölçmüyor.',
'hat_0062':'Amed kentinden geçen aynı nehir soruluyor; Dîcle ve Çemê Dîcleyê aynı yanıt. nav sözcüğü hedefi değiştirmiyor.',
'hat_0071':'Diyarbekir/Amed aynı kentin adları; kök ve Dîcle yanıtı aynı nehir olgusunu tekrar ediyor.',
'offline_2668':'Aynı Selahedînê Eyûbî doğum yeri soruluyor; Tikrit/Tikrît yazımı dışında aynı yanıt. Fiil farkı yeni hedef eklemiyor.',
}
UNCERTAIN = {
'ds_teknoloji_0242':'GPS yanıtı aynı; otomobil ile uçak/gemi kullanım bağlamları farklı. Bağlamsal çeşitlilik mi gereksiz tekrar mı olduğu müfredat kararı gerektirir.',
'ds_cand_0041':'Def yanıtı ortak ancak tembûr eşliği koşulu yalnız bir kökte var. Koşulun kültürel doğruluğu ve yeni hedef oluşturması editör/kaynak incelemesi gerektirir.',
'ds_cand_0240':'agir/agirê pîroz yakın yanıtlar; genel Newroz etkinliği ile nitelendirilmiş ateş arasındaki ayrım kültür editörü gerektirir.',
'ds_cografya_0133':'Deşt yanıtı ortak; nehrin içinden geçmesi ile sulaması koşulları farklı. Coğrafi tanımın kapsamı ve tekrar gerekliliği editör gerektirir.',
'ds_cografya_0030':'Rapordaki eş Amed, bu kök Mûsil; bu çift yer farkıyla ayrılır. Ancak aynı bankadaki ds_cografya_0017 yine Mûsil/Dîcle sorar. Tek rapor eşi bütün tekrar grafını kapsamaz; üçüncü kayıt incelenmeli.',
'ds_cand_0028':'Tembûr/Def cevapları ve geleneksel/genel düğün koşulları farklı; aynı bağlamda tek yanıt varsayımı için kültür kaynağı ve şıklar editörce incelenmeli.',
'ds_cand_0159':'Yemek hazırlama ile çay/ekmek sunma soruları ayrı eylemler, fakat genelleştirilmiş kültür bağlamında tek doğru cevabı kaynak olmadan onaylayamayız.',
}
review = []
for issue in snapshot['issues']:
    m = re.search(r'similar to (.*):(\d+) \(([^)]+)\); jaccard=([0-9.]+)',issue['message'])
    assert m, issue
    other_path, other_row, other_id, similarity = m.groups()
    q = locate(issue['sourcePath'],issue['id']); other = locate(other_path,other_id)
    lesson = q.get('metadata',{}).get('learningLessonId')
    other_lesson = other.get('metadata',{}).get('learningLessonId')
    decision = 'redundant_repeat' if issue['id'] in REDUNDANT else 'needs_editorial_review' if issue['id'] in UNCERTAIN else 'intentional_variation'
    if decision == 'redundant_repeat': reason = REDUNDANT[issue['id']]
    elif decision == 'needs_editorial_review': reason = UNCERTAIN[issue['id']]
    elif issue['id'] == 'dersler3_2026_10_08_0088':
        reason = 'Uçma sorusunun kökü hemen hemen aynı, fakat seçenek evreni ve ders hedefi farklı: transport_1 ulaşım aracı balafir; animals_2 hayvan Eylo. Aynı sözdizimi iki sözlük alanının ölçümünü birleştirmek için yeterli değildir.'
    elif q.get('type') == 'fillInBlank':
        reason = f"Ortak boşluk doldurma kalıbı; hedef cümle/çeviri farklı: {q.get('promptTr',q['prompt'])} ↔ {other.get('promptTr',other['prompt'])}. Beklenen yanıt {q.get('correctAnswer')!r} ↔ {other.get('correctAnswer')!r}; farklı sözcük/çekim veya ayrı bağlam ölçülüyor. Kalıp benzerliği içerik kusurunu kanıtlamaz."
    else:
        reason = f"Kökün ayırt edici öğesi/istenen ilişki farklı: «{q['prompt']}» ↔ «{other['prompt']}». Yanıtlar {q.get('correctAnswer')!r} ↔ {other.get('correctAnswer')!r}. Ortak konu/sözdizimi tek başına tekrar değildir; bu karar olgu doğrulaması sayılmaz."
    review.append({
        **issue, 'issueFingerprint':issue['fingerprint'], 'reviewDecision':decision,
        'reviewScope':'semantic_duplicate_triage_only', 'reviewed':True,
        'reviewer':'Codex semantic review; human language editor not claimed',
        'reviewSeverity':'editorial_low' if decision=='redundant_repeat' else 'editorial_pending' if decision=='needs_editorial_review' else 'no_duplicate_defect_evidenced',
        'learningLessonId':lesson, 'partnerLearningLessonId':other_lesson,
        'beginnerSourcePriority': any(x in issue['sourcePath'] for x in ['baslangic_','dersler2_','dersler3_']),
        'firstSevenLocalLessonRelation':lesson in LESSONS or other_lesson in LESSONS,
        'firstWeekExposure':'unknown_user_schedule; first7_local_everyday_proxy' if lesson in LESSONS or other_lesson in LESSONS else 'not_proven',
        'partner': {'sourcePath':other_path,'sourceRow':int(other_row),'id':other_id,'prompt':other['prompt'], 'correctAnswer':other.get('correctAnswer'),'answers':other.get('answers'), 'type':other.get('type'), 'learningLessonId':other_lesson},
        'jaccard':float(similarity.rstrip('.')), 'rationale':reason,
        'rawSourceReference':q.get('metadata',{}).get('sourceReference'),
        'factualVerificationStatus':'not_independently_verified',
        'kurmanciEditorialStatus':'not_human_certified',
        'safeForAutomaticFix':False,
        'recommendedAction':'Keep production unchanged; plan question-generation de-duplication after preserving topic/difficulty/type coverage.' if decision=='redundant_repeat' else 'Keep production unchanged; editor adjudication required.' if decision=='needs_editorial_review' else 'Keep variant; retain warning fingerprint until a separately reviewed policy decision.',
    })
assert len(review)==183 and len({x['fingerprint'] for x in review})==183
baseline = json.loads((ROOT/'tool/question_quality/baseline.json').read_text())
assert {x['fingerprint'] for x in review}==set(baseline['issueFingerprints'])
(OUT/'triage_183.json').write_text(json.dumps({'schemaVersion':1,'scope':'local_disk_gate_snapshot_not_supabase','qualityBaselineMutated':False,'allIssueFingerprintsMatched':True,'firstWeekDefinition':'Actual first-week exposure unknown. First seven local everyday lessons are a documented prioritization proxy, not a product promise.','records':review},ensure_ascii=False,indent=2)+'\n')
fields=['issueFingerprint','id','sourcePath','severity','checkId','category','learningLessonId','beginnerSourcePriority','firstSevenLocalLessonRelation','reviewDecision','reviewSeverity','rationale']
with (OUT/'triage_183.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');w.writeheader();w.writerows(review)
candidates=[]
for r in review:
    if r['reviewDecision']!='redundant_repeat':continue
    candidates.append({'id':r['id'],'field':'future_generation.duplicate_group','old':{'uncontrolledPair':[r['id'],r['partner']['id']]},'new':{'duplicateGroupAnchor':r['partner']['id'],'sameObjectiveVariant':r['id'],'productionQuestionUnchanged':True},'rationale':r['rationale'],'sourceEvidence':[f"{r['sourcePath']}:{r['sourceRow']}",f"{r['partner']['sourcePath']}:{r['partner']['sourceRow']}"],'sourceOfTruth':'Compared two checked-in question records; no external fact validation claimed.','implementationProposal':'Record this explicit pair in authoring/generation review and reject a future third same-objective variant. Preserve both current IDs until topic/difficulty/type balance and stored-reference compatibility are reviewed. Do not apply global runtime dedupe.','status':'proposal_only; no content mutation','requiresEditorialApprovalForRetirement':True,'safeForAutomaticFix':False})
assert len(candidates)<=10
(OUT/'correction_candidates.json').write_text(json.dumps({'schemaVersion':1,'applied':False,'certainRepeatedObjectives':len(candidates),'linguisticOrFactualCorrectionCandidates':0,'candidates':candidates},ensure_ascii=False,indent=2)+'\n')
summary={'reviewed':len(review),'qualityGateIssuesUnchanged':183,'byDecision':dict(collections.Counter(x['reviewDecision'] for x in review)),'byCheck':dict(collections.Counter(x['checkId'] for x in review)),'bySeverity':dict(collections.Counter(x['severity'] for x in review)),'bySource':dict(collections.Counter(x['sourcePath'] for x in review)),'byCategory':dict(collections.Counter(x['category'] for x in review)),'byLearningLesson':dict(collections.Counter(x['learningLessonId'] or 'unlinked' for x in review)),'beginnerSourceReviewed':sum(x['beginnerSourcePriority'] for x in review),'beginnerSourceDecisions':dict(collections.Counter(x['reviewDecision'] for x in review if x['beginnerSourcePriority'])),'firstSevenLocalLessonRelation':sum(x['firstSevenLocalLessonRelation'] for x in review),'baselinePasses':snapshot['baselinePasses'],'evidenceSha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted({x['sourcePath'] for x in review}|{x['partner']['sourcePath'] for x in review}|{'tool/question_quality/baseline.json','tool/question_quality/src/checks.dart'})}}
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k not in ['evidenceSha256','bySource']},ensure_ascii=False,indent=2))
