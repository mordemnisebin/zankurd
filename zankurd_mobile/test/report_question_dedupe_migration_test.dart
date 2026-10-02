import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `2026-10-02_report_question_dedupe.sql` sözleşme bekçisi.
///
/// Canlı veritabanına dokunmaz; göçün NİÇİN yazıldığını koruyan kalıpları
/// sabitler.
///
/// ## Kusur
///
/// `report_question(text)` her çağrıda `questions.report_count` artırıyor ve
/// 5'te soruyu `needsReview`a düşürüyordu; bildirenin kim olduğuna bakmıyordu
/// (`question_reports`ta (reporter_id, question_id) tekilliği de yoktu).
/// Aynı kullanıcı tek başına bir soruyu havuzdan düşürebilirdi.
///
/// Daha kötüsü: canlı gövde `where id = p_question_id` karşılaştırıyordu;
/// `questions.id` UUID, parametre `text`, yani RPC her çağrıda `operator does
/// not exist: uuid = text` ile patlıyordu ve sayaç HİÇ çalışmadı.
///
/// ## Niçin sessiz kaldı
///
/// İstemci RPC hatasını yutuyor (`report_question RPC failed` yalnız hata
/// raporuna gider), bildirim `question_reports`a yine yazıldığı için akış
/// "çalışıyor" görünüyordu. Tekrar bildirme saldırısı da gerçek bir sayaç
/// olmadığından hiç ölçülmedi.
String _sql() =>
    File('supabase/2026-10-02_report_question_dedupe.sql').readAsStringSync();

void main() {
  test('tek işlemde, doğrulamalı, geri alma notlu, applied.md te ⏳', () {
    final sql = _sql();
    expect(sql.trimLeft(), startsWith('--'));
    expect(sql, contains('\nbegin;'));
    expect(sql.trimRight(), endsWith('commit;'));
    expect(sql, contains('raise exception'));
    expect(sql, contains('GERİ ALMA'));
    expect(
      RegExp(
        r'^\| 2026-10-02_report_question_dedupe\.sql \| ⏳ \|',
        multiLine: true,
      ).hasMatch(File('supabase/applied.md').readAsStringSync()),
      isTrue,
    );
  });

  test('kullanıcı başına soru başına tek bildirim: indeks ve yumuşak atlama', () {
    final sql = _sql();
    expect(
      sql,
      contains(
        'create unique index if not exists question_reports_reporter_question_uidx',
      ),
    );
    expect(sql, contains('(reporter_id, question_id)'));
    // Yinelenenler indeksten ÖNCE temizlenir.
    expect(
      sql.indexOf('delete from public.question_reports'),
      lessThan(sql.indexOf('create unique index')),
    );
    // Eski istemci doğrudan insert yapar: ikinci bildirim hata değil atlama.
    expect(sql, contains('before insert on public.question_reports'));
    expect(sql, contains('return null;'));
    expect(sql, contains('new.counted_at := null;'));
    // Tetikleyici SELECT politikası olmayan tabloyu okur: DEFINER şart.
    final trigger = sql.substring(
      sql.indexOf(
        'create or replace function public.question_reports_before_insert()',
      ),
    );
    expect(trigger.substring(0, 300), contains('security definer'));
  });

  test('report_question idempotent ve tip uyumlu; imza/dönüş/yetki aynı', () {
    final sql = _sql();
    final fn = sql.substring(
      sql.indexOf('create or replace function public.report_question'),
    );
    expect(fn, contains('p_question_id text'));
    expect(fn, contains('returns void'));
    expect(fn, contains('security definer'));
    expect(fn, contains("set search_path to 'public'"));
    // Sayma, `counted_at null -> now()` işaretlenebilirse olur.
    expect(fn, contains('counted_at is null'));
    expect(fn, contains('get diagnostics v_marked = row_count'));
    expect(
      fn.indexOf('get diagnostics v_marked'),
      lessThan(fn.indexOf('set report_count')),
      reason: 'işaretleme sayımdan önce olmalı',
    );
    // Kusurun kendisi: `id = <text parametre>` karşılaştırması.
    expect(
      RegExp(r'where id = p_question_id').hasMatch(fn),
      isFalse,
      reason: 'uuid = text karşılaştırması RPC yi her çağrıda patlatır',
    );
    expect(fn, contains('where id = v_qid'));
    // Eşik ve rejected koruması canlı gövdeyle aynı.
    expect(fn, contains('v_count >= 5'));
    expect(fn, contains("is distinct from 'rejected'"));
    expect(fn, contains("review_status = 'needsReview'"));
    expect(
      sql,
      contains(
        'revoke all on function public.report_question(text) from public, anon;',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.report_question(text) to authenticated;',
      ),
    );
  });

  test('blocked_users.blocked_id indeksi', () {
    expect(
      _sql(),
      contains(
        'create index if not exists blocked_users_blocked_id_idx\n'
        '  on public.blocked_users (blocked_id);',
      ),
    );
  });

  test('eski bildirimler bir kez sayılır, sonra işaretlenir', () {
    final sql = _sql();
    expect(sql, contains('add column if not exists counted_at timestamptz'));
    // UUID olmayan yerel kimlikler (`ziman_x_0035`) cast edilmez: CASE korur.
    expect(sql, contains('when lower(question_id) ~'));
    expect(
      sql.indexOf('update public.questions q'),
      lessThan(sql.indexOf('set counted_at = created_at')),
    );
  });
}
