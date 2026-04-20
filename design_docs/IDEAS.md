# Snake Gym - Freemium Design Ideas

**Date:** 2025-12-01
**Status:** Draft / Brainstorming

---

## Overview

Transform the Snake Pit into a training-focused "Snake Gym" with TWEANN-based AI evolution and freemium monetization.

---

## 0. Event Icons (Quick Win)

Replace the verbose text event list with single expressive icons.

| Event | Current | Proposed Icon | Notes |
|-------|---------|---------------|-------|
| LEFT | `< LEFT` | `←` | Arrow |
| RIGHT | `> RIGHT` | `→` | Arrow |
| UP | `^ UP` | `↑` | Arrow |
| DOWN | `v DOWN` | `↓` | Arrow |
| FOOD | `+5` | `🍎` or 🟡 | Pacman-style eating |
| WIN | `WIN!` | `🎉` | Celebration |
| LOSE | - | `💀` | Ghost/skull |
| WALL | `WALL!` | `🧱` | Wall collision |
| SELF | `SELF!` | `🔄` | Self collision |
| SNAKE | `SNAKE!` | `💥` | Enemy collision |

**Implementation:** Show only the **last event** as a large icon above/beside each snake panel instead of a scrolling list. Consider a brief animation on state change.

---

## 1. Remove Character Sliders

**Rationale:** Snake personality should **emerge** from TWEANN training, not be manually configured.

**Current State:**
- Three sliders: Aggression, Greed, Caution (0-100 each, must total 150)
- Located in Den snake creation form

**Proposed Change:**
- Remove: `aggression`, `greed`, `caution` sliders from snake creation
- Keep: Snake name, colors, pattern selection
- New: Snakes start with random brain weights (untrained)
- Personality traits become **read-only metrics** derived from observed behavior

---

## 2. The Gym - TWEANN Training Arena

**Core Concept:** Players spend tokens to train their snakes against AI opponents or scenarios. Training updates the snake's neural network weights.

### UI Mockup

```
┌─────────────────────────────────────────────────────────────┐
│  🏋️ SNAKE GYM                                    🪙 450    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ 🎯 BASICS   │  │ ⚡ COMBAT   │  │ 🧠 ADVANCED │         │
│  │             │  │             │  │             │         │
│  │ Food Chase  │  │ 1v1 Bot     │  │ Survival    │         │
│  │ Wall Avoid  │  │ Aggression  │  │ Tournament  │         │
│  │ Self Aware  │  │ Defense     │  │ Evolution   │         │
│  │             │  │             │  │             │         │
│  │  🪙 5/run   │  │  🪙 15/run  │  │  🪙 50/run  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                             │
│  Selected Snake: "Slithers" (Win Rate: 67%)                │
│  Brain Generation: 3  |  Training Sessions: 12             │
│                                                             │
│  [START TRAINING]                                          │
└─────────────────────────────────────────────────────────────┘
```

### Training Types

| Tier | Training | Cost | Effect |
|------|----------|------|--------|
| Basic | Food Chase | 🪙 5 | Learn to find food efficiently |
| Basic | Wall Avoid | 🪙 5 | Learn to avoid walls |
| Basic | Self Aware | 🪙 5 | Learn to not hit own tail |
| Combat | 1v1 Bot | 🪙 15 | Practice against AI opponent |
| Combat | Aggression | 🪙 15 | Learn offensive moves |
| Combat | Defense | 🪙 15 | Learn evasive maneuvers |
| Advanced | Survival | 🪙 50 | Long-game optimization |
| Advanced | Tournament | 🪙 50 | Multi-round learning |
| Advanced | Evolution | 🪙 100 | Breed best traits from multiple snakes |

### TWEANN Integration

- Use existing `brain_weights` binary field in Snake schema
- Training sessions update weights based on fitness function
- Fitness metrics: survival time, food eaten, kills, efficiency
- Consider: https://github.com/macula-io/tweann (Elixir TWEANN library)

---

## 3. Freemium Economy

### Currency: 🪙 Coins

**Earning Coins (Free-to-Play):**

| Source | Amount | Frequency |
|--------|--------|-----------|
| Daily Login | 🪙 25 | Once per day |
| Win Match | 🪙 10 | Per victory |
| Lose Match | 🪙 2 | Per loss (participation reward) |
| Complete Training | 🪙 5 | Per gym session |
| Achievement | 🪙 50-500 | One-time unlocks |
| Watch Ad | 🪙 15 | Limited per day |
| **Purchase** | 🪙 100-10,000 | Real money |

**Spending Coins:**

| Item | Cost | Description |
|------|------|-------------|
| Gym Training (Basic) | 🪙 5 | Train snake brain |
| Gym Training (Combat) | 🪙 15 | Advanced training |
| Gym Training (Advanced) | 🪙 50-100 | Elite training |
| New Snake Slot | 🪙 500 | Expand from 5 → 6 snakes |
| Premium Colors | 🪙 200 | Exclusive snake skins |
| Name Change | 🪙 50 | Rename a snake |
| Brain Reset | 🪙 100 | Start training over |
| Tournament Entry | 🪙 250 | Compete for prizes |

---

