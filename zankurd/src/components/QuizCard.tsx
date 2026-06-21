import { Check, RotateCcw, ShieldQuestion, Sparkles, Users } from 'lucide-react'
import type { Question } from '../types/quiz'

type QuizCardProps = {
  question: Question
  currentIndex: number
  totalQuestions: number
  selectedAnswer: string | null
  progressPercent: number
  currentStreak: number
  onSelectAnswer: (answer: string) => void
  onNextQuestion: () => void
}

const answerLabels = ['A', 'B', 'C', 'D']

export function QuizCard({
  question,
  currentIndex,
  totalQuestions,
  selectedAnswer,
  progressPercent,
  currentStreak,
  onSelectAnswer,
  onNextQuestion,
}: QuizCardProps) {
  const isAnswered = selectedAnswer !== null
  const isCorrectSelection = selectedAnswer === question.correctAnswer

  return (
    <section className="quiz-stage" aria-label="Aktif soru">
      <div className="quiz-meta">
        <span>{question.category}</span>
        <span>{question.dialect}</span>
        <span>{question.difficulty}</span>
        <strong>
          {String(currentIndex + 1).padStart(2, '0')} / {String(totalQuestions).padStart(2, '0')}
        </strong>
      </div>

      <div className="progress-block" aria-label="Soru ilerleme durumu">
        <div className="progress-track">
          <div className="progress-fill" style={{ width: `${progressPercent}%` }} />
        </div>
        <span>{currentStreak > 0 ? `${currentStreak} doğru seri` : 'Seriyi başlat'}</span>
      </div>

      <h2>{question.prompt}</h2>

      <div className="answer-grid">
        {question.answers.map((answer, index) => {
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
              onClick={() => onSelectAnswer(answer)}
              aria-pressed={isSelected}
              disabled={isAnswered}
            >
              <small>{answerLabels[index]}</small>
              <span>{answer}</span>
              {isCorrect && <Check size={18} />}
            </button>
          )
        })}
      </div>

      {isAnswered && (
        <div className={isCorrectSelection ? 'explanation success' : 'explanation warning'}>
          <ShieldQuestion size={19} />
          <span>
            <strong>{isCorrectSelection ? 'Doğru!' : `Doğru cevap: ${question.correctAnswer}`}</strong>{' '}
            {question.explanation}
          </span>
        </div>
      )}

      <div className="learning-note">
        <Sparkles size={18} />
        <span>{question.learningNote}</span>
      </div>

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
        <button type="button" onClick={onNextQuestion}>
          <RotateCcw size={18} />
          Sonraki soru
        </button>
      </div>
    </section>
  )
}
