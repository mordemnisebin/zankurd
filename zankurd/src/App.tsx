import { useMemo, useState } from 'react'
import {
  Bell,
  BookOpen,
  Check,
  Coins,
  Copy,
  Crown,
  DoorOpen,
  Flame,
  Gamepad2,
  LockKeyhole,
  MessageCircleWarning,
  Play,
  Plus,
  Radio,
  RotateCcw,
  ShieldQuestion,
  Sparkles,
  Trophy,
  Users,
  Zap,
} from 'lucide-react'
import './App.css'

type Difficulty = 'Kolay' | 'Orta' | 'Zor'

type Question = {
  category: string
  difficulty: Difficulty
  prompt: string
  answers: string[]
  correctAnswer: string
  explanation: string
  tags: string[]
}

const questions: Question[] = [
  {
    category: 'Ziman',
    difficulty: 'Kolay',
    prompt: 'Di Kurmancî de peyva "zanîn" bi Tirkî çi ye?',
    answers: ['Bilmek', 'Gitmek', 'Okumak', 'Yazmak'],
    correctAnswer: 'Bilmek',
    explanation: '"Zanîn" bilgi ve bilmek anlamına gelir.',
    tags: ['kelime', 'kurmanci'],
  },
  {
    category: 'Çand',
    difficulty: 'Orta',
    prompt: 'Newroz bi gelemperî kîjan rojê tê pîroz kirin?',
    answers: ['21 Adar', '1 Gulan', '15 Hezîran', '29 Cotmeh'],
    correctAnswer: '21 Adar',
    explanation: 'Newroz baharın gelişiyle 21 Mart/Adar günü kutlanır.',
    tags: ['newroz', 'kültür'],
  },
  {
    category: 'Edebiyat',
    difficulty: 'Zor',
    prompt: 'Mem û Zîn kimin eseri olarak bilinir?',
    answers: ['Ehmedê Xanî', 'Cegerxwîn', 'Melayê Cizîrî', 'Feqiyê Teyran'],
    correctAnswer: 'Ehmedê Xanî',
    explanation: 'Mem û Zîn, Ehmedê Xanî ile özdeşleşmiş klasik bir eserdir.',
    tags: ['edebiyat', 'klasik'],
  },
]

const players = [
  { name: 'Rojda', score: 1240, streak: 4, status: 'Hazır' },
  { name: 'Baran', score: 1180, streak: 3, status: 'Cevapladı' },
  { name: 'Dilan', score: 960, streak: 2, status: 'Bekliyor' },
  { name: 'Azad', score: 910, streak: 1, status: 'Hazır' },
]

