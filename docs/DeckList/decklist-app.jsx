// ──────────────────────────────────────────────────────────────────────────
// Deck List — galeria de decks do jogador (sleeve + playmat)
// ──────────────────────────────────────────────────────────────────────────
const { useState, useMemo, useEffect } = React;

const DL_MAX_HEROES = 3;
const DL_MAX_CARDS = 50;

const SLEEVE_BY_ID  = Object.fromEntries(SLEEVES.map(s => [s.id, s]));
const PLAYMAT_BY_ID = Object.fromEntries(PLAYMATS.map(p => [p.id, p]));

const CLASS_BG = {
  BARBARIAN: 'oklch(0.32 0.12 35 / 0.6)',
  MAGE:      'oklch(0.28 0.14 300 / 0.6)',
  ARCHER:    'oklch(0.26 0.10 145 / 0.6)',
  KNIGHT:    'oklch(0.28 0.06 78 / 0.6)',
  ASSASSIN:  'oklch(0.20 0.10 300 / 0.7)',
  HEALER:    'oklch(0.30 0.04 95 / 0.6)',
  DRUID:     'oklch(0.26 0.10 130 / 0.6)',
};

// ── Sleeve thumbnail (fanned card-backs) ─────────────────────────────────
function SleeveStack({ sleeveId }) {
  const sleeve = SLEEVE_BY_ID[sleeveId] || SLEEVES[0];
  const tint = sleeve.tint;
  const card = (cls) => (
    <div className={`sleeve-card ${cls}`}>
      {tint && <div className="sleeve-tint" style={{ background: tint }}/>}
      <div className="sleeve-sheen"/>
    </div>
  );
  return (
    <div className="sleeve-stack" style={{ '--sleeve-art': `url(${SLEEVE_ART})` }}>
      {card('back2')}
      {card('back1')}
      {card('front')}
    </div>
  );
}

// ── A single deck plate ──────────────────────────────────────────────────
function DeckPlate({ deck, selected, onSelect, onEdit, onDelete }) {
  const sleeve  = SLEEVE_BY_ID[deck.sleeve]   || SLEEVES[0];
  const playmat = PLAYMAT_BY_ID[deck.playmat] || PLAYMATS[0];
  const heroObjs = deck.heroes.map(id => HEROES.find(h => h.id === id)).filter(Boolean);
  const cardCount = Object.values(deck.cards).reduce((s, n) => s + n, 0);
  const ready = heroObjs.length === DL_MAX_HEROES && cardCount === DL_MAX_CARDS;
  const named = deck.name && deck.name.trim() && deck.name !== 'Deck sem nome';

  return (
    <div className={`deck-plate ${selected ? 'selected' : ''}`}
         onClick={() => onSelect(deck.id)}
         onDoubleClick={() => onEdit(deck.id)}>

      <div className="plate-showcase" style={{ background: playmat.bg }}>
        <div className="playmat-name">
          <span className="pm-swatch" style={{ background: playmat.thumb }}/>
          {playmat.label}
        </div>
        <div className={`plate-status ${ready ? 'ready' : 'draft'}`}>
          {ready ? '✦ Pronto' : 'Rascunho'}
        </div>
        <SleeveStack sleeveId={deck.sleeve}/>
      </div>

      <div className="plate-body">
        <div className={`plate-name ${named ? '' : 'unnamed'}`}>{deck.name || 'Deck sem nome'}</div>

        <div className="plate-heroes">
          {[0, 1, 2].map(i => {
            const h = heroObjs[i];
            if (!h) return <div key={i} className="hero-chip empty">+</div>;
            return (
              <div key={i} className="hero-chip"
                   title={`${h.name} · ${h.heroClass}`}
                   style={{ '--chip-bg': CLASS_BG[h.heroClass] }}>
                <ClassGlyph heroClass={h.heroClass} size={20}/>
              </div>
            );
          })}
        </div>

        <div className="plate-counts">
          <div className="count-stat">
            <span className={`cs-num ${heroObjs.length === DL_MAX_HEROES ? 'full' : ''}`}>
              {heroObjs.length}<span style={{opacity:0.4, fontWeight:400}}>/{DL_MAX_HEROES}</span>
            </span>
            <span className="cs-lbl">Heróis</span>
          </div>
          <div className="count-stat">
            <span className={`cs-num ${cardCount === DL_MAX_CARDS ? 'full' : ''}`}>
              {cardCount}<span style={{opacity:0.4, fontWeight:400}}>/{DL_MAX_CARDS}</span>
            </span>
            <span className="cs-lbl">Cartas</span>
          </div>
        </div>
      </div>

      <div className="plate-meta">
        <div className="meta-row">
          <span className="meta-k">Sleeve</span>
          <span className="meta-swatch round" style={{ background: sleeve.swatch }}/>
          <span className="meta-v">{sleeve.label}</span>
        </div>
        <div className="meta-row">
          <span className="meta-k">Playmat</span>
          <span className="meta-swatch" style={{ background: playmat.thumb }}/>
          <span className="meta-v">{playmat.label}</span>
        </div>
      </div>

      {/* quick actions on hover / selection */}
      <div className="plate-quick">
        <button className="quick-btn edit" onClick={(e) => { e.stopPropagation(); onEdit(deck.id); }}>
          <svg width="13" height="13" viewBox="0 0 14 14"><path d="M1 13 L2 9.5 L9.5 2 L12 4.5 L4.5 12 Z" stroke="currentColor" strokeWidth="1.1" fill="none"/></svg>
          Editar
        </button>
        <button className="quick-btn del" onClick={(e) => { e.stopPropagation(); onDelete(deck.id); }} title="Apagar deck">
          <svg width="13" height="13" viewBox="0 0 14 14"><path d="M4 2 H10 V3 H4Z M3 4 H11 L10 13 H4Z" stroke="currentColor" strokeWidth="1" fill="none"/></svg>
        </button>
      </div>

      <span className="plate-tick-bl"/><span className="plate-tick-br"/>
    </div>
  );
}

