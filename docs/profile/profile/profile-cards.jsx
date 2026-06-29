/* profile-cards.jsx — Taldorian TCCG player profile cards
   Two variations of a profile modal shown over the World HUD.
   Exports to window: PLAYER, TIERS, RankShield, PeakSeal, FavCard,
   GuildCrest, StatRow, WinBar, ProfileDossier, ProfileSeal */

const { useMemo } = React;

/* ─────────────────────────── Data ─────────────────────────── */
const TIERS = {
  Bronze:   { c:'#c89058', d:'#6f4a26', g:'rgba(200,144,88,.55)' },
  Prata:    { c:'#cdd2dd', d:'#828998', g:'rgba(205,210,221,.55)' },
  Ouro:     { c:'#f1c659', d:'#a87d1e', g:'rgba(241,198,89,.6)'  },
  Platina:  { c:'#86e6da', d:'#3c969c', g:'rgba(134,230,218,.55)' },
  Diamante: { c:'#a4d2ff', d:'#4f8ad0', g:'rgba(164,210,255,.6)' },
  Mestre:   { c:'#ec8ba0', d:'#a3486a', g:'rgba(236,139,160,.6)' },
  Lenda:    { c:'#f7e7a6', d:'#c9a23e', g:'rgba(247,231,166,.65)' },
};

const PLAYER = {
  nick: 'Sagashii',
  level: 24,
  xp: { cur: 3400, max: 5000 },
  current: { tier: 'Ouro', div: 'II', pts: 1480 },
  peak:    { tier: 'Platina', div: 'I', season: 'Temp. 3' },
  guild:   { name: "Ordem de Tal'dorian", tag: 'ORD', role: 'Oficial', color: '#8fd99a' },
  record:  { w: 342, l: 188 },
  since:   'Mar 2024',
  fav:     { name: 'Golpe Bruto', type: 'Ação', element: 'Fogo', rarity: 'Comum', atk: 3, img: '../assets/golpe_bruto.png' },
};

const winrate = (r) => Math.round((r.w / (r.w + r.l)) * 100);

/* ─────────────────────────── Rank shield ─────────────────────────── */
function RankShield({ tier, div, size = 86 }) {
  const t = TIERS[tier] || TIERS.Bronze;
  const s = { '--sc': t.c, '--sd': t.d, '--sg': t.g, width: size, height: size * 1.12 };
  return (
    <div className="shield-wrap" style={s}>
      <div className="shield">
        <div className="shield-shine"></div>
        <svg className="shield-star" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 3.2l2.5 5.1 5.6.8-4.05 3.95.96 5.6L12 22l-5.06-2.65.96-5.6L3.85 9.1l5.6-.8L12 3.2z"/>
        </svg>
      </div>
      <span className="shield-div">{div}</span>
    </div>
  );
}

/* Small circular seal — used for the peak/max rank */
function PeakSeal({ tier, div, size = 50 }) {
  const t = TIERS[tier] || TIERS.Bronze;
  return (
    <div className="seal" style={{ '--sc': t.c, '--sd': t.d, '--sg': t.g, width: size, height: size }}>
      <svg className="seal-star" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 3.5l2.4 4.9 5.4.8-3.9 3.8.92 5.4L12 21.7l-4.83-2.5.92-5.4L4.2 9.2l5.4-.8L12 3.5z"/>
      </svg>
      <span className="seal-div">{div}</span>
    </div>
  );
}

/* ─────────────────────────── Guild crest ─────────────────────────── */
function GuildCrest({ color = '#8fd99a', size = 26 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M12 2.2l7.4 2.3v6.1c0 4.6-3.2 7.4-7.4 9.2-4.2-1.8-7.4-4.6-7.4-9.2V4.5L12 2.2z"
            fill="rgba(0,0,0,.35)" stroke={color} strokeWidth="1.3" strokeLinejoin="round"/>
      <path d="M12 6.4l1.45 2.95 3.25.47-2.35 2.29.55 3.24L12 13.9l-2.9 1.53.55-3.24-2.35-2.29 3.25-.47L12 6.4z"
            fill={color} opacity=".92"/>
    </svg>
  );
}

/* ─────────────────────────── Favorite card ─────────────────────────── */
function FavCard({ fav, tilt = -6, w = 118 }) {
  return (
    <div className="favcard" style={{ '--tilt': `${tilt}deg`, width: w }}>
      <div className="favcard-frame">
        <img className="favcard-art" src={fav.img} alt={fav.name} draggable="false" />
        <div className="favcard-gloss"></div>
      </div>
      <div className="favcard-foot">
        <span className="favcard-atk">+{fav.atk}</span>
        <span className="favcard-el">{fav.element}</span>
      </div>
    </div>
  );
}

/* ─────────────────────────── Stat helpers ─────────────────────────── */
function WinBar({ record, label = true }) {
  const wr = winrate(record);
  return (
    <div className="winbar">
      {label && (
        <div className="winbar-meta">
          <span className="wb-w">{record.w}<i>V</i></span>
          <span className="wb-rate">{wr}%</span>
          <span className="wb-l">{record.l}<i>D</i></span>
        </div>
      )}
      <div className="winbar-track">
        <div className="winbar-fill" style={{ width: `${wr}%` }}></div>
      </div>
    </div>
  );
}

function StatRow({ k, children }) {
  return (
    <div className="statrow">
      <span className="statrow-k">{k}</span>
      <span className="statrow-v">{children}</span>
    </div>
  );
}

/* ══════════════════════════════════════════════════════════════════════
   VARIATION A — DOSSIÊ DE CAMPO  (HUD-native, landscape)
   ════════════════════════════════════════════════════════════════════ */
