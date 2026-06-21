import { DoorOpen, Flame, Plus, Radio, Zap } from 'lucide-react'
import { studyModes } from '../data/questions'
import type { QuizMode } from '../types/quiz'

type HeroSectionProps = {
  activeMode: QuizMode
  onSelectMode: (mode: QuizMode) => void
}

export function HeroSection({ activeMode, onSelectMode }: HeroSectionProps) {
  const activeModeCopy = studyModes.find((mode) => mode.mode === activeMode) ?? studyModes[0]

  return (
    <section className="hero-band">
      <div className="hero-copy">
        <span className="eyebrow">
          <Radio size={16} />
          Canlı öğrenme odası açık
        </span>
        <h1>Kürtçe öğren, kültürü keşfet, hevalên te ile yarış.</h1>
        <p>
          ZanKurd; dil, kültür, edebiyat ve gündelik kelimeleri kısa quiz akışlarıyla
          daha oyunlu ve düzenli öğrenmen için tasarlandı.
        </p>

        <div className="mode-preview" aria-live="polite">
          <Flame size={18} />
          <div>
            <strong>{activeModeCopy.title}</strong>
            <span>{activeModeCopy.description}</span>
          </div>
        </div>
      </div>

      <div className="quick-actions" aria-label="Hızlı işlemler">
        <button
          type="button"
          className={activeMode === 'room' ? 'primary-action' : 'secondary-action'}
          onClick={() => onSelectMode('room')}
        >
          <Plus size={20} />
          Oda Kur
        </button>
        <button
          type="button"
          className={activeMode === 'learn' ? 'primary-action' : 'secondary-action'}
          onClick={() => onSelectMode('learn')}
        >
          <DoorOpen size={20} />
          Tek Başına
        </button>
        <button
          type="button"
          className={activeMode === 'random' ? 'primary-action' : 'secondary-action'}
          onClick={() => onSelectMode('random')}
        >
          <Zap size={20} />
          Rastgele
        </button>
      </div>
    </section>
  )
}
