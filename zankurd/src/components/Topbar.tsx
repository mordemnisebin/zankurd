import { Bell, Coins, Sparkles } from 'lucide-react'

type TopbarProps = {
  xp: number
  accuracy: number
}

export function Topbar({ xp, accuracy }: TopbarProps) {
  return (
    <nav className="topbar" aria-label="Ana gezinme">
      <div className="brand-mark">
        <div className="brand-symbol" aria-hidden="true">
          <Sparkles size={21} />
        </div>
        <div>
          <strong>ZanKurd</strong>
          <span>Bi pirsan fêr bibe</span>
        </div>
      </div>

      <div className="top-actions">
        <button type="button" className="icon-button" aria-label="Bildirimler">
          <Bell size={19} />
        </button>
        <button type="button" className="coin-pill" aria-label="Mevcut deneyim puanı">
          <Coins size={18} />
          {xp.toLocaleString('tr-TR')} XP
        </button>
        <div className="accuracy-pill" aria-label="Doğruluk oranı">
          %{accuracy}
        </div>
      </div>
    </nav>
  )
}
