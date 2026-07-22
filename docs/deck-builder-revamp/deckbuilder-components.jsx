// ──────────────────────────────────────────────────────────────────────────
// DeckBuilder — Reusable components
// ──────────────────────────────────────────────────────────────────────────
const { useState, useMemo, useEffect, useRef } = React;

// Element pip used everywhere
function ElementPip({ type, size = 18 }) {
  const cfg = {
    fogo:  { bg:'oklch(0.62 0.22 40)',  fg:'#fff', glyph:'🔥', label:'Fogo'   },
    terra: { bg:'oklch(0.52 0.14 110)', fg:'#fff', glyph:'🪨', label:'Terra'  },
    agua:  { bg:'oklch(0.50 0.15 245)', fg:'#fff', glyph:'💧', label:'Água'   },
    ar:    { bg:'oklch(0.75 0.10 210)', fg:'oklch(0.18 0.05 268)', glyph:'💨', label:'Ar' },
    dark:  { bg:'oklch(0.25 0.10 300)', fg:'#fff', glyph:'🌑', label:'Trevas' },
  };
  const c = cfg[type] || cfg.fogo;
  return (
    <span title={c.label} style={{
      width:size, height:size, borderRadius:'50%',
      background:c.bg, color:c.fg,
      display:'inline-flex', alignItems:'center', justifyContent:'center',
      fontSize: size * 0.55, flexShrink:0,
      boxShadow:'inset 0 0 0 1px rgba(0,0,0,0.25)',
    }}>{c.glyph}</span>
  );
}
window.ElementPip = ElementPip;

// Class icon (small SVG glyph for each class)
function ClassGlyph({ heroClass, size = 16 }) {
  const map = {
    BARBARIAN: { c:'oklch(0.62 0.22 40)',  d:'M3 17 L10 3 L17 17 Z' },
    MAGE:      { c:'oklch(0.55 0.22 300)', d:'M10 1 L14 7 L19 10 L14 13 L10 19 L6 13 L1 10 L6 7 Z' },
    ARCHER:    { c:'oklch(0.55 0.18 145)', d:'M2 18 L18 2 M2 18 L8 18 M2 18 L2 12' },
    KNIGHT:    { c:'oklch(0.73 0.13 78)',  d:'M10 2 L17 6 V12 Q17 17 10 19 Q3 17 3 12 V6 Z' },
    ASSASSIN:  { c:'oklch(0.45 0.12 300)', d:'M10 2 L13 10 L10 18 L7 10 Z' },
    HEALER:    { c:'oklch(0.85 0.05 95)',  d:'M8 3 H12 V8 H17 V12 H12 V17 H8 V12 H3 V8 H8 Z' },
    DRUID:     { c:'oklch(0.55 0.18 130)', d:'M10 2 Q15 6 15 11 Q15 16 10 18 Q5 16 5 11 Q5 6 10 2 Z' },
  };
  const cfg = map[heroClass] || map.KNIGHT;
  const stroked = heroClass === 'ARCHER';
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" style={{display:'block'}}>
      <path d={cfg.d}
        fill={stroked ? 'none' : cfg.c}
        stroke={stroked ? cfg.c : 'rgba(0,0,0,0.3)'}
        strokeWidth={stroked ? 2 : 0.6}/>
    </svg>
  );
}
window.ClassGlyph = ClassGlyph;

// Rarity colors / labels
const RARITY_COLOR = {
  'Comum':     'oklch(0.65 0.02 78)',
  'Incomum':   'oklch(0.65 0.14 145)',
  'Raro':      'oklch(0.62 0.16 245)',
  'Épico':     'oklch(0.62 0.20 300)',
  'Lendário':  'oklch(0.78 0.16 78)',
};
window.RARITY_COLOR = RARITY_COLOR;

// ──────────────────────────────────────────────────────────────────────────
// Hero collection card (small grid item)
// ──────────────────────────────────────────────────────────────────────────
function HeroGridCard({ hero, inDeck, slotsLeft, onAdd }) {
  const canAdd = slotsLeft > 0 && !inDeck;
  return (
    <div className={`hero-grid-card ${inDeck ? 'in-deck' : ''} ${!canAdd && !inDeck ? 'disabled' : ''}`}
         onClick={canAdd ? onAdd : undefined}>
      {inDeck && (
        <div className="grid-card-ribbon">
          <span style={{marginRight:6}}>✓</span> No deck
        </div>
      )}
      <div className="hero-grid-art">
        <div className="hero-art-bg" style={{
          background:`linear-gradient(165deg, ${classBg(hero.heroClass)}, oklch(0.13 0.04 268))`,
        }}>
          <div className="hero-art-glyph"><ClassGlyph heroClass={hero.heroClass} size={56}/></div>
        </div>
        <div className="hero-grid-hp">
          <span className="hp-icon">♥</span>{hero.hp}
        </div>
        <div className="hero-grid-class-pill">
          <ClassGlyph heroClass={hero.heroClass} size={11}/>
          <span>{hero.heroClass}</span>
        </div>
      </div>
      <div className="hero-grid-body">
        <div className="hero-grid-name">{hero.name}</div>
        <div className="hero-grid-stats">
          <span className="stat-atk">⚔ {hero.attack}</span>
          <span className="stat-def">🛡 {hero.defense}</span>
        </div>
        <div className="hero-grid-symbols">
          {hero.skillSymbols.map((s,i) => <ElementPip key={i} type={s} size={14}/>)}
        </div>
      </div>
      {canAdd && <div className="grid-card-add-overlay"><span>+ Adicionar</span></div>}
    </div>
  );
}