function ProfileDossier({ p = PLAYER }) {
  const wr = winrate(p.record);
  return (
    <div className="modal modal-dossier panel">
      <div className="md-titlebar">
        <span className="md-title mono-label">Perfil do Jogador</span>
        <button className="md-close" aria-label="Fechar">
          <svg width="13" height="13" viewBox="0 0 16 16"><path d="M3 3l10 10M13 3L3 13" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>
        </button>
      </div>

      <div className="md-body">
        {/* Left identity column */}
        <div className="md-id">
          <div className="avatar-frame av-lg">
            <image-slot id="dossier-avatar" shape="circle" placeholder="foto"></image-slot>
            <span className="level-badge">LV {p.level}</span>
          </div>
          <div className="md-nick">{p.nick}</div>
          <div className="md-guildchip">
            <GuildCrest color={p.guild.color} size={15} />
            <span className="gc-name">{p.guild.name}</span>
          </div>
          <div className="md-role mono-label">{p.guild.role}</div>
        </div>

        {/* Right detail column */}
        <div className="md-detail">
          <div className="md-ranks">
            <div className="md-rank-main">
              <RankShield tier={p.current.tier} div={p.current.div} size={78} />
              <div className="md-rank-text">
                <span className="rk-label mono-label">Rank Atual</span>
                <span className="rk-tier">{p.current.tier} {p.current.div}</span>
                <span className="rk-pts">{p.current.pts} PTS</span>
              </div>
            </div>
            <div className="md-rank-peak">
              <PeakSeal tier={p.peak.tier} div={p.peak.div} size={42} />
              <div className="md-peak-text">
                <span className="pk-label mono-label">Maior Rank</span>
                <span className="pk-tier">{p.peak.tier} {p.peak.div}</span>
                <span className="pk-season">{p.peak.season}</span>
              </div>
            </div>
          </div>

          <div className="md-stats panel-inset">
            <div className="ms-block">
              <span className="ms-k mono-label">Vitórias / Derrotas</span>
              <WinBar record={p.record} />
            </div>
            <div className="ms-grid">
              <StatRow k="Membro desde">{p.since}</StatRow>
              <StatRow k="Aproveit.">{wr}%</StatRow>
            </div>
          </div>
        </div>

        {/* Favorite card */}
        <div className="md-fav">
          <span className="md-fav-label mono-label">Carta Preferida</span>
          <FavCard fav={p.fav} tilt={-5} w={104} />
          <span className="md-fav-name">{p.fav.name}</span>
        </div>
      </div>
    </div>
  );
}

/* ══════════════════════════════════════════════════════════════════════
   VARIATION B — SELO DA GUILDA  (ceremonial fantasy, portrait)
   ════════════════════════════════════════════════════════════════════ */
function ProfileSeal({ p = PLAYER }) {
  const wr = winrate(p.record);
  return (
    <div className="modal modal-seal">
      <div className="filigree"></div>
      <button className="ms-close" aria-label="Fechar">
        <svg width="13" height="13" viewBox="0 0 16 16"><path d="M3 3l10 10M13 3L3 13" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/></svg>
      </button>

      <div className="sl-head">
        <span className="sl-eyebrow">✦ &nbsp;Perfil do Jogador&nbsp; ✦</span>
        <h2 className="sl-nick">{p.nick}</h2>
        <div className="sl-guild">
          <GuildCrest color={p.guild.color} size={18} />
          <span>{p.guild.name}</span>
          <em className="sl-role">· {p.guild.role}</em>
        </div>
      </div>

      <div className="sl-medallion">
        <div className="medal-ring">
          <div className="avatar-frame av-round">
            <image-slot id="seal-avatar" shape="circle" placeholder="foto"></image-slot>
          </div>
          <span className="medal-level">LV {p.level}</span>
        </div>
      </div>

      <div className="sl-rank">
        <RankShield tier={p.current.tier} div={p.current.div} size={92} />
        <div className="sl-rank-name">{p.current.tier} {p.current.div}</div>
        <div className="sl-rank-sub">{p.current.pts} pontos de classificação</div>
        <div className="sl-peak">
          <PeakSeal tier={p.peak.tier} div={p.peak.div} size={34} />
          <span className="sl-peak-txt">Auge: <b>{p.peak.tier} {p.peak.div}</b> · {p.peak.season}</span>
        </div>
      </div>

      <div className="sl-rule"><span>⟡</span></div>

      <div className="sl-stats">
        <div className="sl-wins">
          <div className="sl-wins-row">
            <span className="sw-num sw-w">{p.record.w}</span>
            <span className="sw-cap">Vitórias</span>
            <span className="sw-rate">{wr}%</span>
            <span className="sw-cap">Derrotas</span>
            <span className="sw-num sw-l">{p.record.l}</span>
          </div>
          <WinBar record={p.record} label={false} />
        </div>
        <div className="sl-since">Membro desde <b>{p.since}</b></div>
      </div>

      <div className="sl-fav">
        <div className="sl-fav-card">
          <FavCard fav={p.fav} tilt={0} w={92} />
        </div>
        <div className="sl-fav-info">
          <span className="sl-fav-label">Carta Preferida</span>
          <span className="sl-fav-name">{p.fav.name}</span>
          <span className="sl-fav-meta">{p.fav.element} · {p.fav.type} · {p.fav.rarity}</span>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  PLAYER, TIERS, winrate,
  RankShield, PeakSeal, GuildCrest, FavCard, WinBar, StatRow,
  ProfileDossier, ProfileSeal,
});
