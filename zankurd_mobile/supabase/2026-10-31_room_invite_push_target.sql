-- Yerel aday. Önce push_delivery_v2 (outbox.data) kurulmalı.
-- Uygulama öncesinde her iki pg_get_functiondef ile üretilen farkı denetle.
-- Yeni gönderiler gerçek davet kimliğini taşır; eski işlere kimlik tahmin edilmez.
begin;

do $patch$
declare
  producer regprocedure := 'public.invite_friends_to_room(uuid,uuid[])'::regprocedure;
  inbox regprocedure := 'public.list_my_room_invites()'::regprocedure;
  def text;
  edit record;
  pending_clause text := $fragment$where i.invitee_id = v_uid
    and i.status = 'pending'$fragment$;
begin
  if not exists (select 1 from pg_attribute where attrelid = 'public.push_outbox'::regclass
      and attname = 'data' and atttypid = 'jsonb'::regtype and not attisdropped)
     or to_regprocedure('public.list_my_room_invites(uuid)') is not null then
    raise exception 'Davet hedefi: V2 önkoşulu veya RPC imzası beklenmedik';
  end if;

  def := pg_get_functiondef(producer);
  -- Tekil satır aynı oda/alıcıya yeniden kullanılıyor. Yeni bildirim, yeniden
  -- açılmış davet veya değişen davetçi eski dokunuşu yeniden geçerli kılamaz.
  for edit in select * from (values
    -- Ortak FOR SHARE iki üreticiyi aynı anda geçirirdi. Oda kapsamındaki
    -- tek kilit, çok alıcılı istekler ters sırada gelse de tek sıra sağlar.
    (E'where r.id = p_room_id\n  for share;', E'where r.id = p_room_id\n  for no key update;'),
    ('v_push boolean;', E'v_push boolean;\n  v_invite_id uuid;'),
    ('set inviter_id = excluded.inviter_id,',
     $new$set id = case when v_push or room_invites.status <> 'pending'
                           or room_invites.inviter_id <> excluded.inviter_id
                    then excluded.id else room_invites.id end,
          inviter_id = excluded.inviter_id,$new$),
    (E'created_at = now();\n\n    if v_push then',
     E'created_at = now()\n    returning id into v_invite_id;\n\n    if v_push then'),
    ('insert into public.push_outbox (to_user_id, kind, title, body, from_user_id)',
     'insert into public.push_outbox (to_user_id, kind, title, body, from_user_id, data)'),
    (E'        v_uid\n      );\n    end if;',
     $new$        v_uid,
        jsonb_build_object('invite_id', v_invite_id::text, 'room_id', p_room_id::text)
      );
    end if;$new$)
  ) as edits(old_part, new_part)
  loop
    if (length(def) - length(replace(def, edit.old_part, ''))) <> length(edit.old_part) then
      raise exception 'Davet hedefi: canlı üretici farklı; otomatik değişiklik durdu';
    end if;
    def := replace(def, edit.old_part, edit.new_part);
  end loop;
  execute def;

  -- Liste ilk on daveti getirir. Bildirim sorgusu aynı güncel güvenlik
  -- koşullarında kimliği LIMIT'ten önce süzer. Parametresiz RPC korunur.
  def := pg_get_functiondef(inbox);
  if position('public.list_my_room_invites()' in def) = 0
     or position('public.blocked_users' in def) = 0
     or position('auth.uid()' in def) = 0
     or position('interval ''30 minutes''' in def) = 0
     or position('limit 10' in def) = 0
     or (length(def) - length(replace(def, pending_clause, ''))) <> 2 * length(pending_clause) then
    raise exception 'Davet hedefi: canlı gelen kutusu farklı; otomatik değişiklik durdu';
  end if;
  def := replace(def, 'public.list_my_room_invites()', 'public.list_my_room_invites(p_invite_id uuid)');
  def := replace(def, pending_clause, pending_clause || ' and i.id = p_invite_id');
  -- PostgreSQL pg_get_functiondef dönüş tablosunu tek satırda normalleştirir.
  for edit in select * from (values
    ('created_at timestamp with time zone)',
     'created_at timestamp with time zone, entry_fee integer, question_count integer, seconds_per_question integer)'),
    (E'i.created_at\n  from public.room_invites i',
     E'i.created_at, r.entry_fee, r.question_count, r.seconds_per_question\n  from public.room_invites i')
  ) as edits(old_part, new_part)
  loop
    if (length(def) - length(replace(def, edit.old_part, ''))) <> length(edit.old_part) then
      raise exception 'Davet hedefi: canlı oda koşulları farklı; işlem durdu';
    end if;
    def := replace(def, edit.old_part, edit.new_part);
  end loop;
  execute def;
end;
$patch$;

alter function public.list_my_room_invites(uuid) set search_path = public, pg_temp;
revoke all on function public.list_my_room_invites(uuid) from public, anon;
grant execute on function public.list_my_room_invites(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
