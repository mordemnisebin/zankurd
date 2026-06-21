export type Difficulty = 'Kolay' | 'Orta' | 'Zor'

export type Dialect = 'Kurmancî' | 'Soranî' | 'Zazakî'

export type QuizMode = 'learn' | 'room' | 'random' | 'daily'

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
