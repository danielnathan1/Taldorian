const { useState, useEffect, useRef, useMemo } = React;

// ── Particles ──────────────────────────────────────────────────────────────
function spawnParticles() {
  const container = document.getElementById('particles');
  if (!container || container.childElementCount) return;
  const colors = ['oklch(0.82 0.16 80)', 'oklch(0.73 0.13 78)', 'oklch(0.55 0.22 15)', 'oklch(0.65 0.12 262)'];
  for (let i = 0; i < 22; i++) {
    const p = document.createElement('div');
    p.className = 'particle';
    const size = Math.random() * 2.6 + 1;
    const color = colors[Math.floor(Math.random() * colors.length)];
    p.style.cssText = `left:${Math.random()*100}%; bottom:-10px; width:${size}px; height:${size}px;
      background:${color}; box-shadow:0 0 6px 2px ${color};
      animation-duration:${Math.random()*14+9}s; animation-delay:${Math.random()*12}s; --drift:${(Math.random()-0.5)*120}px;`;
    container.appendChild(p);
  }
}

// ── Mock data ────────────────────────────────────────────────────────────────
const INITIAL_ROOMS = [
  { id: 1042, name: 'Salão dos Bravos',        type: 'classico', players: 1, cap: 2, locked: false },
  { id: 1043, name: 'Forja de Tal\u2019dorian',type: 'flash',    players: 0, cap: 2, locked: true  },
  { id: 1051, name: 'Duelo dos Anciões',       type: 'classico', players: 2, cap: 2, locked: false },
  { id: 1058, name: 'Câmara das Sombras',      type: 'flash',    players: 1, cap: 2, locked: true  },
  { id: 1067, name: 'Arena do Crepúsculo',     type: 'classico', players: 0, cap: 2, locked: false },
  { id: 1072, name: 'Trono de Cinzas',         type: 'classico', players: 1, cap: 2, locked: false },
  { id: 1080, name: 'Refúgio dos Magos',       type: 'flash',    players: 0, cap: 2, locked: false },
  { id: 1091, name: 'Covil do Bárbaro',        type: 'classico', players: 2, cap: 2, locked: true  },
  { id: 1099, name: 'Torre de Vesper',         type: 'flash',    players: 1, cap: 2, locked: false },
  { id: 1103, name: 'Pátio Silencioso',        type: 'classico', players: 0, cap: 2, locked: false },
  { id: 1118, name: 'Santuário de Mira',       type: 'flash',    players: 0, cap: 2, locked: true  },
  { id: 1126, name: 'Bosque de Orla',          type: 'classico', players: 1, cap: 2, locked: false },
];

const DECKS = [
  { id: 'deck_fogo',   name: 'Inferno Ardente',  heroes: 3, cards: 30 },
  { id: 'deck_aether', name: 'Marés Profundas',  heroes: 2, cards: 24 },
  { id: 'deck_terra',  name: 'Muralha de Pedra', heroes: 3, cards: 30 },
];

const TYPE_LABEL = { classico: 'Clássico', flash: 'Flash' };

// ── Lock icon ──────────────────────────────────────────────────────────────
function Lock() {
  return (
    <span className="lock" title="Sala protegida por senha">
      <span className="lock-shackle"></span>
      <span className="lock-body"></span>
    </span>
  );
}

// ── Toast ──────────────────────────────────────────────────────────────────
function Toast({ msg, onDone }) {
  useEffect(() => { const t = setTimeout(onDone, 2600); return () => clearTimeout(t); }, []);
  return <div className="toast">{msg}</div>;
}

// ── Room row ─────────────────────────────────────────────────────────────────
function RoomRow({ room, selected, onSelect }) {
  const full = room.players >= room.cap;
  return (
    <div
      className={`room-row${selected ? ' selected' : ''}${full ? ' full' : ''}`}
      onClick={() => !full && onSelect(room.id)}
    >
      <span className="room-id">#{room.id}</span>
      <span className="room-name-cell">
        {room.locked && <Lock />}
        <span className="room-name">{room.name}</span>
      </span>
      <span className={`game-chip ${room.type}`}>{TYPE_LABEL[room.type]}</span>
      <span className={`room-players${full ? ' is-full' : ''}`}>
        <svg className="seat-icon" viewBox="0 0 10 10"><circle cx="5" cy="5" r="4" fill="currentColor" opacity="0.7" /></svg>
        <span className="pcount">{room.players}/{room.cap}</span>
      </span>
    </div>
  );
}

