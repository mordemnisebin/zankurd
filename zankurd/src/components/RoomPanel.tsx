import { Copy, Flame, Play, Users } from 'lucide-react'
import type { Player } from '../types/quiz'

type RoomPanelProps = {
  players: Player[]
  roomCode: string
  copyStatus: string
  onCopyRoomCode: () => void
}

export function RoomPanel({ players, roomCode, copyStatus, onCopyRoomCode }: RoomPanelProps) {
  return (
    <aside className="room-panel" aria-label="Oda bilgileri">
      <div className="panel-heading">
        <div>
          <span className="section-label">Özel oda</span>
          <h2>Hevalên Zanînê</h2>
        </div>
        <button type="button" className="icon-button" aria-label="Oda kodunu kopyala" onClick={onCopyRoomCode}>
          <Copy size={18} />
        </button>
      </div>

      <div className="room-code">
        <span>Oda kodu</span>
        <strong>{roomCode}</strong>
        <small>{copyStatus}</small>
      </div>

      <div className="room-summary">
        <div>
          <Users size={18} />
          <strong>{players.length}</strong>
          <span>Oyuncu</span>
        </div>
        <div>
          <Flame size={18} />
          <strong>{Math.max(...players.map((player) => player.streak))}</strong>
          <span>En iyi seri</span>
        </div>
      </div>

      <div className="player-list">
        {players.map((player, index) => (
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
  )
}
