// ──────────────────────────────────────────────────────────────────────────
// Mock data — Heroes & Cards for the deck builder
// ──────────────────────────────────────────────────────────────────────────

const HERO_CLASSES = ['BARBARIAN', 'MAGE', 'ARCHER', 'KNIGHT', 'ASSASSIN', 'HEALER', 'DRUID'];

const HEROES = [
  { id:'poppy',   name:'Poppy',   heroClass:'BARBARIAN', hp:20, attack:2, defense:1,
    passive:'Ataque descuidado: +1 ⚔ enquanto não aumentar 🛡.',
    skillSymbols:['terra','terra','fogo'], skillDesc:'recebe +3 de ⚔' },
  { id:'grok',    name:'Grok',    heroClass:'MAGE',      hp:16, attack:1, defense:2,
    passive:'Canalização: cada símbolo acumulado dá +1 ⚔ no próximo ataque.',
    skillSymbols:['dark','dark','agua'], skillDesc:'drena 2 de vida' },
  { id:'lira',    name:'Lira',    heroClass:'ARCHER',    hp:18, attack:3, defense:1,
    passive:'Tiro preciso: dano dobrado em alvos sem 🛡.',
    skillSymbols:['ar','ar','fogo'], skillDesc:'2 ataques em alvos diferentes' },
  { id:'thane',   name:'Thane',   heroClass:'KNIGHT',    hp:24, attack:2, defense:3,
    passive:'Juramento: +1 🛡 ao final de cada turno.',
    skillSymbols:['terra','terra','terra'], skillDesc:'aplica taunt em si mesmo' },
  { id:'vesper',  name:'Vesper',  heroClass:'ASSASSIN',  hp:14, attack:4, defense:0,
    passive:'Lâmina envenenada: aplica 1 de veneno por ataque.',
    skillSymbols:['dark','ar'], skillDesc:'invisível por 1 turno' },
  { id:'mira',    name:'Mira',    heroClass:'HEALER',    hp:17, attack:1, defense:1,
    passive:'Luz: cura 1 de vida ao jogar cura.',
    skillSymbols:['agua','agua','ar'], skillDesc:'cura 4 de vida em aliado' },
  { id:'kael',    name:'Kael',    heroClass:'MAGE',      hp:15, attack:1, defense:2,
    passive:'Ignição: símbolos de fogo causam +1 de dano.',
    skillSymbols:['fogo','fogo','fogo'], skillDesc:'queima toda a fileira por 2' },
  { id:'orla',    name:'Orla',    heroClass:'DRUID',     hp:19, attack:2, defense:2,
    passive:'Comunhão: ganha 1 símbolo de terra/turno.',
    skillSymbols:['terra','agua','ar'], skillDesc:'convoca tropa 2/2' },
  { id:'brom',    name:'Brom',    heroClass:'BARBARIAN', hp:22, attack:3, defense:1,
    passive:'Fúria: quando atacado, contra-ataca por 1.',
    skillSymbols:['fogo','fogo'], skillDesc:'ataque em área (2)' },
  { id:'sira',    name:'Sira',    heroClass:'ASSASSIN',  hp:15, attack:3, defense:1,
    passive:'Sombras: primeiro ataque do turno custa -1.',
    skillSymbols:['dark','dark'], skillDesc:'rouba 1 carta do oponente' },
  { id:'doran',   name:'Doran',   heroClass:'KNIGHT',    hp:22, attack:2, defense:2,
    passive:'Escudeiro: protege aliados adjacentes (-1 dano).',
    skillSymbols:['terra','agua'], skillDesc:'concede +2 🛡 a um aliado' },
  { id:'fenra',   name:'Fenra',   heroClass:'ARCHER',    hp:17, attack:3, defense:1,
    passive:'Olho de águia: ignora 1 de 🛡 do alvo.',
    skillSymbols:['ar','ar','ar'], skillDesc:'flecha que atinge 3 vezes' },
  { id:'isen',    name:'Isen',    heroClass:'HEALER',    hp:18, attack:1, defense:2,
    passive:'Bênção: aliados começam com +1 🛡.',
    skillSymbols:['agua','agua'], skillDesc:'cura 3 em todos aliados' },
  { id:'rurik',   name:'Rurik',   heroClass:'DRUID',     hp:20, attack:2, defense:2,
    passive:'Raízes: inimigos perdem 1 movimento.',
    skillSymbols:['terra','terra','agua'], skillDesc:'enraíza alvo por 1 turno' },
];

const RARITIES = ['Comum', 'Incomum', 'Raro', 'Épico', 'Lendário'];
const ELEMENTS = ['fogo', 'terra', 'agua', 'ar', 'dark'];
const CARD_TYPES = ['Ação', 'Reação', 'Ação Bônus'];
// Placeholder — categorias reais de efeito serão definidas na implementação
const EFFECT_TAGS = ['Dano', 'Cura', 'Buff', 'Debuff', 'Controle', 'Recurso'];