// ── Create room modal ──────────────────────────────────────────────────────
function CreateRoomModal({ onClose, onCreate }) {
  const [name, setName] = useState('');
  const [type, setType] = useState('classico');
  const [priv, setPriv] = useState(false);
  const [pw, setPw] = useState('');
  const nameRef = useRef(null);
  useEffect(() => { nameRef.current && nameRef.current.focus(); }, []);

  const canCreate = name.trim() && (!priv || pw.trim());

  const submit = () => {
    if (!canCreate) return;
    onCreate({ name: name.trim(), type, locked: priv, password: priv ? pw.trim() : '' });
  };

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal-box">
        <div className="modal-title">⚒ Criar Sala</div>

        <div className="field">
          <label className="field-label" htmlFor="room-name">Nome da Sala</label>
          <input ref={nameRef} id="room-name" className="field-input" autoComplete="off" spellCheck="false"
            placeholder="ex.: Salão dos Bravos" value={name}
            onChange={e => setName(e.target.value)} onKeyDown={e => e.key === 'Enter' && submit()} maxLength={32} />
        </div>

        <div className="field">
          <label className="field-label">Tipo de Jogo</label>
          <div className="type-toggle">
            <div className={`type-option${type === 'classico' ? ' active' : ''}`} onClick={() => setType('classico')}>
              Clássico<span className="type-sub">partida completa</span>
            </div>
            <div className={`type-option${type === 'flash' ? ' active' : ''}`} onClick={() => setType('flash')}>
              Flash<span className="type-sub">ritmo acelerado</span>
            </div>
          </div>
        </div>

        <div className="field" style={{ marginBottom: 0 }}>
          <div className="check-row" onClick={() => setPriv(v => !v)}>
            <span className={`check-box${priv ? ' checked' : ''}`}>✓</span>
            <span>
              <span className="check-label">Sala privada</span>{'  '}
              <span className="check-hint">— exige senha para entrar</span>
            </span>
          </div>
          <div className={`pw-reveal ${priv ? 'open' : 'closed'}`}>
            <label className="field-label" htmlFor="room-pw">Senha</label>
            <input id="room-pw" className="field-input" type="password" autoComplete="new-password"
              placeholder="defina uma senha" value={pw}
              onChange={e => setPw(e.target.value)} onKeyDown={e => e.key === 'Enter' && submit()} maxLength={24} />
          </div>
        </div>

        <div className="modal-actions">
          <button className="btn btn-cancel" onClick={onClose}>Cancelar</button>
          <button className="btn btn-primary" disabled={!canCreate} onClick={submit}>
            <span className="btn-shimmer"></span>Criar Sala
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Main App ─────────────────────────────────────────────────────────────────
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "bgIntensity": 60,
  "accentFlash": "indigo",
  "compactRows": false
}/*EDITMODE-END*/;