function App() {
  const [activeQuestion, setActiveQuestion] = useState(0)
  const [selectedAnswer, setSelectedAnswer] = useState<string | null>(null)
  const [selectedCategory, setSelectedCategory] = useState('Tümü')
  const [roomCode] = useState('ZK-4821')
  const [copyStatus, setCopyStatus] = useState('Kopyala')

  const categories = useMemo(
    () => ['Tümü', ...Array.from(new Set(questions.map((question) => question.category)))],
    [],
  )

  const filteredQuestions = useMemo(() => {
    if (selectedCategory === 'Tümü') {
      return questions
    }

    return questions.filter((question) => question.category === selectedCategory)
  }, [selectedCategory])

  const question = filteredQuestions[activeQuestion] ?? filteredQuestions[0]
  const isAnswered = selectedAnswer !== null
  const isCorrectSelection = selectedAnswer === question.correctAnswer
  const successRate = Math.round(
    (players.reduce((total, player) => total + player.streak, 0) / (players.length * 5)) * 100,
  )

  const sortedPlayers = useMemo(
    () => [...players].sort((a, b) => b.score - a.score),
    [],
  )

  function nextQuestion() {
    setActiveQuestion((current) => (current + 1) % filteredQuestions.length)
    setSelectedAnswer(null)
  }

  function selectCategory(category: string) {
    setSelectedCategory(category)
    setActiveQuestion(0)
    setSelectedAnswer(null)
  }

  async function copyRoomCode() {
    try {
      await navigator.clipboard.writeText(roomCode)
      setCopyStatus('Kopyalandı')
      window.setTimeout(() => setCopyStatus('Kopyala'), 1400)
    } catch {
      setCopyStatus(roomCode)
    }
  }

  return (
    <main className="app-shell">
      <nav className="topbar" aria-label="Ana gezinme">
        <div className="brand-mark">
          <div className="brand-symbol">ZK</div>
          <div>
            <strong>ZanKurd</strong>
            <span>Pêşbirka Kurmancî</span>
          </div>
        </div>

        <div className="top-actions">
          <button type="button" className="icon-button" aria-label="Bildirimler">
            <Bell size={19} />
          </button>
          <button type="button" className="coin-pill" aria-label="Mevcut coin bakiyesi">
            <Coins size={18} />
            2.450
          </button>
        </div>
      </nav>

      <section className="hero-band">
        <div className="hero-copy">
          <span className="eyebrow">
            <Radio size={16} />
            Canlı oda açık
          </span>
          <h1>Kurmancî bilgi yarışmasını odalarda canlı çöz.</h1>
          <p>
            Arkadaş daveti, rastgele eşleşme, jokerler, günlük turnuvalar ve
            öğrenme alanı tek oyun akışında.
          </p>
        </div>

        <div className="quick-actions" aria-label="Hızlı işlemler">
          <button type="button" className="primary-action">
            <Plus size={20} />
            Oda Kur
          </button>
          <button type="button" className="secondary-action">
            <DoorOpen size={20} />
            Kodla Katıl
          </button>
          <button type="button" className="secondary-action">
            <Zap size={20} />
            Rastgele
          </button>
        </div>
      </section>

      <section className="dashboard-grid">
        <aside className="room-panel" aria-label="Oda bilgileri">
          <div className="panel-heading">
            <div>
              <span className="section-label">Özel oda</span>
              <h2>Hevalên Zanînê</h2>
            </div>
            <button type="button" className="icon-button" aria-label="Oda kodunu kopyala" onClick={copyRoomCode}>
              <Copy size={18} />
            </button>
          </div>

          <div className="room-code">
            <span>Oda kodu</span>
            <strong>{roomCode}</strong>
            <small>{copyStatus}</small>
          </div>

          <div className="player-list">
            {sortedPlayers.map((player, index) => (
              <div className="player-row" key={player.name}>
                <div className="rank">{index + 1}</div>
                <div>
                  <strong>{player.name}</strong>
                  <span>{player.status} · seri {player.streak}</span>
                </div>
                <div className="score">
                  <Flame size={15} />
                  {player.score}
                </div>
              </div>
            ))}
          </div>

          <button type="button" className="start-button">
            <Play size={19} />
            Yarışı Başlat
          </button>
        </aside>

        <section className="quiz-stage" aria-label="Aktif soru">
          <div className="quiz-meta">
            <span>{question.category}</span>
            <span>{question.difficulty}</span>
            <strong>{String(activeQuestion + 1).padStart(2, '0')} / {String(filteredQuestions.length).padStart(2, '0')}</strong>
          </div>

          <h2>{question.prompt}</h2>

          <div className="answer-grid">
            {question.answers.map((answer) => {
              const isSelected = selectedAnswer === answer
              const isCorrect = isAnswered && answer === question.correctAnswer
              const isWrong = isSelected && answer !== question.correctAnswer

              return (
                <button
                  type="button"
                  className={[
                    'answer-option',
                    isSelected ? 'selected' : '',
                    isCorrect ? 'correct' : '',
                    isWrong ? 'wrong' : '',
                  ].join(' ')}
                  key={answer}
                  onClick={() => setSelectedAnswer(answer)}
                  aria-pressed={isSelected}
                >
                  <span>{answer}</span>
                  {isCorrect && <Check size={18} />}
                </button>
              )
            })}
          </div>

          {isAnswered && (
            <div className="explanation">
              <ShieldQuestion size={19} />
              <span>
                <strong>{isCorrectSelection ? 'Doğru!' : 'Doğru cevap: ' + question.correctAnswer}</strong>{' '}
                {question.explanation}
              </span>
            </div>
          )}

          <div className="question-tags" aria-label="Soru etiketleri">
            {question.tags.map((tag) => (
              <span key={tag}>#{tag}</span>
            ))}
          </div>

          <div className="joker-row" aria-label="Jokerler">
            <button type="button">
              <Sparkles size={18} />
              50/50
            </button>
            <button type="button">
              <Users size={18} />
              Seyirci
            </button>
            <button type="button" onClick={nextQuestion}>
              <RotateCcw size={18} />
              Değiştir
            </button>
          </div>
        </section>

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
              <strong>{successRate}%</strong>
              <span>Takım ivmesi</span>
            </div>
            <div className="metric">
              <Gamepad2 size={20} />
              <strong>{questions.length}</strong>
              <span>Soru</span>
            </div>
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
                  onClick={() => selectCategory(category)}
                >
                  {category}
                </button>
              ))}
            </div>
          </div>

          <button type="button" className="report-button">
            <MessageCircleWarning size={18} />
            Soruyu Bildir
          </button>

          <div className="privacy-note">
            <LockKeyhole size={18} />
            Puan ve cevap doğrulama backend tarafında yapılacak.
          </div>
        </aside>
      </section>
    </main>
  )
}

export default App