// ── App ──────────────────────────────────────────────────────────────────
function App() {
  const [decks, setDecks] = useState(() => JSON.parse(JSON.stringify(DEFAULT_DECKS)));
  const [selectedId, setSelectedId] = useState(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState(null);
  const [toast, setToast] = useState(null);

  const showToast = (msg, kind = 'info') => {
    setToast({ msg, kind });
    setTimeout(() => setToast(null), 2200);
  };

  const selectedDeck = decks.find(d => d.id === selectedId) || null;

  function goEdit(id) { window.location.href = `Deck Builder.html?deck=${encodeURIComponent(id)}`; }
  function goNew()    { window.location.href = `Deck Builder.html?new=1`; }

  function doDelete() {
    const id = confirmDeleteId;
    const target = decks.find(d => d.id === id);
    setDecks(prev => prev.filter(d => d.id !== id));
    if (selectedId === id) setSelectedId(null);
    setConfirmDeleteId(null);
    showToast(`Deck apagado`, 'info');
  }

  // Esc clears selection / closes modal
  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'Escape') { setConfirmDeleteId(null); setSelectedId(null); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const confirmDeck = decks.find(d => d.id === confirmDeleteId) || null;
  const barSleeve = selectedDeck ? (SLEEVE_BY_ID[selectedDeck.sleeve] || SLEEVES[0]) : null;

  return (
    <div className="screen" data-screen-label="Lista de Decks">

      <header className="top-header">
        <div className="header-left">
          <a className="back-btn" href="Lobby.html" title="Voltar ao Lobby">
            <svg width="14" height="14" viewBox="0 0 14 14"><path d="M9 1 L3 7 L9 13" stroke="currentColor" strokeWidth="1.6" fill="none"/></svg>
            <span>Voltar</span>
          </a>
          <div className="header-sep"/>
          <div className="header-eyebrow">
            <div className="eyebrow-line">Coleção</div>
            <div className="eyebrow-title">Meus Decks</div>
          </div>
        </div>
        <div className="header-right">
          <div className="deck-tally"><strong>{decks.length}</strong> decks</div>
          <button className="header-btn primary" onClick={goNew}>
            <span style={{fontSize:'1rem', lineHeight:0, marginTop:-1}}>+</span> Novo deck
          </button>
        </div>
      </header>

      <div className="list-body">
        <div className="gallery-head">
          <span className="gh-title">Escolha um deck para jogar ou editar</span>
          <span className="gh-hint">Clique para selecionar · duplo-clique para editar</span>
        </div>

        <div className="deck-gallery">
          {decks.map(d => (
            <DeckPlate key={d.id}
                       deck={d}
                       selected={selectedId === d.id}
                       onSelect={setSelectedId}
                       onEdit={goEdit}
                       onDelete={(id) => setConfirmDeleteId(id)}/>
          ))}

          {/* New deck tile */}
          <div className="deck-plate new" onClick={goNew}>
            <div className="new-inner">
              <div className="new-mark">+</div>
              <div className="new-label">Novo deck</div>
              <div className="new-sub">Forje uma nova trindade de heróis</div>
            </div>
          </div>

          {decks.length === 0 && (
            <div className="empty-collection">Você ainda não tem decks. Crie o primeiro!</div>
          )}
        </div>
      </div>

      {/* Contextual action bar */}
      <div className={`action-bar ${selectedDeck ? 'show' : ''}`}>
        {selectedDeck && (
          <>
            <div className="ab-info">
              <div className="ab-sleeve" style={{ '--sleeve-art': `url(${SLEEVE_ART})` }}>
                {barSleeve.tint && <div className="sleeve-tint" style={{ background: barSleeve.tint }}/>}
              </div>
              <div className="ab-text">
                <div className="ab-label">Selecionado</div>
                <div className="ab-name">{selectedDeck.name}</div>
              </div>
            </div>
            <div className="ab-spacer"/>
            <div className="ab-actions">
              <button className="header-btn danger" onClick={() => setConfirmDeleteId(selectedDeck.id)}>
                <svg width="13" height="13" viewBox="0 0 14 14"><path d="M4 2 H10 V3 H4Z M3 4 H11 L10 13 H4Z" stroke="currentColor" strokeWidth="1" fill="none"/></svg>
                Apagar
              </button>
              <button className="header-btn ab-edit" onClick={() => goEdit(selectedDeck.id)}>
                <svg width="13" height="13" viewBox="0 0 14 14"><path d="M1 13 L2 9.5 L9.5 2 L12 4.5 L4.5 12 Z" stroke="currentColor" strokeWidth="1.1" fill="none"/></svg>
                Editar deck
              </button>
            </div>
          </>
        )}
      </div>

      {/* Confirm delete */}
      {confirmDeck && (
        <div className="modal-veil" onClick={() => setConfirmDeleteId(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-title">Apagar deck?</div>
            <div className="modal-body">
              Esta ação não pode ser desfeita. O deck <strong>{confirmDeck.name}</strong> será removido permanentemente da sua coleção.
            </div>
            <div className="modal-actions">
              <button className="header-btn" onClick={() => setConfirmDeleteId(null)}>Cancelar</button>
              <button className="header-btn danger filled" onClick={doDelete}>Apagar definitivamente</button>
            </div>
          </div>
        </div>
      )}

      {toast && <div className={`toast toast-${toast.kind}`}>{toast.msg}</div>}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
