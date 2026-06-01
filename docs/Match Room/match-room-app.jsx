const { useState, useEffect, useRef } = React;

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

// ── Toast ──────────────────────────────────────────────────────────────────
function Toast({ msg, onDone }) {
  useEffect(() => { const t = setTimeout(onDone, 2400); return () => clearTimeout(t); }, []);
  return <div className="toast">{msg}</div>;
}

// ── Player podium (circle + banners) ─────────────────────────────────────────
function PlayerSlot({ player, side, isYou }) {
  const present = !!player;
  const ready = present && player.ready;
  const circleCls = `circle ${!present ? 'empty' : ready ? 'ready' : 'waiting'}`;

  return (
    <div className={`player-slot ${side}`}>
      {/* status above the circle */}
      <div className="status-banner">
        {ready
          ? <div className="ready-badge"><span className="tick"></span>Pronto</div>
          : present
            ? <div className="waiting-badge dots">aguardando</div>
            : <div className="waiting-badge">vazio</div>}
      </div>

      {/* the ground circle */}
      <div className="circle-stage">
        <div className="circle-shadow"></div>
        <div className={circleCls}>
          <span className="rune-ring"></span>
          <span className="rune-ring fast"></span>
          {present ? (
            <div className="occupant">
              <div className="avatar">{player.initial}</div>
              {player.host && <div className="occupant-host">⌂ Anfitrião</div>}
            </div>
          ) : (
            <div className="empty-mark">
              <span className="empty-glyph">?</span>
              <span className="empty-text">à espera</span>
            </div>
          )}
        </div>
      </div>

      {/* name plate below */}
      <div className="name-plate">
        {present ? (
          <>
            <div className="player-name">{player.name}</div>
            <div className="player-deck">{player.deck}</div>
            {isYou && <div className="you-tag">Você</div>}
          </>
        ) : (
          <div className="player-name empty">Aguardando oponente…</div>
        )}
      </div>
    </div>
  );
}

// ── Main App ─────────────────────────────────────────────────────────────────
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "opponentPresent": true,
  "opponentReady": false,
  "bgIntensity": 60
}/*EDITMODE-END*/;

const YOU = { name: 'Aldric, o Bravo', initial: 'A', deck: 'Inferno Ardente', host: true };
const OPP = { name: 'Vesper Noctil', initial: 'V', deck: 'Marés Profundas', host: false };

function App() {
  const [youReady, setYouReady] = useState(false);
  const [toast, setToast] = useState(null);
  const [countdown, setCountdown] = useState(null);
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);

  const oppPresent = tweaks.opponentPresent;
  const oppReady = oppPresent && tweaks.opponentReady;

  useEffect(() => { spawnParticles(); }, []);

  const showToast = (msg) => setToast({ msg, id: Date.now() });

  // build player objects
  const you = { ...YOU, ready: youReady };
  const opp = oppPresent ? { ...OPP, ready: oppReady } : null;

  const bothReady = youReady && oppReady;

  // countdown when both ready
  useEffect(() => {
    if (bothReady) {
      setCountdown(3);
      const iv = setInterval(() => {
        setCountdown(c => {
          if (c <= 1) { clearInterval(iv); return null; }
          return c - 1;
        });
      }, 1000);
      return () => clearInterval(iv);
    } else {
      setCountdown(null);
    }
  }, [bothReady]);

  const toggleReady = () => {
    setYouReady(r => {
      const next = !r;
      showToast(next ? '✦ Você está pronto' : '✦ Aguardando — pronto cancelado');
      return next;
    });
  };

  const leave = () => {
    showToast('✦ Saindo da sala…');
    // em produção: get_tree().change_scene_to_file -> RoomLobby
  };

  return (
    <>
      <style>{`#bg-canvas { opacity: ${tweaks.bgIntensity / 100}; }`}</style>

      <div className="shell">
        {/* top bar */}
        <div className="topbar">
          <div className="room-head">
            <span className="room-title">Salão dos Bravos</span>
            <span className="room-meta">
              <span className="room-chip">Clássico</span>
              <span>Sala #1042</span>
            </span>
          </div>
          <div className="topbar-right">
            <div className="net-status"><span className="net-dot"></span>Rede Local · sincronizado</div>
          </div>
        </div>

        {/* arena */}
        <div className="arena">
          <div className="stage-floor"></div>
          <div className="matchup">
            <PlayerSlot player={you} side="left" isYou={true} />
            <div className="vs-wrap">
              <div className="vs-line"></div>
              <div className="vs">
                <span className="lozenge"></span>
                <span className="lozenge inner"></span>
                <span className="vs-text">VS</span>
              </div>
              <div className="vs-line bottom"></div>
            </div>
            <PlayerSlot player={opp} side="right" isYou={false} />
          </div>
        </div>

        {/* footer actions */}
        <div className="footer">
          <div className="footer-wrap">
            <div className="footer-status">
              {bothReady
                ? <><span className="net-dot"></span>Ambos prontos — iniciando…</>
                : oppPresent
                  ? (youReady ? 'Aguardando o oponente confirmar…' : 'Confirme quando estiver pronto')
                  : 'Aguardando um oponente entrar na sala…'}
            </div>
            <button className="btn btn-leave" onClick={leave}>
              <span className="btn-shimmer"></span>⬅ Sair da Sala
            </button>
            <button className={`btn btn-ready${youReady ? ' is-ready' : ''}`} onClick={toggleReady}>
              <span className="btn-shimmer"></span>
              {youReady ? '✓ Pronto — Cancelar' : '⚔ Pronto'}
            </button>
          </div>
        </div>
      </div>

      {/* countdown overlay when both ready */}
      {countdown !== null && (
        <div className="countdown">
          <div className="countdown-label">A batalha começa em</div>
          <div className="countdown-num" key={countdown}>{countdown}</div>
        </div>
      )}

      {toast && <Toast key={toast.id} msg={toast.msg} onDone={() => setToast(null)} />}

      <TweaksPanel>
        <TweakSection label="Simulação">
          <TweakToggle label="Oponente na sala" value={tweaks.opponentPresent}
            onChange={v => setTweak('opponentPresent', v)} />
          <TweakToggle label="Oponente pronto" value={tweaks.opponentReady}
            onChange={v => setTweak('opponentReady', v)} />
        </TweakSection>
        <TweakSection label="Aparência">
          <TweakSlider label="Intensidade do Fundo" value={tweaks.bgIntensity} min={20} max={100} step={5}
            onChange={v => setTweak('bgIntensity', v)} />
        </TweakSection>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
