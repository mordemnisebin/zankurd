import { useState, useEffect } from 'react'
import { BookOpen, Gamepad2, Globe, Sparkles, Trophy, Users, Zap, ArrowRight } from 'lucide-react'
import './App.css'
import { ThemeToggle } from './ThemeToggle'

function App() {
  const [isKu, setIsKu] = useState(true)

  // SEO meta güncelleme
  useEffect(() => {
    document.title = 'ZanKurd — Pêşbirka Kurmancî | Kürtçe Bilgi Yarışması'
    const metaDesc = document.querySelector('meta[name="description"]')
    if (metaDesc) {
      metaDesc.setAttribute('content',
        'ZanKurd — Kurmancî ziman, çand, dîrok û edebiyatê hîn bibe û pêşbirkê bike. '
        + 'Kürtçe dil, kültür, tarih ve edebiyat öğren, yarış.')
    }
  }, [])

  const t = (ku: string, tr: string) => isKu ? ku : tr

  const features = [
    {
      icon: <Gamepad2 size={28} />,
      titleKu: 'Pêşbirka Zû',
      titleTr: 'Hızlı Yarış',
      descKu: '10 pirsan tavilê bibersivîne û pûanan berhev bike.',
      descTr: 'Hemen 10 soruyu cevapla ve puanları topla.',
      color: '#F47A32',
    },
    {
      icon: <Users size={28} />,
      titleKu: 'Odeyên Zindî',
      titleTr: 'Canlı Odalar',
      descKu: 'Bi hevalên xwe re odeyê ava bike an jî bi kodê tevlî bibe.',
      descTr: 'Arkadaşlarınla oda kur veya kodla katıl.',
      color: '#1E5F47',
    },
    {
      icon: <Trophy size={28} />,
      titleKu: 'Pêşbirkên Rojane',
      titleTr: 'Günlük Turnuvalar',
      descKu: 'Her roj pêşbirka nû, tema nû û xelatên taybet.',
      descTr: 'Her gün yeni yarışma, yeni tema ve özel ödüller.',
      color: '#E9C46A',
    },
    {
      icon: <BookOpen size={28} />,
      titleKu: 'Fêr Bibe',
      titleTr: 'Öğren',
      descKu: 'Kurmancî gav bi gav, dersên kurt û mînakên rastîn.',
      descTr: 'Kurmancîyi adım adım, kısa dersler ve gerçek örneklerle.',
      color: '#2B5C8F',
    },
    {
      icon: <Sparkles size={28} />,
      titleKu: 'Joker û Alîkarî',
      titleTr: 'Joker ve Yardımcılar',
      descKu: '50/50, temaşevan, bersiva ducar û pirsa nû.',
      descTr: '50/50, seyirci, çift cevap ve soru değiştirme.',
      color: '#E72F8C',
    },
    {
      icon: <Globe size={28} />,
      titleKu: '8 Kategorî',
      titleTr: '8 Kategori',
      descKu: 'Ziman, Çand, Dîrok, Edebiyat, Cografya û hêj bêtir.',
      descTr: 'Dil, Kültür, Tarih, Edebiyat, Coğrafya ve daha fazlası.',
      color: '#8A62D3',
    },
  ]

  return (
    <div className="landing">
      {/* Nav */}
      <nav className="landing-nav">
        <div className="brand-mark">
          <div className="brand-symbol">ZK</div>
          <div>
            <strong>ZanKurd</strong>
            <span>{t('Pêşbirka Kurmancî', 'Kurmancî Yarışması')}</span>
          </div>
        </div>
        <div className="nav-actions">
          <div className="lang-switch">
            <button
              className={isKu ? 'active' : ''}
              onClick={() => setIsKu(true)}
              aria-label="Kurmancî"
            >
              KU
            </button>
            <button
              className={!isKu ? 'active' : ''}
              onClick={() => setIsKu(false)}
              aria-label="Türkçe"
            >
              TR
            </button>
          </div>
          <ThemeToggle />
        </div>
      </nav>

      {/* Hero */}
      <section className="landing-hero">
        <div className="hero-glow hero-glow-1" />
        <div className="hero-glow hero-glow-2" />
        <div className="hero-content">
          <div className="hero-badge">
            <Zap size={16} />
            <span>{t('Zindî ye!', 'Canlı!')}</span>
          </div>
          <h1>
            {t(
              'Kurmancî hîn bibe û pêşbirkê bike',
              'Kurmancî öğren ve yarışmaya katıl'
            )}
          </h1>
          <p>
            {t(
              'Ziman, çand, dîrok û edebiyata Kurdî di serî de 8 kategoriyên cuda, '
              + 'pêşbirkên zindî, odeyên hevalan, joker û xelatên rojane li benda te ne.',
              'Dil, kültür, tarih ve edebiyat başta olmak üzere 8 farklı kategori, '
              + 'canlı yarışmalar, arkadaş odaları, jokerler ve günlük ödüller seni bekliyor.'
            )}
          </p>
          <div className="hero-cta">
            <a href="https://zankurd.com" className="cta-primary">
              <span>{t('Dest Pê Bike', 'Hemen Başla')}</span>
              <ArrowRight size={20} />
            </a>
            <a href="#features" className="cta-secondary">
              {t('Bêtir Fêr Bibe', 'Daha Fazla Öğren')}
            </a>
          </div>
        </div>
        <div className="hero-visual">
          <div className="hero-mockup">
            <div className="mockup-screen">
              <div className="mockup-question">
                <span className="mockup-category">Ziman</span>
                <p>{t(
                  'Di Kurmancî de peyva "zanîn" bi Tirkî çi ye?',
                  'Kurmancî\'de "zanîn" kelimesi Türkçe\'de nedir?'
                )}</p>
                <div className="mockup-answers">
                  <div className="mockup-answer correct">{t('Bilmek', 'Bilmek')}</div>
                  <div className="mockup-answer">{t('Gitmek', 'Gitmek')}</div>
                  <div className="mockup-answer">{t('Okumak', 'Okumak')}</div>
                  <div className="mockup-answer">{t('Yazmak', 'Yazmak')}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="landing-features">
        <div className="section-header">
          <h2>{t('Hemû Taybetmendî', 'Tüm Özellikler')}</h2>
          <p>{t(
            'ZanKurd bi dehan taybetmendiyan ji bo fêrbûn û pêşbirkê hatîye amadekirin.',
            'ZanKurd, öğrenme ve yarışma için onlarca özellikle hazırlandı.'
          )}</p>
        </div>
        <div className="features-grid">
          {features.map((f, i) => (
            <div className="feature-card" key={i} style={{ '--accent': f.color } as React.CSSProperties}>
              <div className="feature-icon" style={{ color: f.color }}>
                {f.icon}
              </div>
              <h3>{t(f.titleKu, f.titleTr)}</h3>
              <p>{t(f.descKu, f.descTr)}</p>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="landing-cta">
        <div className="cta-card">
          <h2>{t(
            'Tu jî tevlî civata ZanKurd bibe!',
            'Sen de ZanKurd topluluğuna katıl!'
          )}</h2>
          <p>{t(
            'Bi hezaran lîstikvan her roj li vir in. Pêşbirkê bike, fêr bibe, xelatan bi dest bixe.',
            'Binlerce oyuncu her gün burada. Yarış, öğren, ödülleri topla.'
          )}</p>
          <a href="https://zankurd.com" className="cta-primary cta-large">
            <span>{t('Niha Tevlî Bibe', 'Şimdi Katıl')}</span>
            <ArrowRight size={22} />
          </a>
        </div>
      </section>

      {/* Footer */}
      <footer className="landing-footer">
        <div className="footer-content">
          <div className="footer-brand">
            <div className="brand-symbol footer-symbol">ZK</div>
            <div>
              <strong>ZanKurd</strong>
              <span>© 2026 — {t('Hemû maf parastî ne.', 'Tüm hakları saklıdır.')}</span>
            </div>
          </div>
          <div className="footer-links">
            <a href="https://zankurd.com">{t('Sepan', 'Uygulama')}</a>
            <a href="mailto:nisebinbawer47@gmail.com">{t('Têkilî', 'İletişim')}</a>
          </div>
        </div>
      </footer>
    </div>
  )
}

export default App