// Helper to build a card
let _cardId = 0;
const C = (name, element, rarity, type, cost, atk, eff) => ({
  id: `c_${++_cardId}_${name.toLowerCase().replace(/\s+/g,'_')}`,
  name, element, rarity, type, cost, atk, effect: eff,
});

const CARDS = [
  C('Golpe Bruto',       'fogo',  'Comum',     'Ação',        1, 2, 'Causa 2 de dano.'),
  C('Lâmina Flamejante', 'fogo',  'Incomum',   'Ação',        2, 3, 'Causa 3 de dano e aplica queimar.'),
  C('Explosão Ígnea',    'fogo',  'Raro',      'Ação',        3, 4, 'Causa 4 de dano em área.'),
  C('Tempestade de Brasa','fogo', 'Épico',     'Ação',        4, 5, 'Causa 5 de dano e ignora 🛡.'),
  C('Phoenix Renascida', 'fogo',  'Lendário',  'Ação',        6, 7, 'Causa 7 de dano. Retorna se morrer.'),
  C('Refletir Chamas',   'fogo',  'Raro',      'Reação',      1, 0, 'Reflete dano de fogo recebido.'),
  C('Bofetão Selvagem',  'fogo',  'Comum',     'Ação Bônus',  0, 1, 'Causa 1 de dano sem usar turno.'),

  C('Punho de Pedra',    'terra', 'Comum',     'Ação',        1, 2, 'Causa 2 e ganha +1 🛡.'),
  C('Muralha Antiga',    'terra', 'Incomum',   'Reação',      1, 0, 'Ganha 3 🛡 até o próximo turno.'),
  C('Avalanche',         'terra', 'Raro',      'Ação',        3, 4, 'Causa 4 e atordoa o alvo.'),
  C('Coração da Montanha','terra','Épico',     'Reação',      2, 0, 'Imune a dano por 1 turno.'),
  C('Titã Ancestral',    'terra', 'Lendário',  'Ação',        5, 6, 'Convoca titã 6/6 por 1 turno.'),
  C('Postura Firme',     'terra', 'Comum',     'Ação Bônus',  0, 0, 'Ganha 2 🛡 imediatamente.'),

  C('Jato de Água',      'agua',  'Comum',     'Ação',        1, 2, 'Causa 2 e empurra o alvo.'),
  C('Cura Menor',        'agua',  'Comum',     'Ação Bônus',  1, 0, 'Cura 2 de vida.'),
  C('Maremoto',          'agua',  'Raro',      'Ação',        3, 3, 'Causa 3 em todos inimigos.'),
  C('Selo Glacial',      'agua',  'Épico',     'Reação',      2, 0, 'Congela ataque inimigo.'),
  C('Leviatã das Marés', 'agua',  'Lendário',  'Ação',        6, 7, 'Causa 7 e cura 3.'),
  C('Névoa Curativa',    'agua',  'Incomum',   'Ação Bônus',  1, 0, 'Cura 3 em aliado.'),

  C('Lâmina do Vento',   'ar',    'Comum',     'Ação',        1, 2, 'Causa 2 e ganha esquiva.'),
  C('Rajada Veloz',      'ar',    'Incomum',   'Ação Bônus',  1, 1, '+1 ataque neste turno.'),
  C('Ciclone',           'ar',    'Raro',      'Ação',        3, 3, 'Causa 3 e desarma o alvo.'),
  C('Passo do Vento',    'ar',    'Incomum',   'Reação',      1, 0, 'Esquiva do próximo ataque.'),
  C('Furacão',           'ar',    'Épico',     'Ação',        4, 5, 'Causa 5 e empurra todos.'),

  C('Toque Sombrio',     'dark',  'Comum',     'Ação',        1, 2, 'Causa 2 e dreno 1.'),
  C('Maldição',          'dark',  'Incomum',   'Ação Bônus',  1, 0, 'Alvo recebe +1 de dano.'),
  C('Sussurro Profundo', 'dark',  'Raro',      'Reação',      2, 0, 'Cancela carta do oponente.'),
  C('Devorar Almas',     'dark',  'Épico',     'Ação',        4, 4, 'Causa 4 e cura igual ao dano.'),
  C('Senhor das Sombras','dark',  'Lendário',  'Ação',        5, 6, 'Causa 6 e silencia por 2 turnos.'),
];

// ──────────────────────────────────────────────────────────────────────────
// Sleeves (verso das cartas) — todas derivam da mesma arte, tingidas por cor
//   (igual sleeves reais: mesma moldura, cores diferentes). 'taldor' = original.
// ──────────────────────────────────────────────────────────────────────────
const SLEEVE_ART = 'assets/card_back.png';
const SLEEVES = [
  { id:'taldor',   label:'Selo de Taldor',   tint:null,                  swatch:'oklch(0.73 0.13 78)'  },
  { id:'crimson',  label:'Brasão Carmesim',  tint:'oklch(0.45 0.20 18)', swatch:'oklch(0.50 0.20 18)'  },
  { id:'azure',    label:'Véu Arcano',       tint:'oklch(0.42 0.16 258)',swatch:'oklch(0.50 0.16 258)' },
  { id:'verdant',  label:'Folha Ancestral',  tint:'oklch(0.42 0.14 150)',swatch:'oklch(0.50 0.15 150)' },
  { id:'obsidian', label:'Sigilo Sombrio',   tint:'oklch(0.30 0.12 300)',swatch:'oklch(0.40 0.13 300)' },
];