function App() {
  const [rooms, setRooms] = useState(INITIAL_ROOMS);
  const [selectedId, setSelectedId] = useState(null);
  const [filterId, setFilterId] = useState('');
  const [filterName, setFilterName] = useState('');
  const [showCreate, setShowCreate] = useState(false);
  const [activeDeckId, setActiveDeckId] = useState(DECKS[0].id);
  const [deckOpen, setDeckOpen] = useState(false);
  const [queueing, setQueueing] = useState(false);
  const [toast, setToast] = useState(null);
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);

  useEffect(() => { spawnParticles(); }, []);

  const showToast = (msg) => setToast({ msg, id: Date.now() });

  const filtered = useMemo(() => rooms.filter(r => {
    const idOk = !filterId.trim() || String(r.id).includes(filterId.trim());
    const nameOk = !filterName.trim() || r.name.toLowerCase().includes(filterName.trim().toLowerCase());
    return idOk && nameOk;
  }), [rooms, filterId, filterName]);

  const selectedRoom = rooms.find(r => r.id === selectedId) || null;
  const activeDeck = DECKS.find(d => d.id === activeDeckId);

  const connect = () => {
    if (!selectedRoom) return;
    showToast(`✦ Conectando à sala #${selectedRoom.id} — ${selectedRoom.name}`);
  };

  const connectRandom = () => {
    const open = rooms.filter(r => r.players < r.cap);
    if (!open.length) { showToast('✦ Nenhuma sala disponível no momento'); return; }
    const pick = open[Math.floor(Math.random() * open.length)];
    setSelectedId(pick.id);
    showToast(`✦ Sala aleatória — #${pick.id} ${pick.name}`);
  };

  const handleCreate = (data) => {
    const newId = Math.max(...rooms.map(r => r.id)) + Math.floor(Math.random() * 6 + 1);
    const room = { id: newId, name: data.name, type: data.type, players: 1, cap: 2, locked: data.locked };
    setRooms(prev => [room, ...prev]);
    setSelectedId(newId);
    setShowCreate(false);
    showToast(`✦ Sala "${data.name}" criada`);
  };

  const toggleQueue = () => {
    setQueueing(q => !q);
    showToast(queueing ? '✦ Você saiu da fila' : '✦ Buscando oponente de nível similar…');
  };

  return (
    <>
      <style>{`
        #bg-canvas { opacity: ${tweaks.bgIntensity / 100}; }
        .game-chip.flash {
          color: ${tweaks.accentFlash === 'crimson' ? 'var(--crimson-bright)' : tweaks.accentFlash === 'teal' ? 'oklch(0.70 0.12 190)' : 'var(--rune-color)'};
          border-color: ${tweaks.accentFlash === 'crimson' ? 'oklch(0.55 0.22 15 / 0.5)' : tweaks.accentFlash === 'teal' ? 'oklch(0.60 0.12 190 / 0.5)' : 'oklch(0.55 0.16 262 / 0.5)'};
          background: ${tweaks.accentFlash === 'crimson' ? 'oklch(0.42 0.20 15 / 0.10)' : tweaks.accentFlash === 'teal' ? 'oklch(0.55 0.12 190 / 0.10)' : 'oklch(0.50 0.14 262 / 0.10)'};
        }
        ${tweaks.compactRows ? '.room-row { padding-top: 0.55rem !important; padding-bottom: 0.55rem !important; }' : ''}
      `}</style>

      <div className="shell">
        {/* Top bar */}
        <div className="topbar">
          <div className="brand">
            <span className="brand-mark">TALDORIAN</span>
            <span className="brand-tag">Salas de Batalha</span>
          </div>
          <div className="topbar-right">
            <div className="net-status"><span className="net-dot"></span>Rede Local · 12 jogadores online</div>
            <button className="icon-btn" title="Fechar lobby" onClick={() => showToast('✦ Saindo do lobby…')}>✕</button>
          </div>
        </div>

        {/* Columns */}
        <div className="columns">
          {/* LEFT */}
          <div className="panel left-col">
            <div className="left-head">
              <div className="left-head-title">
                <span className="section-label">Salas Abertas</span>
                <span className="room-count">{filtered.length} de {rooms.length}</span>
              </div>
              <div className="filters">
                <div className="filter-wrap">
                  <span className="filter-glyph">#</span>
                  <input className="filter-input num" placeholder="número" inputMode="numeric"
                    value={filterId} onChange={e => setFilterId(e.target.value.replace(/[^0-9]/g, ''))} />
                </div>
                <div className="filter-wrap">
                  <span className="filter-glyph">⌕</span>
                  <input className="filter-input name" placeholder="nome da sala"
                    value={filterName} onChange={e => setFilterName(e.target.value)} />
                </div>
              </div>
            </div>

            <div className="list-cols">
              <span>ID</span><span>Sala</span><span>Modo</span><span>Jogadores</span>
            </div>

            <div className="room-list">
              {filtered.length === 0 ? (
                <div className="empty-state">
                  <div style={{ fontSize: '1.4rem', opacity: 0.5 }}>✦</div>
                  Nenhuma sala encontrada com esse filtro
                </div>
              ) : filtered.map(room => (
                <RoomRow key={room.id} room={room} selected={room.id === selectedId} onSelect={setSelectedId} />
              ))}
            </div>

            <div className="action-bar">
              <button className="btn btn-primary" disabled={!selectedRoom} onClick={connect}>
                <span className="btn-shimmer"></span>
                {selectedRoom ? `⚔ Conectar · #${selectedRoom.id}` : '⚔ Conectar'}
              </button>
              <button className="btn btn-ghost" onClick={connectRandom}>
                <span className="btn-shimmer"></span>⚄ Aleatório
              </button>
              <button className="btn btn-ghost" onClick={() => setShowCreate(true)}>
                <span className="btn-shimmer"></span>✚ Criar Sala
              </button>
            </div>
          </div>

          {/* RIGHT */}
          <div className="right-col">
            {/* Active deck */}
            <div className="panel side-panel" style={{ flex: '0 0 auto' }}>
              <div className="side-head"><span className="section-label">Deck Ativo</span></div>
              <div className="deck-card" onClick={() => setDeckOpen(o => !o)}>
                <div className="deck-card-label">Selecionado</div>
                <div className="deck-card-name">{activeDeck.name}</div>
                <div className="deck-card-meta">{activeDeck.heroes} heróis · {activeDeck.cards} cartas</div>
                <span className="deck-card-chevron">{deckOpen ? '▲' : '▼'}</span>
              </div>
              {deckOpen && (
                <div className="deck-options">
                  {DECKS.map(d => (
                    <div key={d.id} className={`deck-option${d.id === activeDeckId ? ' active' : ''}`}
                      onClick={() => { setActiveDeckId(d.id); setDeckOpen(false); showToast(`✦ Deck ativo: ${d.name}`); }}>
                      <span className="deck-option-name">{d.name}</span>
                      <span className="deck-option-meta">{d.id === activeDeckId ? <span className="check">✓ ativo</span> : `${d.cards} cartas`}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Ranked + builder */}
            <div className="panel side-panel" style={{ flex: '1 1 auto' }}>
              <div className="side-head"><span className="section-label">Partida Rankeada</span></div>
              <div className="ranked-panel">
                <div className="ranked-emblem">
                  <span className="ring"></span><span className="ring-inner"></span><span className="pip">IV</span>
                </div>
                <div className="ranked-tier">Prata IV</div>
                <div className="ranked-elo">1 248 pontos · 7 vitórias seguidas</div>
                {queueing && (
                  <div className="ranked-queueing"><span className="pulse-dot"></span>Na fila · 00:0{Math.floor(Math.random()*9)}</div>
                )}
                <button className={`btn ${queueing ? 'btn-ghost' : 'btn-crimson'}`} onClick={toggleQueue} style={{ width: '100%' }}>
                  <span className="btn-shimmer"></span>
                  {queueing ? '✕ Cancelar Fila' : '⚔ Entrar na Fila Rankeada'}
                </button>
              </div>
              <a className="btn btn-builder" href="Deck Builder.html">
                <span className="btn-shimmer"></span>⚒ Deck Builder
              </a>
            </div>
          </div>
        </div>
      </div>

      {showCreate && <CreateRoomModal onClose={() => setShowCreate(false)} onCreate={handleCreate} />}
      {toast && <Toast key={toast.id} msg={toast.msg} onDone={() => setToast(null)} />}

      <TweaksPanel>
        <TweakSection label="Aparência">
          <TweakSlider label="Intensidade do Fundo" value={tweaks.bgIntensity} min={20} max={100} step={5}
            onChange={v => setTweak('bgIntensity', v)} />
          <TweakRadio label="Cor do modo Flash" value={tweaks.accentFlash}
            options={[
              { value: 'indigo', label: 'Índigo' },
              { value: 'crimson', label: 'Carmesim' },
              { value: 'teal', label: 'Turquesa' },
            ]}
            onChange={v => setTweak('accentFlash', v)} />
          <TweakToggle label="Linhas compactas" value={tweaks.compactRows}
            onChange={v => setTweak('compactRows', v)} />
        </TweakSection>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