## 4. Premium Features (Subscription)

### "Snake Pit VIP" - $4.99/month

| Benefit | Description |
|---------|-------------|
| 🪙 Daily Bonus | 50 coins/day (2x normal) |
| 🏋️ Gym Discount | 50% off all training |
| 🐍 Extra Slots | 10 snakes (vs 5 free) |
| ⚡ Fast Training | 2x training speed |
| 🎨 Exclusive Skins | VIP-only patterns |
| 📊 Analytics | Detailed brain stats & heatmaps |
| 🏆 Ranked Queue | Skill-based matchmaking |
| 🚫 Ad-Free | No ads ever |

---

## 5. Monetization Mechanisms

### a) Coin Packs (One-time IAP)

```
Starter Pack:    $0.99  →  🪙 150
Snake Charmer:   $4.99  →  🪙 800 + 1 exclusive skin
Pit Boss:        $9.99  →  🪙 2,000 + 3 exclusive skins
Serpent King:    $24.99 →  🪙 6,000 + all skins + 1 extra slot
```

### b) Battle Pass (Seasonal)

- **Cost:** $9.99 per season (8 weeks)
- **Free Track:** Basic rewards (coins, common skins)
- **Premium Track:** Exclusive skins, bonus coins, unique snake patterns, profile badges

### c) Tournament Entry Fees

- **Weekly Tournaments:** 🪙 100 entry, prize pool split among top 3
- **Monthly Championships:** 🪙 500 entry, real prizes or large coin pools
- **Spectator Mode:** Free, with optional tipping

### d) Cosmetic Shop (Rotating)

- Snake skins: 🪙 100-500
- Arena themes: 🪙 200
- Victory animations: 🪙 150
- Name colors/effects: 🪙 75
- Trail effects: 🪙 300

---

## 6. Engagement Loops

### Daily Loop
```
Login → Collect daily coins → Quick match → Check leaderboard → Logout
```

### Training Loop
```
Den → Select snake → Gym → Choose training → Watch/skip progress → Review stats → Return to Den
```

### Progression Loop
```
Earn coins → Train snake → Enter tournament → Win prizes → Unlock cosmetics → Show off
```

### Social Loop
```
Challenge friend → Watch replay → Share result → Earn referral bonus
```

### Collection Loop
```
Unlock skin → Equip on snake → Show in matches → Inspire others → They buy too
```

---

## 7. Implementation Phases

| Phase | Feature | Effort | Priority |
|-------|---------|--------|----------|
| **1** | Event icons (replace list) | Small | High |
| **1** | Remove personality sliders | Small | High |
| **2** | Gym UI with training modes | Medium | High |
| **2** | TWEANN training backend | Large | High |
| **3** | Daily login rewards | Small | Medium |
| **3** | Coin earn/spend tracking | Medium | Medium |
| **4** | Premium subscription | Medium | Medium |
| **4** | Cosmetic shop | Medium | Medium |
| **5** | Battle pass system | Large | Low |
| **5** | Tournament system | Large | Low |

---

## 8. Technical Considerations

### Database Changes Needed

```elixir
# New fields for Snake schema
field :brain_generation, :integer, default: 0
field :training_sessions_count, :integer, default: 0
field :last_trained_at, :utc_datetime

# New fields for Player schema
field :vip_until, :utc_datetime  # nil = not VIP
field :last_daily_claim, :date
field :total_spent_cents, :integer, default: 0

# New table: purchases
create table(:purchases) do
  belongs_to :player
  field :product_id, :string
  field :amount_cents, :integer
  field :coins_granted, :integer
  field :provider, :string  # "stripe", "apple", "google"
  field :provider_id, :string
  timestamps()
end

# New table: training_sessions (already referenced in schema)
create table(:training_sessions) do
  belongs_to :snake
  field :training_type, :string
  field :cost, :integer
  field :fitness_before, :float
  field :fitness_after, :float
  field :duration_seconds, :integer
  timestamps()
end
```

### Payment Integration

- **Primary:** Stripe (web)
- **Future:** Apple/Google IAP (mobile)
- **Webhook handling** for subscription status

### TWEANN Library

- Consider existing Elixir implementations or port from Erlang
- Key functions needed:
  - `create_network/1` - Initialize random weights
  - `mutate/2` - Apply mutations based on fitness
  - `crossover/2` - Breed two snakes
  - `evaluate/2` - Run fitness evaluation
  - `serialize/1` / `deserialize/1` - Convert to/from binary

---

## 9. Open Questions

1. **TWEANN Library:** Use existing or build custom?
2. **Payment Provider:** Stripe only, or also crypto?
3. **Target Platforms:** Web-only initially, or plan for mobile?
4. **AI Training:** Real-time during match, or offline background processing?
5. **Replay System:** Store match replays for training data?
6. **Anti-Cheat:** How to prevent weight manipulation?

---

## 10. References

- Current codebase exploration (2025-12-01)
- TWEANN: Topology and Weight Evolving Artificial Neural Networks
- Freemium game design patterns (Clash Royale, Brawl Stars)
- Macula ecosystem: https://github.com/macula-io/tweann

---

*Last updated: 2025-12-01*
