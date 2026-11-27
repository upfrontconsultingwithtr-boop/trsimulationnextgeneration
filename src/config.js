// Global tuning + world constants. Everything gameplay-related lives here so designers can tweak in one place.
export const WORLD_SIZE = 64;            // tiles per side (1 tile = 1 metre)
export const WALL_HEIGHT = 2.7;
export const TICK_GAME_MINUTES_PER_SEC = 1; // solo: 1 real second = 1 game minute at 1x
export const ONLINE_MINUTES_PER_SEC = 2;    // online neighborhood clock
export const WALK_SPEED = 2.4;              // tiles per real second (scaled by sim speed)
export const SAVE_KEY = 'nextgen-life-save-v1';

// Needs decay per *game hour* (0..100 scale)
export const NEEDS = {
  hunger:  { label: 'Hunger',  icon: '🍔', decay: 5.5, color: '#ffb347' },
  energy:  { label: 'Energy',  icon: '⚡', decay: 4.2, color: '#7ad7ff' },
  hygiene: { label: 'Hygiene', icon: '🫧', decay: 3.6, color: '#8ef0d0' },
  bladder: { label: 'Bladder', icon: '🚻', decay: 9.0, color: '#c3a6ff' },
  fun:     { label: 'Fun',     icon: '🎉', decay: 6.0, color: '#ff8fc7' },
  social:  { label: 'Social',  icon: '💬', decay: 4.8, color: '#ffe066' },
};
export const NEED_KEYS = Object.keys(NEEDS);

export const SKILLS = {
  cooking:    { label: 'Cooking',    icon: '🍳' },
  fitness:    { label: 'Fitness',    icon: '💪' },
  creativity: { label: 'Creativity', icon: '🎨' },
  logic:      { label: 'Logic',      icon: '🧠' },
  charisma:   { label: 'Charisma',   icon: '✨' },
  music:      { label: 'Music',      icon: '🎸' },
};

// Traits shape autonomy and social outcomes.
export const TRAITS = {
  creative:  { label: 'Creative',  icon: '🎨', desc: 'Loves painting & music. Gets Inspired often.' },
  outgoing:  { label: 'Outgoing',  icon: '🥳', desc: 'Social need drops faster, socials land better.' },
  homebody:  { label: 'Homebody',  icon: '🏡', desc: 'Happier at home, comfort objects are extra cozy.' },
  foodie:    { label: 'Foodie',    icon: '🍜', desc: 'Cooks better and loves eating.' },
  athletic:  { label: 'Athletic',  icon: '🏃', desc: 'Gains fitness fast, workouts are fun.' },
  bookworm:  { label: 'Bookworm',  icon: '📚', desc: 'Reading is fun and builds logic.' },
  hothead:   { label: 'Hothead',   icon: '🔥', desc: 'Quick to anger, intense vibes.' },
  romantic:  { label: 'Romantic',  icon: '💘', desc: 'Flirts land better, craves romance.' },
  gamer:     { label: 'Gamer',     icon: '🎮', desc: 'Gaming is extra fun and builds logic.' },
  neat:      { label: 'Neat',      icon: '🧼', desc: 'Hygiene matters more. Hates mess.' },
  chill:     { label: 'Chill',     icon: '😌', desc: 'Bad vibes fade fast.' },
  ambitious: { label: 'Ambitious', icon: '🚀', desc: 'Earns more from gigs, loves goals.' },
};

// "Vibes" = emotional states. Original system: vibes radiate to nearby sims (emotional contagion).
export const VIBES = {
  neutral:  { label: 'Neutral',  emoji: '🙂', color: '#d9d9e3' },
  happy:    { label: 'Happy',    emoji: '😄', color: '#ffd84d' },
  inspired: { label: 'Inspired', emoji: '🤩', color: '#7cc8ff' },
  flirty:   { label: 'Flirty',   emoji: '😍', color: '#ff7eb6' },
  energized:{ label: 'Energized',emoji: '⚡', color: '#b4ff6b' },
  focused:  { label: 'Focused',  emoji: '🧐', color: '#9aa8ff' },
  cozy:     { label: 'Cozy',     emoji: '🥰', color: '#ffb38a' },
  sad:      { label: 'Sad',      emoji: '😢', color: '#6f8bbd' },
  angry:    { label: 'Angry',    emoji: '😡', color: '#ff5a4f' },
  tense:    { label: 'Tense',    emoji: '😬', color: '#c98bff' },
  bored:    { label: 'Bored',    emoji: '🥱', color: '#9b9b9b' },
};

export const STARTING_MONEY = 12000;
