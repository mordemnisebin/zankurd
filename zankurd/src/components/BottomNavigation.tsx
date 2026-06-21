import type { ReactNode } from 'react'
import { BookOpen, Gamepad2, Trophy, Users } from 'lucide-react'
import type { QuizMode } from '../types/quiz'

type BottomNavigationProps = {
  activeMode: QuizMode
  onSelectMode: (mode: QuizMode) => void
}

type NavItem = {
  mode: QuizMode
  label: string
  icon: ReactNode
}

const navItems: NavItem[] = [
  { mode: 'learn', label: 'Öğren', icon: <BookOpen size={18} /> },
  { mode: 'room', label: 'Oda', icon: <Users size={18} /> },
  { mode: 'daily', label: 'Günlük', icon: <Trophy size={18} /> },
  { mode: 'random', label: 'Yarış', icon: <Gamepad2 size={18} /> },
]

export function BottomNavigation({ activeMode, onSelectMode }: BottomNavigationProps) {
  return (
    <nav className="bottom-nav" aria-label="Mobil gezinme">
      {navItems.map((item) => (
        <button
          type="button"
          key={item.mode}
          className={activeMode === item.mode ? 'active' : ''}
          onClick={() => onSelectMode(item.mode)}
        >
          {item.icon}
          <span>{item.label}</span>
        </button>
      ))}
    </nav>
  )
}
