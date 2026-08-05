-- Exp Share: an OPTIONS row that turns party-wide experience on in
-- four flavors.  GEN 1 mirrors the Exp. All key item -- the fighters
-- split half of the exp (and stat exp), and the whole party splits the
-- other half, re-divided by the party count (the participant-division
-- bug included, engine/battle/experience.asm).  GEN 5+ mirrors the
-- modern Exp. Share -- the fighters keep the full amount split between
-- them, and every alive bench mon gets half a fighter's share.
-- BALANCED is the GEN 5+ split with a level gate: a bench mon only
-- gains exp while it is below the active fighter's level, so the bench
-- trails the party instead of racing ahead of it.  AVERAGE is the same
-- gate measured against the party's average level instead.
-- Shared recipients get ONE "EXP is shared amongst the party" line
-- instead of a per-mon "X gained N EXP. Points!" message.

local ORDER = { "off", "gen1", "gen5", "balanced", "average" }
local ORDER_INDEX = {}
for i, mode in ipairs(ORDER) do ORDER_INDEX[mode] = i end
local LABELS = { off = "OFF", gen1 = "GEN 1", gen5 = "GEN 5+",
                 balanced = "BALANCED", average = "AVERAGE" }
local SHARE_TEXT = "EXP is shared\namongst the party!"

local api = {}

-- normalized mode: nil / garbage -> "off"
function api.modeOf(game)
  local options = game and game.save and game.save.options
  local mode = options and options.expShare
  if mode == "gen1" or mode == "gen5" or mode == "balanced"
      or mode == "average" then
    return mode
  end
  return "off"
end

-- the row's step body: LEFT/RIGHT cycle OFF -> GEN 1 -> GEN 5+ ->
-- BALANCED -> AVERAGE -> OFF.  Returns nil when there is no save (the
-- launcher's stub games), so the row stays inert there like every other
-- options row.
function api.cycle(game, dir)
  local options = game and game.save and game.save.options
  if not options then return nil end
  -- modeOf normalizes, so the ladder position is a direct lookup; the
  -- modulo is the same wrap the engine's own ladder rows use
  local i = ORDER_INDEX[api.modeOf(game)]
  local nextMode = ORDER[((i - 1 + (dir or 1)) % #ORDER) + 1]
  options.expShare = nextMode
  if game.writeOptions then game:writeOptions() end
  return nextMode
end

function api.labelOf(game)
  return LABELS[api.modeOf(game)]
end

-- GEN 1 (Exp. All): participants split half the exp; the whole party
-- splits the other half, with the halved-and-participant-divided base
-- divided again by the party count -- the vanilla
-- DivideExpDataByNumMonsGainingExp behavior with the EXP.ALL item held.
-- applyShare(mon, split, announce): split is the number of shares the
-- mon's base exp/stat exp is divided by; announce true prints the
-- individual gain line, nil stays silent (the share line covers it).
-- The share line announces the party pass before any of its silent
-- level-up messages queue.
function api.awardGen1(ctx)
  local battle = ctx.battle
  local party = battle.game.save.party
  local p = math.max(1, ctx.participants)
  for _, mon in ipairs(ctx.alive) do
    ctx.applyShare(mon, p * 2, true)
  end
  if #party > 1 then battle:sayNext(SHARE_TEXT) end
  for _, mon in ipairs(party) do
    if mon.hp > 0 then
      ctx.applyShare(mon, p * #party * 2, nil)
    end
  end
end

-- the shared GEN 5+ split: fighters keep the full exp split between
-- them; every alive bench mon that passes `gate` gets half a fighter's
-- share.  The bench gains are silent -- one share line replaces the
-- per-mon messages, and it lands after the fighters' own gains but
-- before the bench level-ups.
local function awardModern(ctx, gate)
  local battle = ctx.battle
  local party = battle.game.save.party
  local p = math.max(1, ctx.participants)
  local fought = {}
  for _, mon in ipairs(ctx.alive) do fought[mon] = true end
  local bench = {}
  for _, mon in ipairs(party) do
    if mon.hp > 0 and not fought[mon] and (not gate or gate(mon)) then
      bench[#bench + 1] = mon
    end
  end
  for _, mon in ipairs(ctx.alive) do
    ctx.applyShare(mon, p, true)
  end
  if #bench > 0 then battle:sayNext(SHARE_TEXT) end
  for _, mon in ipairs(bench) do
    ctx.applyShare(mon, p * 2, nil)
  end
end

-- GEN 5+: no gate -- every alive bench mon gets the half share.
function api.awardGen5(ctx)
  return awardModern(ctx, nil)
end

-- BALANCED: the GEN 5+ split with the level gate -- a bench mon only
-- gains exp while it is below the active fighter's level.  A bench mon
-- at or above the mon you are using gets nothing until the fighter
-- levels past it, so the bench trails the party instead of out-leveling
-- the mons that actually fight.
function api.awardBalanced(ctx)
  local battle = ctx.battle
  local active = battle.player and battle.player.mon
  local capLevel = active and active.level or 100
  return awardModern(ctx, function(mon)
    return mon.level < capLevel
  end)
end

-- AVERAGE: the GEN 5+ split with the gate set to the party's average
-- level -- a bench mon only gains exp while it is below that average
-- (whole party, fainted included), so the bench trails the party's
-- middle instead of the lead fighter.
function api.awardAverage(ctx)
  local battle = ctx.battle
  local party = battle.game.save.party
  local total = 0
  for _, mon in ipairs(party) do
    total = total + (mon.level or 1)
  end
  local capLevel = #party > 0 and math.floor(total / #party) or 100
  return awardModern(ctx, function(mon)
    return mon.level < capLevel
  end)
end

return function(mod)
  -- the OPTIONS row; next() first keeps every other mod's rows
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    out[#out + 1] = {
      id = "exp_share",
      label = "EXP SHARE",
      value = function(g) return api.labelOf(g) end,
      step = function(g, dir)
        return api.cycle(g, dir) ~= nil
      end,
    }
    return out
  end)

  -- battle.exp_award: OFF defers to the vanilla participant/EXP.ALL
  -- split; GEN 1, GEN 5+, BALANCED and AVERAGE replace it.  ctx is the
  -- engine's { battle, participants, alive, applyShare }.
  mod.hooks:wrap("battle.exp_award", function(nextFn, ctx)
    local mode = api.modeOf(ctx.battle and ctx.battle.game)
    if mode == "gen1" then return api.awardGen1(ctx) end
    if mode == "gen5" then return api.awardGen5(ctx) end
    if mode == "balanced" then return api.awardBalanced(ctx) end
    if mode == "average" then return api.awardAverage(ctx) end
    return nextFn(ctx)
  end)

  mod.exports.modeOf = api.modeOf
  mod.exports.cycle = api.cycle
  mod.exports.labelOf = api.labelOf
  mod.exports.awardGen1 = api.awardGen1
  mod.exports.awardGen5 = api.awardGen5
  mod.exports.awardBalanced = api.awardBalanced
  mod.exports.awardAverage = api.awardAverage
end