function classBg(cls) {
  const m = {
    BARBARIAN: 'oklch(0.32 0.12 35 / 0.6)',
    MAGE:      'oklch(0.28 0.14 300 / 0.6)',
    ARCHER:    'oklch(0.26 0.10 145 / 0.6)',
    KNIGHT:    'oklch(0.28 0.06 78 / 0.6)',
    ASSASSIN:  'oklch(0.20 0.10 300 / 0.7)',
    HEALER:    'oklch(0.30 0.04 95 / 0.6)',
    DRUID:     'oklch(0.26 0.10 130 / 0.6)',
  };
  return m[cls] || 'oklch(0.20 0.05 268 / 0.6)';
}
window.HeroGridCard = HeroGridCard;

// ──────────────────────────────────────────────────────────────────────────
// Card collection card
// ──────────────────────────────────────────────────────────────────────────
function CardGridCard({ card, count, maxCopies, deckFull, onAdd, onRemove }) {
  const canAdd = count < maxCopies && !deckFull;
  const inDeck = count > 0;
  const rarColor = RARITY_COLOR[card.rarity];
  return (
    <div className={`card-grid ${inDeck ? 'in-deck' : ''} ${!canAdd && !inDeck ? 'disabled' : ''}`}
         onClick={canAdd ? onAdd : undefined}>
      {inDeck && (
        <div className="grid-card-count-badge" onClick={(e) => { e.stopPropagation(); onRemove(); }}
             title="Clique para remover uma cópia">
          ×{count}
        </div>
      )}
      <div className="card-grid-art" style={{
        background:`linear-gradient(160deg, ${elementBg(card.element)} 0%, oklch(0.11 0.04 268) 100%)`,
      }}>
        <div className="card-grid-cost">{card.cost}</div>
        <div className="card-grid-element"><ElementPip type={card.element} size={22}/></div>
        <div className="card-grid-art-glyph">
          <CardArtGlyph type={card.type}/>
        </div>
      </div>
      <div className="card-grid-body">
        <div className="card-grid-name">{card.name}</div>
        <div className="card-grid-meta">
          <span className="card-grid-type">{card.type}</span>
          <span className="card-grid-rarity" style={{color: rarColor}}>◆ {card.rarity}</span>
        </div>
        <div className="card-grid-effect">{card.effect}</div>
      </div>
      {canAdd && (
        <div className="grid-card-add-overlay"><span>+ Adicionar</span></div>
      )}
    </div>
  );
}

function elementBg(element) {
  const m = {
    fogo:  'oklch(0.30 0.16 40 / 0.55)',
    terra: 'oklch(0.28 0.10 110 / 0.55)',
    agua:  'oklch(0.26 0.12 245 / 0.55)',
    ar:    'oklch(0.35 0.06 210 / 0.55)',
    dark:  'oklch(0.18 0.08 300 / 0.7)',
  };
  return m[element] || 'oklch(0.20 0.05 268)';
}
window.CardGridCard = CardGridCard;

function CardArtGlyph({ type }) {
  // Simple abstract glyph by type, just decoration since artwork isn't ready
  if (type === 'Reação') {
    return (
      <svg viewBox="0 0 40 40" width="48" height="48">
        <circle cx="20" cy="20" r="14" stroke="currentColor" strokeWidth="1.4" fill="none" opacity="0.4"/>
        <path d="M20 6 L20 34 M6 20 L34 20" stroke="currentColor" strokeWidth="1" opacity="0.3"/>
        <circle cx="20" cy="20" r="3" fill="currentColor" opacity="0.55"/>
      </svg>
    );
  }
  if (type === 'Ação Bônus') {
    return (
      <svg viewBox="0 0 40 40" width="48" height="48">
        <path d="M20 4 L24 16 L36 16 L26 23 L30 35 L20 28 L10 35 L14 23 L4 16 L16 16 Z"
              fill="none" stroke="currentColor" strokeWidth="1.2" opacity="0.5"/>
      </svg>
    );
  }
  // Ação
  return (
    <svg viewBox="0 0 40 40" width="48" height="48">
      <path d="M6 34 L20 8 L34 34 Z" fill="none" stroke="currentColor" strokeWidth="1.4" opacity="0.5"/>
      <path d="M14 26 L26 26" stroke="currentColor" strokeWidth="1" opacity="0.45"/>
    </svg>
  );
}
window.CardArtGlyph = CardArtGlyph;

