import { BookOpen, Crown, Database, FileSpreadsheet, Gamepad2, LockKeyhole, MessageCircleWarning, Settings, Trophy } from 'lucide-react'

type InsightPanelProps = {
  categories: string[]
  selectedCategory: string
  totalQuestions: number
  accuracy: number
  xp: number
  levelProgress: number
  bestStreak: number
  onSelectCategory: (category: string) => void
}

const backendSteps = [
  { label: 'questions', detail: 'Soru bankası' },
  { label: 'rooms', detail: 'Canlı oda' },
  { label: 'scores', detail: 'Puan geçmişi' },
  { label: 'progress', detail: 'Yanlışlarım' },
]

export function InsightPanel({
  categories,
  selectedCategory,
  totalQuestions,
  accuracy,
  xp,
  levelProgress,
  bestStreak,
  onSelectCategory,
}: InsightPanelProps) {
  return (
    <aside className="side-panel" aria-label="Turnuva ve istatistik">
      <div className="stat-card accent">
        <Trophy size={22} />
        <div>
          <span>Günün turnuvası</span>
          <strong>21:00 - Ziman gecesi</strong>
        </div>
      </div>

      <div className="mini-grid">
        <div className="metric">
          <Crown size={20} />
          <strong>%{accuracy}</strong>
          <span>Doğruluk</span>
        </div>
        <div className="metric">
          <Gamepad2 size={20} />
          <strong>{totalQuestions}</strong>
          <span>Soru</span>
        </div>
      </div>

      <div className="level-card">
        <div className="panel-heading compact">
          <div>
            <span className="section-label">Seviye</span>
            <h2>Zanîn yolu</h2>
          </div>
          <strong>{xp.toLocaleString('tr-TR')} XP</strong>
        </div>
        <div className="progress-track">
          <div className="progress-fill" style={{ width: `${levelProgress}%` }} />
        </div>
        <small>En iyi seri: {bestStreak}</small>
      </div>

      <div className="category-panel">
        <div className="panel-heading compact">
          <div>
            <span className="section-label">Kategoriler</span>
            <h2>Bugün aktif</h2>
          </div>
          <BookOpen size={20} />
        </div>
        <div className="category-list">
          {categories.map((category) => (
            <button
              type="button"
              key={category}
              className={selectedCategory === category ? 'active' : ''}
              onClick={() => onSelectCategory(category)}
            >
              {category}
            </button>
          ))}
        </div>
      </div>

      <div className="category-panel product-ready-card">
        <div className="panel-heading compact">
          <div>
            <span className="section-label">Ürünleşme</span>
            <h2>Admin + backend planı</h2>
          </div>
          <Settings size={20} />
        </div>
        <div className="schema-list compact-schema">
          {backendSteps.map((step) => (
            <span key={step.label}>
              <Database size={14} />
              <strong>{step.label}</strong>
              <small>{step.detail}</small>
            </span>
          ))}
        </div>
        <div className="csv-template">
          <FileSpreadsheet size={18} />
          <code>category,dialect,difficulty,prompt,correct,tags</code>
        </div>
      </div>

      <button type="button" className="report-button">
        <MessageCircleWarning size={18} />
        Soruyu Bildir
      </button>

      <div className="privacy-note">
        <LockKeyhole size={18} />
        Puan, cevap doğrulama ve oda güvenliği backend tarafında korunacak.
      </div>
    </aside>
  )
}
