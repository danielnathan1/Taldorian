// ──────────────────────────────────────────────────────────────────────────
// DeckBuilder — App
// ──────────────────────────────────────────────────────────────────────────

const MAX_HEROES = 3;
const MAX_CARDS = 50;
const MAX_COPIES = 4;

// Placeholder keyword matcher for the "Efeitos" filter — real tagging comes later.
function matchesEffectTag(card, tag) {
  const t = card.effect.toLowerCase();
  switch (tag) {
    case 'Dano':      return /dano|causa/.test(t);
    case 'Cura':      return /cura/.test(t);
    case 'Buff':      return /ganha|convoca|\+\d/.test(t);
    case 'Debuff':    return /atordoa|desarma|silencia|maldi/.test(t);
    case 'Controle':  return /congela|enraí|cancela|imune|esquiva/.test(t);
    case 'Recurso':   return /rouba|dreno/.test(t);
    default:          return false;
  }
}

// Read ?deck=ID / ?new=1 so the Deck List screen can deep-link into a deck.
function initFromURL() {
  const base = JSON.parse(JSON.stringify(DEFAULT_DECKS));
  const params = new URLSearchParams(window.location.search);
  if (params.get('new')) {
    const fresh = { id: `deck_${Date.now()}`, name: 'Novo deck', sleeve: 'taldor', playmat: 'dark', heroes: [], cards: {} };
    base.push(fresh);
    return { decks: base, activeId: fresh.id };
  }
  const wanted = params.get('deck');
  const match = wanted && base.find(d => d.id === wanted);
  return { decks: base, activeId: match ? match.id : base[0].id };
}