// ──────────────────────────────────────────────────────────────────────────
// Playmats — espelham os do tabuleiro (board.html)
// ──────────────────────────────────────────────────────────────────────────
const PLAYMATS = [
  { id:'dark',     label:'Sombra Etérea',    bg:'linear-gradient(135deg,#050215 0%,#0e0928 30%,#190736 55%,#070d28 80%,#020110 100%)', thumb:'linear-gradient(135deg,#0e0928,#190736)' },
  { id:'oriental', label:'Jardim do Dragão', bg:'linear-gradient(135deg,#120802 0%,#391705 25%,#582908 42%,#284316 62%,#14280b 80%,#070d04 100%)', thumb:'linear-gradient(135deg,#391705,#284316)' },
  { id:'arcane',   label:'Câmara Arcana',    bg:'linear-gradient(135deg,#020318 0%,#060e2c 30%,#0b052e 55%,#040216 80%,#010208 100%)', thumb:'linear-gradient(135deg,#060e2c,#0b052e)' },
  { id:'crimson',  label:'Terra de Chamas',  bg:'linear-gradient(135deg,#160202 0%,#2c0505 28%,#160303 55%,#0a0101 80%,#040108 100%)', thumb:'linear-gradient(135deg,#2c0505,#160303)' },
  { id:'forest',   label:'Floresta Élfica',  bg:'linear-gradient(135deg,#010f07 0%,#031608 28%,#071c0c 55%,#031208 80%,#010703 100%)', thumb:'linear-gradient(135deg,#031608,#071c0c)' },
];

// ──────────────────────────────────────────────────────────────────────────
// Starter decks
// ──────────────────────────────────────────────────────────────────────────
const DEFAULT_DECKS = [
  {
    id: 'deck_fogo',
    name: 'Inferno Ardente',
    sleeve: 'crimson',
    playmat: 'crimson',
    heroes: ['poppy', 'brom', 'kael'],
    // Pre-populate ~30 cards (counts)
    cards: {
      [CARDS[0].id]: 4, [CARDS[1].id]: 3, [CARDS[2].id]: 2, [CARDS[3].id]: 2, [CARDS[5].id]: 2, [CARDS[6].id]: 3,
      [CARDS[7].id]: 3, [CARDS[8].id]: 2,
      [CARDS[13].id]: 2, [CARDS[14].id]: 2,
      [CARDS[20].id]: 2, [CARDS[24].id]: 1, [CARDS[25].id]: 2,
    },
  },
  {
    id: 'deck_aether',
    name: 'Marés Profundas',
    sleeve: 'azure',
    playmat: 'arcane',
    heroes: ['mira', 'isen'],
    cards: {
      [CARDS[13].id]: 4, [CARDS[14].id]: 4, [CARDS[15].id]: 3, [CARDS[16].id]: 2, [CARDS[17].id]: 1, [CARDS[18].id]: 3,
      [CARDS[7].id]: 2, [CARDS[11].id]: 1,
    },
  },
  {
    id: 'deck_terra',
    name: 'Vigília de Pedra',
    sleeve: 'verdant',
    playmat: 'forest',
    heroes: ['thane', 'doran', 'orla'],
    cards: {
      [CARDS[7].id]: 4, [CARDS[8].id]: 3, [CARDS[9].id]: 3, [CARDS[10].id]: 2, [CARDS[11].id]: 1, [CARDS[12].id]: 3,
      [CARDS[0].id]: 2, [CARDS[13].id]: 2, [CARDS[14].id]: 2,
    },
  },
  {
    id: 'deck_sombra',
    name: 'Sussurros nas Sombras',
    sleeve: 'obsidian',
    playmat: 'dark',
    heroes: ['vesper', 'sira'],
    cards: {
      [CARDS[24].id]: 4, [CARDS[25].id]: 3, [CARDS[26].id]: 2, [CARDS[27].id]: 2, [CARDS[28].id]: 1,
      [CARDS[19].id]: 3, [CARDS[20].id]: 2,
    },
  },
  {
    id: 'deck_new',
    name: 'Deck sem nome',
    sleeve: 'taldor',
    playmat: 'dark',
    heroes: [],
    cards: {},
  },
];

window.HERO_CLASSES = HERO_CLASSES;
window.HEROES = HEROES;
window.RARITIES = RARITIES;
window.ELEMENTS = ELEMENTS;
window.CARD_TYPES = CARD_TYPES;
window.EFFECT_TAGS = EFFECT_TAGS;
window.CARDS = CARDS;
window.SLEEVE_ART = SLEEVE_ART;
window.SLEEVES = SLEEVES;
window.PLAYMATS = PLAYMATS;
window.DEFAULT_DECKS = DEFAULT_DECKS;
