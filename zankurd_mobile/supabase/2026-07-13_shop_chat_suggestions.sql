-- Eksik tablolar: shop_items, room_messages, suggested_questions
-- Kod bu üç tabloyu zaten çağırıyordu (Dart tarafı tamam) ama tablolar
-- production'da hiç yoktu — sırasıyla Mağaza, Oda Sohbeti ve Soru Öner
-- özellikleri sessizce 404 veriyordu (Mağaza yalnız statik yedek listeyle
-- çalışıyordu; Oda Sohbeti ve Soru Öner tamamen kırıktı).

-- ============================================================================
-- TABLE: shop_items
-- ============================================================================

CREATE TABLE IF NOT EXISTS shop_items (
  id TEXT PRIMARY KEY,
  title_ku TEXT NOT NULL,
  title_tr TEXT NOT NULL,
  desc_ku TEXT NOT NULL,
  desc_tr TEXT NOT NULL,
  cost INT NOT NULL,
  icon_name TEXT,
  theme_color TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE shop_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "shop_items_read" ON shop_items FOR SELECT USING (true);

-- Statik yedek listedeki (shop_screen.dart _items) 10 ürünle birebir
-- aynı id/başlık/açıklama/fiyat/ikon/renk — dinamik ve yedek liste aynı
-- görünsün diye. id çakışırsa güncellenir (yeniden çalıştırma güvenli).
INSERT INTO shop_items (id, title_ku, title_tr, desc_ku, desc_tr, cost, icon_name, theme_color)
VALUES
  ('joker_bundle', 'Paketa Jokeran', 'Joker Paketi',
   'Hemû jokaran ji bo pêşbirka bê nû dike.',
   'Bir sonraki yarışma için tüm joker haklarını sıfırlar.',
   500, 'auto_awesome_motion_outlined', 'FF3B81'),
  ('extra_lifeline', 'Cana Zêde', 'Ekstra Can',
   'Di dema quizê de canekî din dide te.',
   'Yarışma esnasında elendiğinde kullanabileceğin 1 can verir.',
   100, 'favorite_border_rounded', 'FF3B81'),
  ('spin_wheel_extra', 'Zivirîna Zêde ya Çerxê', 'Ekstra Çark Çevirme',
   'Ji bo çerxa rojane mafekî zivirînê yê nû dide.',
   'Bugün çarkı tekrar çevirebilmek için ekstra bir hak tanımlar.',
   200, 'casino_outlined', '2B5C8F'),
  ('premium_colors', 'Rengên Taybet', 'Premium Renkler',
   'Ji bo profilê rengên nû û taybet vedike.',
   'Profil kartı ve avatarı için özel premium renk paletleri açar.',
   300, 'palette_outlined', 'E9C46A'),
  ('avatar_frame_gold', 'Çarçoveya Zêrîn', 'Altın Çerçeve',
   'Ji bo avatarê te çarçoveyeke zêrîn a taybet.',
   'Avatarın için özel altın çerçeve.',
   750, 'star_rounded', 'E9C46A'),
  ('avatar_frame_neon', 'Çarçoveya Neon', 'Neon Çerçeve',
   'Avatarê te bi rengên neon ên geş dibiriqe.',
   'Avatarın neon renklerle parıldasın.',
   600, 'auto_awesome_rounded', '38BDF8'),
  ('name_color_gold', 'Navê Zêrîn', 'Altın İsim',
   'Navê te di profîl û rêzbendiyê de bi rengê zêrîn xuya dibe.',
   'İsmin profil ve liderlik tablosunda altın renginde görünsün.',
   500, 'text_fields_rounded', 'E9C46A'),
  ('name_color_purple', 'Navê Mor', 'Mor İsim',
   'Navê te bi rengekî mor ê taybet were xuyakirin.',
   'İsmin özel mor renkte görünsün.',
   400, 'text_format_rounded', '6C5CE7'),
  ('joker_pack_3', 'Pakêta Jokeran (3)', 'Joker Paketi (3)',
   'Ji bo pêşbirka bê 3 jokerên zêde: 50/50, temaşevan û bersiva ducar.',
   'Bir sonraki yarışma için 3 ekstra joker: 50/50, seyirci ve çift cevap.',
   350, 'auto_fix_high_rounded', 'FF3B81'),
  ('profile_badge_vip', 'Rozeta VIP', 'VIP Rozeti',
   'Profîla te de rozeteke taybet a VIP xuya dibe.',
   'Profilinde özel VIP rozeti görünsün.',
   1000, 'diamond_rounded', '38BDF8')
ON CONFLICT (id) DO UPDATE SET
  title_ku = EXCLUDED.title_ku,
  title_tr = EXCLUDED.title_tr,
  desc_ku = EXCLUDED.desc_ku,
  desc_tr = EXCLUDED.desc_tr,
  cost = EXCLUDED.cost,
  icon_name = EXCLUDED.icon_name,
  theme_color = EXCLUDED.theme_color;

-- ============================================================================
-- TABLE: room_messages (oda sohbeti — room_screen.dart chat toggle'ı)
-- ============================================================================

CREATE TABLE IF NOT EXISTS room_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_name TEXT,
  sender_avatar_color TEXT,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE room_messages ENABLE ROW LEVEL SECURITY;

-- Oda üyeleri (ve herkes; oda kodu zaten paylaşımla sınırlı) mesajları
-- okuyabilir — leaderboard_entries/contest_entries'teki "anyone can read"
-- deseniyle tutarlı.
CREATE POLICY "room_messages_read" ON room_messages FOR SELECT USING (true);

-- Yalnız kendi adına mesaj gönderebilir.
CREATE POLICY "room_messages_insert_own" ON room_messages FOR INSERT
  WITH CHECK (sender_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_room_messages_room_id ON room_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_room_messages_created_at ON room_messages(created_at);

-- Realtime stream (subscribeRoomMessages .stream() kullanıyor).
ALTER PUBLICATION supabase_realtime ADD TABLE room_messages;

-- ============================================================================
-- TABLE: suggested_questions ("Pirs Pêşniyar Bike" — profil menüsü)
-- ============================================================================

CREATE TABLE IF NOT EXISTS suggested_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  prompt TEXT NOT NULL,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  correct_option TEXT NOT NULL,
  explanation TEXT,
  difficulty INT DEFAULT 3,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE suggested_questions ENABLE ROW LEVEL SECURITY;

-- Yalnız kendi önerdiğini görebilir (moderasyon service_role ile yapılır).
CREATE POLICY "suggested_questions_read_own" ON suggested_questions FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "suggested_questions_insert_own" ON suggested_questions FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_suggested_questions_user_id ON suggested_questions(user_id);
CREATE INDEX IF NOT EXISTS idx_suggested_questions_status ON suggested_questions(status);
