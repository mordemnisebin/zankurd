export type Difficulty = 'Kolay' | 'Orta' | 'Zor'

export type Dialect = 'Kurmancî' | 'Soranî' | 'Zazakî'

export type QuizMode = 'learn' | 'room' | 'random' | 'daily'

export type AppSection = 'quiz' | 'daily' | 'leaderboard' | 'admin' | 'roadmap'

export type Question = {
  id: string
  category: string
  dialect: Dialect
  difficulty: Difficulty
  prompt: string
  answers: string[]
  correctAnswer: string
  explanation: string
  learningNote: string
  source?: string
  tags: string[]
}

export type Player = {
  name: string
  score: number
  streak: number
  status: 'Hazır' | 'Cevapladı' | 'Bekliyor'
}

export type StudyMode = {
  mode: QuizMode
  title: string
  description: string
}

export type UserProgress = {
  xp: number
  answeredCount: number
  correctCount: number
  currentStreak: number
  bestStreak: number
  dailyStreak: number
  favoriteQuestionIds: string[]
  wrongQuestionIds: string[]
  completedCategoryIds: string[]
  updatedAt: string
}

export type LeaderboardEntry = {
  name: string
  score: number
  streak: number
  badge: string
  isCurrentUser?: boolean
}

export type DailyChallenge = {
  id: string
  title: string
  description: string
  questionIds: string[]
  rewardXp: number
  date: string
}

export type QuestionDraft = {
  category: string
  dialect: Dialect
  difficulty: Difficulty
  prompt: string
  answers: string[]
  correctAnswer: string
  explanation: string
  learningNote: string
  source: string
  tags: string
}

export type ProductCapability = {
  id: AppSection
  title: string
  description: string
  status: 'Ready' | 'Draft' | 'Backend-ready' | 'Next'
}