function App() {
  // Decks state
  const _init = useMemo(initFromURL, []);
  const [decks, setDecks] = useState(_init.decks);
  const [activeDeckId, setActiveDeckId] = useState(_init.activeId);
  const [originalSnapshot, setOriginalSnapshot] = useState(() => JSON.stringify(_init.decks.find(d => d.id === _init.activeId)));

  // UI
  const [tab, setTab] = useState('heroes'); // 'heroes' | 'cards'
  const [editingName, setEditingName] = useState(false);
  const [showDeckPicker, setShowDeckPicker] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [toast, setToast] = useState(null);

  // Hero filters
  const [heroSearch, setHeroSearch] = useState('');
  const [heroClassFilters, setHeroClassFilters] = useState([]);

  // Card filters (multi-select)
  const [cardSearch, setCardSearch] = useState('');
  const [cardRarities, setCardRarities] = useState([]);
  const [cardElements, setCardElements] = useState([]);
  const [cardTypes, setCardTypes] = useState([]);
  const [cardEffects, setCardEffects] = useState([]);
  const [cardAtkMin, setCardAtkMin] = useState(0);
  const [cardCostMax, setCardCostMax] = useState(6);
  const [showOnlyInDeck, setShowOnlyInDeck] = useState(false);

  const toggleVal = (arr, setArr, val) => setArr(arr.includes(val) ? arr.filter(x => x !== val) : [...arr, val]);

  const clearCardFilters = () => {
    setCardSearch(''); setCardRarities([]); setCardElements([]); setCardTypes([]);
    setCardEffects([]); setCardAtkMin(0); setCardCostMax(6); setShowOnlyInDeck(false);
  };

  const cardFilterCount = cardRarities.length + cardElements.length + cardTypes.length + cardEffects.length
    + (cardAtkMin > 0 ? 1 : 0) + (cardCostMax < 6 ? 1 : 0) + (showOnlyInDeck ? 1 : 0) + (cardSearch ? 1 : 0);

  // Derived
  const activeDeck = decks.find(d => d.id === activeDeckId) || decks[0];
  const heroObjs = activeDeck.heroes.map(id => HEROES.find(h => h.id === id)).filter(Boolean);
  const cardCount = Object.values(activeDeck.cards).reduce((s, n) => s + n, 0);
  const isDirty = JSON.stringify(activeDeck) !== originalSnapshot;

  // Show toast helper
  const showToast = (msg, kind='info') => {
    setToast({ msg, kind });
    setTimeout(() => setToast(null), 2400);
  };

  // ── Filtering ────────────────────────────────────────────────────────────
  const filteredHeroes = useMemo(() => {
    return HEROES.filter(h => {
      if (heroClassFilters.length && !heroClassFilters.includes(h.heroClass)) return false;
      if (heroSearch && !h.name.toLowerCase().includes(heroSearch.toLowerCase())) return false;
      return true;
    });
  }, [heroSearch, heroClassFilters]);

  const filteredCards = useMemo(() => {
    return CARDS.filter(c => {
      if (cardRarities.length && !cardRarities.includes(c.rarity)) return false;
      if (cardElements.length && !cardElements.includes(c.element)) return false;
      if (cardTypes.length && !cardTypes.includes(c.type)) return false;
      if (cardEffects.length && !cardEffects.some(tag => matchesEffectTag(c, tag))) return false;
      if (c.atk < cardAtkMin) return false;
      if (c.cost > cardCostMax) return false;
      if (cardSearch && !c.name.toLowerCase().includes(cardSearch.toLowerCase())) return false;
      if (showOnlyInDeck && !activeDeck.cards[c.id]) return false;
      return true;
    });
  }, [cardSearch, cardRarities, cardElements, cardTypes, cardEffects, cardAtkMin, cardCostMax, showOnlyInDeck, activeDeck]);

  // ── Deck mutations ───────────────────────────────────────────────────────
  function updateActiveDeck(mutator) {
    setDecks(prev => prev.map(d => d.id === activeDeckId ? mutator(d) : d));
  }

  function addHero(heroId) {
    if (heroObjs.length >= MAX_HEROES) {
      showToast('Já existem 3 heróis no deck', 'warn');
      return;
    }
    if (activeDeck.heroes.includes(heroId)) return;
    updateActiveDeck(d => ({ ...d, heroes: [...d.heroes, heroId] }));
  }

  function removeHero(heroId) {
    updateActiveDeck(d => ({ ...d, heroes: d.heroes.filter(id => id !== heroId) }));
  }

  function addCard(cardId) {
    const currentCount = activeDeck.cards[cardId] || 0;
    if (currentCount >= MAX_COPIES) {
      showToast(`Máximo de ${MAX_COPIES} cópias por carta`, 'warn');
      return;
    }
    if (cardCount >= MAX_CARDS) {
      showToast('Deck cheio — 50 cartas', 'warn');
      return;
    }
    updateActiveDeck(d => ({ ...d, cards: { ...d.cards, [cardId]: currentCount + 1 } }));
  }

  function removeCard(cardId) {
    const currentCount = activeDeck.cards[cardId] || 0;
    if (currentCount <= 0) return;
    updateActiveDeck(d => {
      const next = { ...d.cards };
      if (currentCount === 1) delete next[cardId];
      else next[cardId] = currentCount - 1;
      return { ...d, cards: next };
    });
  }

  function renameActiveDeck(name) {
    updateActiveDeck(d => ({ ...d, name }));
  }

  // Deck-level actions
  function saveDeck() {
    setOriginalSnapshot(JSON.stringify(activeDeck));
    showToast('✦ Deck salvo', 'success');
  }

  function createNewDeck() {
    const id = `deck_${Date.now()}`;
    const newDeck = { id, name: 'Novo deck', sleeve: 'taldor', playmat: 'dark', heroes: [], cards: {} };
    setDecks(prev => [...prev, newDeck]);
    setActiveDeckId(id);
    setOriginalSnapshot(JSON.stringify(newDeck));
    setShowDeckPicker(false);
    setTab('heroes');
    showToast('✦ Novo deck criado', 'success');
  }

  function selectDeck(id) {
    const target = decks.find(d => d.id === id);
    if (!target) return;
    setActiveDeckId(id);
    setOriginalSnapshot(JSON.stringify(target));
    setShowDeckPicker(false);
  }

  function deleteActiveDeck() {
    if (decks.length <= 1) {
      showToast('Mantenha ao menos um deck', 'warn');
      setConfirmDelete(false);
      return;
    }
    const idx = decks.findIndex(d => d.id === activeDeckId);
    const next = decks.filter(d => d.id !== activeDeckId);
    const newActive = next[Math.max(0, idx - 1)];
    setDecks(next);
    setActiveDeckId(newActive.id);
    setOriginalSnapshot(JSON.stringify(newActive));
    setConfirmDelete(false);
    showToast('Deck apagado', 'info');
  }

  function discardChanges() {
    const snap = JSON.parse(originalSnapshot);
    setDecks(prev => prev.map(d => d.id === activeDeckId ? snap : d));
    showToast('Alterações descartadas', 'info');
  }

  // ── Deck list summary (sorted by cost then name) ─────────────────────────
  const sortedDeckCards = useMemo(() => {
    return Object.entries(activeDeck.cards)
      .map(([id, count]) => ({ card: CARDS.find(c => c.id === id), count }))
      .filter(x => x.card)
      .sort((a, b) => (a.card.cost - b.card.cost) || a.card.name.localeCompare(b.card.name));
  }, [activeDeck]);

  // Mana curve buckets
  const manaCurve = useMemo(() => {
    const buckets = [0, 0, 0, 0, 0, 0, 0]; // 0,1,2,3,4,5,6+
    Object.entries(activeDeck.cards).forEach(([id, count]) => {
      const card = CARDS.find(c => c.id === id);
      if (!card) return;
      const idx = Math.min(card.cost, 6);
      buckets[idx] += count;
    });
    return buckets;
  }, [activeDeck]);
  const maxBucket = Math.max(1, ...manaCurve);

  // ── RENDER ───────────────────────────────────────────────────────────────
  return (
    <div className="screen" data-screen-label="Deck Builder">

      {/* TOP HEADER ─────────────────────────────────────────────── */}
      <header className="top-header">
        <div className="header-left">
          <a className="back-btn" href="Deck List.html" title="Voltar aos meus decks">
            <svg width="14" height="14" viewBox="0 0 14 14"><path d="M9 1 L3 7 L9 13" stroke="currentColor" strokeWidth="1.6" fill="none"/></svg>
            <span>Meus Decks</span>
          </a>
          <div className="header-sep"/>
          <div className="header-eyebrow">
            <div className="eyebrow-line">Forja de Decks</div>
            <div className="eyebrow-title">Construa sua trindade</div>
          </div>
        </div>

        <div className="header-center">
          <div className="deck-switcher">
            <button className="deck-switcher-trigger"
                    onClick={() => setShowDeckPicker(s => !s)}>
              <svg width="14" height="14" viewBox="0 0 14 14"><path d="M2 4 L7 9 L12 4" stroke="currentColor" strokeWidth="1.4" fill="none"/></svg>
              <span className="switcher-label">DECK ATIVO</span>
            </button>

            {editingName ? (
              <input
                autoFocus
                className="deck-name-input"
                value={activeDeck.name}
                onChange={(e) => renameActiveDeck(e.target.value)}
                onBlur={() => setEditingName(false)}
                onKeyDown={(e) => { if (e.key === 'Enter') setEditingName(false); }}
              />
            ) : (
              <button className="deck-name" onClick={() => setEditingName(true)} title="Clique para renomear">
                {activeDeck.name}
                <svg width="11" height="11" viewBox="0 0 12 12" style={{marginLeft:8, opacity:0.5}}>
                  <path d="M1 11 L2 8 L8 2 L10 4 L4 10 Z" stroke="currentColor" strokeWidth="1" fill="none"/>
                </svg>
              </button>
            )}

            {showDeckPicker && (
              <div className="deck-picker">
                <div className="picker-header">Meus decks</div>
                {decks.map(d => {
                  const heroes = d.heroes.length;
                  const cards = Object.values(d.cards).reduce((s, n) => s + n, 0);
                  const valid = heroes === MAX_HEROES && cards === MAX_CARDS;
                  return (
                    <button key={d.id}
                            className={`picker-item ${d.id === activeDeckId ? 'active' : ''}`}
                            onClick={() => selectDeck(d.id)}>
                      <div className="picker-item-name">{d.name}</div>
                      <div className="picker-item-meta">
                        <span className={heroes === MAX_HEROES ? 'ok' : 'pending'}>{heroes}/3 ♛</span>
                        <span className={cards === MAX_CARDS ? 'ok' : 'pending'}>{cards}/50 ❖</span>
                        {valid && <span className="picker-pill-ok">Pronto</span>}
                      </div>
                    </button>
                  );
                })}
                <button className="picker-new" onClick={createNewDeck}>
                  <span style={{fontSize:'1rem', marginRight:6}}>+</span> Novo deck
                </button>
              </div>
            )}
          </div>
        </div>

        <div className="header-right">
          {isDirty && (
            <button className="header-btn ghost" onClick={discardChanges}>Descartar</button>
          )}
          <button className="header-btn danger" onClick={() => setConfirmDelete(true)}>
            <svg width="13" height="13" viewBox="0 0 14 14"><path d="M4 2 H10 V3 H4Z M3 4 H11 L10 13 H4Z" stroke="currentColor" strokeWidth="1" fill="none"/></svg>
            Apagar
          </button>
          <button className={`header-btn primary ${!isDirty ? 'is-saved' : ''}`} onClick={saveDeck}>
            <svg width="13" height="13" viewBox="0 0 14 14"><path d="M2 2 H10 L12 4 V12 H2Z M4 2 V6 H9 V2 M4 12 V8 H10 V12" stroke="currentColor" strokeWidth="1" fill="none"/></svg>
            {isDirty ? 'Salvar' : 'Salvo'}
          </button>
        </div>
      </header>

      {/* BODY ──────────────────────────────────────────────────── */}
      <div className="body-grid">

        {/* LEFT: collection picker */}
        <main className="picker-pane">

          {/* Tabs */}
          <div className="picker-tabs">
            <button className={`tab ${tab === 'heroes' ? 'active' : ''}`}
                    onClick={() => setTab('heroes')}>
              <span className="tab-glyph">♛</span>
              <span>Heróis</span>
              <span className="tab-counter">{heroObjs.length}/{MAX_HEROES}</span>
            </button>
            <button className={`tab ${tab === 'cards' ? 'active' : ''}`}
                    onClick={() => setTab('cards')}>
              <span className="tab-glyph">❖</span>
              <span>Cartas</span>
              <span className="tab-counter">{cardCount}/{MAX_CARDS}</span>
            </button>

            <div className="tabs-spacer"/>
            <div className="picker-hint">
              <span>Clique numa carta para adicionar</span>
            </div>
          </div>

          {/* Filters */}
          {tab === 'heroes' ? (
            <div className="filters">
              <div className="filters-top-row">
                <SearchInput value={heroSearch} onChange={setHeroSearch} placeholder="Buscar por nome…"/>
                {heroClassFilters.length > 0 && (
                  <button className="clear-filters-btn" onClick={() => setHeroClassFilters([])}>Limpar ({heroClassFilters.length})</button>
                )}
              </div>
              <FilterGroup label="CLASSE">
                <FilterChip active={heroClassFilters.length === 0}
                            label="Todas" onClick={() => setHeroClassFilters([])}/>
                {HERO_CLASSES.map(c => (
                  <FilterChip key={c}
                              active={heroClassFilters.includes(c)}
                              label={c}
                              onClick={() => toggleVal(heroClassFilters, setHeroClassFilters, c)}/>
                ))}
              </FilterGroup>
            </div>
          ) : (
            <div className="filters card-filters">
              <div className="filters-top-row">
                <SearchInput value={cardSearch} onChange={setCardSearch} placeholder="Buscar carta…"/>
                <button className={`filter-toggle ${showOnlyInDeck ? 'active' : ''}`}
                        onClick={() => setShowOnlyInDeck(v => !v)}>
                  <span className="toggle-dot"/> Só no deck
                </button>
                {cardFilterCount > 0 && (
                  <button className="clear-filters-btn" onClick={clearCardFilters}>Limpar filtros ({cardFilterCount})</button>
                )}
              </div>

              <div className="filter-groups-grid">
                <FilterGroup label="ELEMENTO">
                  <FilterChip active={cardElements.length === 0} label="Todos"
                              onClick={() => setCardElements([])}/>
                  {ELEMENTS.map(e => (
                    <button key={e}
                      className={`filter-chip element ${cardElements.includes(e) ? 'active' : ''}`}
                      onClick={() => toggleVal(cardElements, setCardElements, e)}>
                      <ElementPip type={e} size={14}/>
                      <span style={{textTransform:'capitalize'}}>{e === 'agua' ? 'Água' : e === 'dark' ? 'Trevas' : e}</span>
                    </button>
                  ))}
                </FilterGroup>

                <FilterGroup label="RARIDADE">
                  <FilterChip active={cardRarities.length === 0} label="Todas"
                              onClick={() => setCardRarities([])}/>
                  {RARITIES.map(r => (
                    <FilterChip key={r}
                      active={cardRarities.includes(r)}
                      color={RARITY_COLOR[r]}
                      label={<><span style={{color:RARITY_COLOR[r], marginRight:5}}>◆</span>{r}</>}
                      onClick={() => toggleVal(cardRarities, setCardRarities, r)}/>
                  ))}
                </FilterGroup>

                <FilterGroup label="TIPO">
                  <FilterChip active={cardTypes.length === 0} label="Todos"
                              onClick={() => setCardTypes([])}/>
                  {CARD_TYPES.map(t => (
                    <FilterChip key={t}
                      active={cardTypes.includes(t)}
                      label={t}
                      onClick={() => toggleVal(cardTypes, setCardTypes, t)}/>
                  ))}
                </FilterGroup>

                <FilterGroup label="EFEITOS">
                  <FilterChip active={cardEffects.length === 0} label="Todos"
                              onClick={() => setCardEffects([])}/>
                  {EFFECT_TAGS.map(tag => (
                    <FilterChip key={tag}
                      active={cardEffects.includes(tag)}
                      label={tag}
                      onClick={() => toggleVal(cardEffects, setCardEffects, tag)}/>
                  ))}
                </FilterGroup>
              </div>

              <div className="filter-stats-row">
                <StatSlider label="ATAQUE MÍNIMO" value={cardAtkMin} max={7} onChange={setCardAtkMin}/>
                <StatSlider label="CUSTO MÁXIMO" value={cardCostMax} max={6} onChange={setCardCostMax}/>
              </div>

              {cardFilterCount > 0 && (
                <div className="active-filters-bar">
                  {cardSearch && <ActivePill label={`“${cardSearch}”`} onRemove={() => setCardSearch('')}/>}
                  {cardElements.map(e => <ActivePill key={e} label={e === 'agua' ? 'Água' : e === 'dark' ? 'Trevas' : e} onRemove={() => toggleVal(cardElements, setCardElements, e)}/>)}
                  {cardRarities.map(r => <ActivePill key={r} label={r} onRemove={() => toggleVal(cardRarities, setCardRarities, r)}/>)}
                  {cardTypes.map(t => <ActivePill key={t} label={t} onRemove={() => toggleVal(cardTypes, setCardTypes, t)}/>)}
                  {cardEffects.map(f => <ActivePill key={f} label={f} onRemove={() => toggleVal(cardEffects, setCardEffects, f)}/>)}
                  {cardAtkMin > 0 && <ActivePill label={`ATK ≥ ${cardAtkMin}`} onRemove={() => setCardAtkMin(0)}/>}
                  {cardCostMax < 6 && <ActivePill label={`Custo ≤ ${cardCostMax}`} onRemove={() => setCardCostMax(6)}/>}
                  {showOnlyInDeck && <ActivePill label="Só no deck" onRemove={() => setShowOnlyInDeck(false)}/>}
                </div>
              )}
            </div>
          )}

          {/* Grid */}
          <div className="grid-scroll">
            {tab === 'heroes' ? (
              <>
                <div className="grid-meta">
                  Mostrando <strong>{filteredHeroes.length}</strong> de {HEROES.length} heróis
                </div>
                <div className="hero-grid">
                  {filteredHeroes.map(h => (
                    <HeroGridCard key={h.id}
                                  hero={h}
                                  inDeck={activeDeck.heroes.includes(h.id)}
                                  slotsLeft={MAX_HEROES - heroObjs.length}
                                  onAdd={() => addHero(h.id)}/>
                  ))}
                  {filteredHeroes.length === 0 && (
                    <div className="grid-empty">Nenhum herói corresponde aos filtros.</div>
                  )}
                </div>
              </>
            ) : (
              <>
                <div className="grid-meta">
                  Mostrando <strong>{filteredCards.length}</strong> de {CARDS.length} cartas
                </div>
                <div className="card-grid-wrap">
                  {filteredCards.map(c => (
                    <CardGridCard key={c.id}
                                  card={c}
                                  count={activeDeck.cards[c.id] || 0}
                                  maxCopies={MAX_COPIES}
                                  deckFull={cardCount >= MAX_CARDS}
                                  onAdd={() => addCard(c.id)}
                                  onRemove={() => removeCard(c.id)}/>
                  ))}
                  {filteredCards.length === 0 && (
                    <div className="grid-empty">Nenhuma carta corresponde aos filtros.</div>
                  )}
                </div>
              </>
            )}
          </div>
        </main>

        {/* RIGHT: deck composition rail */}
        <aside className="deck-rail">
          <div className="rail-header">
            <div className="rail-title-row">
              <div className="rail-title">{activeDeck.name}</div>
              <div className={`rail-status ${isDirty ? 'dirty' : 'saved'}`}>
                {isDirty ? '● não salvo' : '✓ salvo'}
              </div>
            </div>
            <div className="rail-progress">
              <ProgressTrack label="Heróis" value={heroObjs.length} max={MAX_HEROES}/>
              <ProgressTrack label="Cartas" value={cardCount} max={MAX_CARDS}/>
            </div>
            <div className="mana-curve">
              <div className="mana-curve-label">CURVA DE CUSTO</div>
              <div className="mana-curve-bars">
                {manaCurve.map((n, i) => (
                  <div key={i} className="mana-curve-col">
                    <div className="mana-curve-count">{n || ''}</div>
                    <div className="mana-curve-bar-wrap">
                      <div className="mana-curve-bar" style={{height:`${(n / maxBucket) * 100}%`}}/>
                    </div>
                    <div className="mana-curve-tick">{i === 6 ? '6+' : i}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Heroes summary */}
          <div className="rail-section">
            <div className="rail-section-header">
              <span>HERÓIS</span>
              <span className="rail-section-count">{heroObjs.length}/{MAX_HEROES}</span>
            </div>
            <div className="hero-slots">
              {[0, 1, 2].map(i => (
                <DeckHeroSlot
                  key={i}
                  hero={heroObjs[i]}
                  onRemove={() => heroObjs[i] && removeHero(heroObjs[i].id)}
                />
              ))}
            </div>
          </div>

          {/* Cards summary */}
          <div className="rail-section flex-grow">
            <div className="rail-section-header">
              <span>CARTAS</span>
              <span className="rail-section-count">{cardCount}/{MAX_CARDS}</span>
            </div>
            <div className="card-list-scroll">
              {sortedDeckCards.length === 0 && (
                <div className="rail-empty">
                  <div className="rail-empty-mark">❖</div>
                  <div>Adicione cartas para construir seu deck</div>
                </div>
              )}
              {sortedDeckCards.map(({ card, count }) => (
                <DeckCardRow key={card.id}
                             card={card} count={count}
                             onAdd={() => addCard(card.id)}
                             onRemove={() => removeCard(card.id)}/>
              ))}
            </div>
          </div>
        </aside>
      </div>

      {/* Confirm delete modal */}
      {confirmDelete && (
        <div className="modal-veil" onClick={() => setConfirmDelete(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-title">Apagar deck?</div>
            <div className="modal-body">
              Esta ação não pode ser desfeita. O deck <strong>{activeDeck.name}</strong> será removido permanentemente.
            </div>
            <div className="modal-actions">
              <button className="header-btn ghost" onClick={() => setConfirmDelete(false)}>Cancelar</button>
              <button className="header-btn danger filled" onClick={deleteActiveDeck}>Apagar definitivamente</button>
            </div>
          </div>
        </div>
      )}

      {/* Toast */}
      {toast && <div className={`toast toast-${toast.kind}`}>{toast.msg}</div>}
    </div>
  );
}

function ProgressTrack({ label, value, max }) {
  const pct = Math.min(100, (value / max) * 100);
  const complete = value === max;
  return (
    <div className="progress-track">
      <div className="progress-track-head">
        <span className="progress-label">{label}</span>
        <span className={`progress-value ${complete ? 'complete' : ''}`}>{value}/{max}</span>
      </div>
      <div className="progress-bar-wrap">
        <div className={`progress-bar-fill ${complete ? 'complete' : ''}`}
             style={{width: `${pct}%`}}/>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