// ──────────────────────────────────────────────────────────────────────────
// Right rail — deck composition list item (small)
// ──────────────────────────────────────────────────────────────────────────
function DeckHeroSlot({ hero, onRemove }) {
  if (!hero) {
    return (
      <div className="deck-hero-slot empty">
        <div className="empty-mark">+</div>
        <div className="empty-label">Vazio</div>
      </div>
    );
  }
  return (
    <div className="deck-hero-slot filled">
      <div className="deck-hero-art" style={{
        background:`linear-gradient(165deg, ${classBg(hero.heroClass)}, oklch(0.13 0.04 268))`,
      }}>
        <ClassGlyph heroClass={hero.heroClass} size={32}/>
      </div>
      <div className="deck-hero-info">
        <div className="deck-hero-name">{hero.name}</div>
        <div className="deck-hero-class">{hero.heroClass}</div>
        <div className="deck-hero-stats">
          <span>♥{hero.hp}</span>
          <span>⚔{hero.attack}</span>
          <span>🛡{hero.defense}</span>
        </div>
      </div>
      <button className="deck-row-remove" onClick={onRemove} title="Remover">×</button>
    </div>
  );
}
window.DeckHeroSlot = DeckHeroSlot;

function DeckCardRow({ card, count, onAdd, onRemove }) {
  const rarColor = RARITY_COLOR[card.rarity];
  return (
    <div className="deck-card-row">
      <div className="deck-card-cost">{card.cost}</div>
      <ElementPip type={card.element} size={14}/>
      <div className="deck-card-info">
        <div className="deck-card-name">{card.name}</div>
        <div className="deck-card-sub">
          <span style={{color: rarColor}}>◆</span>
          <span>{card.type}</span>
        </div>
      </div>
      <div className="deck-card-counter">
        <button onClick={onRemove} className="counter-btn">−</button>
        <span className="counter-val">×{count}</span>
        <button onClick={onAdd} className="counter-btn">+</button>
      </div>
    </div>
  );
}
window.DeckCardRow = DeckCardRow;

// ──────────────────────────────────────────────────────────────────────────
// Toolbar / filter components
// ──────────────────────────────────────────────────────────────────────────
function FilterChip({ active, label, color, onClick }) {
  return (
    <button className={`filter-chip ${active ? 'active' : ''}`}
            style={active && color ? {borderColor: color, color: color} : undefined}
            onClick={onClick}>
      {label}
    </button>
  );
}
window.FilterChip = FilterChip;

function FilterGroup({ label, children }) {
  return (
    <div className="filter-group">
      <div className="filter-group-label">{label}</div>
      <div className="filter-chips">{children}</div>
    </div>
  );
}
window.FilterGroup = FilterGroup;

function StatSlider({ label, value, min = 0, max, suffix = '', onChange }) {
  const pct = max === min ? 0 : ((value - min) / (max - min)) * 100;
  return (
    <div className="stat-slider-wrap">
      <div className="stat-slider-head">
        <span className="stat-slider-label">{label}</span>
        <span className="stat-slider-value">{value}{suffix}</span>
      </div>
      <input
        type="range"
        className="gold-range"
        min={min} max={max} value={value}
        style={{'--fill': `${pct}%`}}
        onChange={(e) => onChange(Number(e.target.value))}
      />
    </div>
  );
}
window.StatSlider = StatSlider;

function ActivePill({ label, onRemove }) {
  return (
    <button className="active-pill" onClick={onRemove}>
      <span>{label}</span>
      <span className="active-pill-x">×</span>
    </button>
  );
}
window.ActivePill = ActivePill;

function SearchInput({ value, onChange, placeholder }) {
  return (
    <div className="search-input-wrap">
      <svg width="14" height="14" viewBox="0 0 14 14" className="search-icon">
        <circle cx="6" cy="6" r="4.5" stroke="currentColor" strokeWidth="1.2" fill="none"/>
        <path d="M9.5 9.5 L13 13" stroke="currentColor" strokeWidth="1.4"/>
      </svg>
      <input className="search-input"
             value={value}
             onChange={(e) => onChange(e.target.value)}
             placeholder={placeholder}/>
      {value && (
        <button className="search-clear" onClick={() => onChange('')}>×</button>
      )}
    </div>
  );
}
window.SearchInput = SearchInput;
