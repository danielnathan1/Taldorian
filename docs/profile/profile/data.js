/* Shared player profile data + rank system + frame presets.
   Attached to window so the Babel component files can read them. */
(function () {
  // ── Rank ladder ───────────────────────────────────────────────
  // Tier order low→high. Divisions count down IV → I (I is highest).
  const RANKS = {
    Bronze:   { c1: '#d39a6a', c2: '#a96a3c', deep: '#5e3a1f', ink: '#2a1709' },
    Prata:    { c1: '#dfe6ef', c2: '#a7b3c4', deep: '#5a6679', ink: '#1d2430' },
    Ouro:     { c1: '#f5cf6a', c2: '#d39a2c', deep: '#7a5410', ink: '#2a1d04' },
    Platina:  { c1: '#9fe6dc', c2: '#52b3a6', deep: '#1f5a52', ink: '#062421' },
    Diamante: { c1: '#a9defc', c2: '#5aa8e0', deep: '#1c5a86', ink: '#04202f' },
    Mestre:   { c1: '#d3b8ff', c2: '#9a72e0', deep: '#4a2f86', ink: '#1a0e33' },
  };

  const PLAYER = {
    nick: 'Sagashii',
    level: 24,
    title: 'Caçador de Relíquias',
    currentRank: { tier: 'Prata', div: 'II', lp: 64, lpMax: 100 },
    maxRank: { tier: 'Ouro', div: 'IV' },
    guild: { name: 'Ordem do Crepúsculo', tag: 'ORD', role: 'Tenente' },
    wins: 318,
    losses: 142,
    memberSince: 'Mar 2024',
    favCard: {
      title: 'Golpe Bruto',
      type: 'Ação',
      element: 'fogo',
      rarity: 'C',
      atk: 3,
      def: 0,
      art: 'assets/golpe_bruto.png',
    },
  };

  PLAYER.totalGames = PLAYER.wins + PLAYER.losses;
  PLAYER.winrate = Math.round((PLAYER.wins / PLAYER.totalGames) * 100);

  // Avatar frame presets (mirrors the World HUD vocabulary).
  const FRAMES = {
    iron:     { a: '#4a515f', b: '#8b92a0', glow: 'rgba(135,206,228,0)',   accent: '#87cee4' },
    ouro:     { a: '#8a6a1e', b: '#f0c95f', glow: 'rgba(240,201,95,.55)',  accent: '#f0c95f' },
    azure:    { a: '#3a6e80', b: '#87cee4', glow: 'rgba(135,206,228,.55)', accent: '#87cee4' },
    carmesim: { a: '#7a2f2a', b: '#e0795f', glow: 'rgba(224,121,95,.5)',   accent: '#e0795f' },
    esmeralda:{ a: '#2f6a45', b: '#8fd99a', glow: 'rgba(143,217,154,.5)',  accent: '#8fd99a' },
  };

  const ELEMENTS = {
    fogo:   { glyph: '🔥', fg: '#d94d2a', bg: '#f6a55a' },
    agua:   { glyph: '💧', fg: '#2a6db8', bg: '#7ab2e0' },
    terra:  { glyph: '⛰', fg: '#7a5230', bg: '#c79b6b' },
    ar:     { glyph: '💨', fg: '#7a8a98', bg: '#cdd6dd' },
    raio:   { glyph: '⚡', fg: '#a07a16', bg: '#f5d469' },
    sombra: { glyph: '🌙', fg: '#2b2440', bg: '#6e5e8a' },
  };

  // Heraldic shield path on a 0..100 viewBox.
  const SHIELD_PATH =
    'M50 6 L88 22 V52 C88 76 71 88 50 96 C29 88 12 76 12 52 V22 Z';

  Object.assign(window, { RANKS, PLAYER, FRAMES, ELEMENTS, SHIELD_PATH });
})();
