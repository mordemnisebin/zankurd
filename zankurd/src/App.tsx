import { useMemo, useState } from 'react'
import './App.css'
import { BottomNavigation } from './components/BottomNavigation'
import { HeroSection } from './components/HeroSection'
import { InsightPanel } from './components/InsightPanel'
import { QuizCard } from './components/QuizCard'
import { RoomPanel } from './components/RoomPanel'
import { Topbar } from './components/Topbar'
import { players, questions } from './data/questions'
import type { QuizMode } from './types/quiz'

function App() {
  const [activeQuestion, setActiveQuestion] = useState(0)
  const [selectedAnswer, setSelectedAnswer] = useState<string | null>(null)
  const [selectedCategory, setSelectedCategory] = useState('Tümü')
  const [activeMode, setActiveMode] = useState<QuizMode>('room')
  const [roomCode] = useState('ZK-4821')
  const [copyStatus, setCopyStatus] = useState('Kopyala')
  const [answeredCount, setAnsweredCount] = useState(0)
  const [correctCount, setCorrectCount] = useState(0)
  const [currentStreak, setCurrentStreak] = useState(0)
  const [bestStreak, setBestStreak] = useState(4)

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
  const progressPercent = Math.round(((activeQuestion + 1) / filteredQuestions.length) * 100)
  const accuracy = answeredCount === 0 ? 0 : Math.round((correctCount / answeredCount) * 100)
  const xp = correctCount * 120 + bestStreak * 30 + answeredCount * 10
  const levelProgress = Math.min(100, Math.round(((xp % 800) / 800) * 100))

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

  function selectAnswer(answer: string) {
    if (selectedAnswer !== null) {
      return
    }

    const isCorrect = answer === question.correctAnswer
    const nextStreak = isCorrect ? currentStreak + 1 : 0

    setSelectedAnswer(answer)
    setAnsweredCount((count) => count + 1)
    setCurrentStreak(nextStreak)

    if (isCorrect) {
      setCorrectCount((count) => count + 1)
      setBestStreak((streak) => Math.max(streak, nextStreak))
    }
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
      <Topbar xp={xp} accuracy={accuracy} />
      <HeroSection activeMode={activeMode} onSelectMode={setActiveMode} />

      <section className="dashboard-grid">
        <RoomPanel
          players={sortedPlayers}
          roomCode={roomCode}
          copyStatus={copyStatus}
          onCopyRoomCode={copyRoomCode}
        />

        <QuizCard
          question={question}
          currentIndex={activeQuestion}
          totalQuestions={filteredQuestions.length}
          selectedAnswer={selectedAnswer}
          progressPercent={progressPercent}
          currentStreak={currentStreak}
          onSelectAnswer={selectAnswer}
          onNextQuestion={nextQuestion}
        />

        <InsightPanel
          categories={categories}
          selectedCategory={selectedCategory}
          totalQuestions={questions.length}
          accuracy={accuracy}
          xp={xp}
          levelProgress={levelProgress}
          bestStreak={bestStreak}
          onSelectCategory={selectCategory}
        />
      </section>

      <BottomNavigation activeMode={activeMode} onSelectMode={setActiveMode} />
    </main>
  )
}

export default App
