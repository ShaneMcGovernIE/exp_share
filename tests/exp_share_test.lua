-- Standalone: luajit mods/exp_share/tests/exp_share_test.lua
-- Loads the mod through the real headless loader and asserts the OPTIONS
-- row ladder, the GEN 1 / GEN 5+ exp splits, and the hook wiring.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Data = require("src.core.Data")
Data:load()

local run = T.sdk.loadMod("mods/exp_share", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
local ex = run.loader.exports.exp_share
T.neq(ex, nil, "exports reachable")

-- ------------------------------------------------ the OPTIONS row

local function findRow(game)
  local rows = Runtime.call("ui.options.rows", function(_, r) return r end,
    game, { { id = "text_speed" } })
  for _, row in ipairs(rows) do
    if row.id == "exp_share" then return row end
  end
  return nil
end

local written = 0
local game = {
  save = { options = {} },
  -- method-shaped like the real Game:writeOptions, so a dot-call regression
  -- (self == nil) fails the test instead of being silently swallowed
  writeOptions = function(self)
    assert(type(self) == "table" and self.save ~= nil,
           "writeOptions must be called with a colon")
    written = written + 1
  end,
}

local row = findRow(game)
T.neq(row, nil, "the EXP SHARE row joins the options menu")
T.eq(row.label, "EXP SHARE", "row label")
T.eq(row.value(game), "OFF", "defaults to OFF")
T.eq(row.step(game, 1), true, "stepping right works")
T.eq(game.save.options.expShare, "gen1", "OFF cycles to GEN 1")
T.eq(row.value(game), "GEN 1", "value follows the save")
T.eq(row.step(game, 1), true, "step again")
T.eq(game.save.options.expShare, "gen5", "GEN 1 cycles to GEN 5+")
T.eq(row.value(game), "GEN 5+", "GEN 5+ label")
T.eq(row.step(game, -1), true, "stepping left works")
T.eq(game.save.options.expShare, "gen1", "GEN 5+ left-cycles to GEN 1")
T.eq(row.step(game, 1), true, "step again")
T.eq(row.step(game, 1), true, "step again")
T.eq(game.save.options.expShare, "off", "GEN 5+ cycles back to OFF")
T.eq(written, 5, "each step persists via writeOptions")

game.save.options.expShare = "bogus"
T.eq(ex.modeOf(game), "off", "a garbage value normalizes to OFF")
T.eq(ex.cycle({}), nil, "no save -> nil (launcher is untouched)")
T.eq(ex.cycle({ save = {} }), nil, "no options table -> nil")

-- ------------------------------------------------ GEN 1 split (Exp. All)

do
  -- one ordered event log, so the share line's position among the
  -- applyShare calls is asserted too
  local log = {}
  local monA, monB = { hp = 10 }, { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen1" },
                      party = { monA, monB } } },
    sayNext = function(_, text) log[#log + 1] = { kind = "say", text = text } end,
  }
  local ctx = {
    battle = battle,
    participants = 1,
    alive = { monA },
    applyShare = function(mon, split, announce)
      log[#log + 1] = { kind = "share", mon = mon, split = split,
                        announce = announce }
    end,
  }
  ex.awardGen1(ctx)
  -- fighter pass: half the total, split among the fighters, announced
  T.eq(log[1].kind, "share", "gen1: the fighter gets the first share")
  T.eq(log[1].mon, monA, "gen1: the fighter gets the first share")
  T.eq(log[1].split, 2, "gen1: fighter split = participants(1) x 2")
  T.eq(log[1].announce, true, "gen1: the fighter's own gain is announced")
  -- the share line lands before the silent whole-party pass
  T.eq(log[2].kind, "say", "gen1: the share line is queued second")
  T.eq(log[2].text, "Exp is shared\namongst the party!",
    "gen1: the single shared-exp line")
  -- whole-party pass: the halved-and-fighter-divided base re-divided by
  -- the party count, silent (the share line covers it)
  T.eq(log[3].mon, monA, "gen1: the fighter is in the party pass too")
  T.eq(log[3].split, 4, "gen1: party split = participants(1) x party(2) x 2")
  T.eq(log[3].announce, nil, "gen1: party-pass gains are not announced per mon")
  T.eq(log[4].mon, monB, "gen1: the bench mon gets the same party pass")
  T.eq(log[4].split, 4, "gen1: the bench shares the same divisor")
  T.eq(#log, 4, "gen1: fighter share + share line + one share per party mon")
end

do
  -- two fighters, three-party mons: the divisors follow participants
  local log = {}
  local monA, monB, monC = { hp = 10 }, { hp = 10 }, { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen1" },
                      party = { monA, monB, monC } } },
    sayNext = function(_, text) log[#log + 1] = { kind = "say", text = text } end,
  }
  local ctx = {
    battle = battle,
    participants = 2,
    alive = { monA, monB },
    applyShare = function(mon, split, announce)
      log[#log + 1] = { kind = "share", mon = mon, split = split,
                        announce = announce }
    end,
  }
  ex.awardGen1(ctx)
  T.eq(log[1].split, 4, "gen1: fighter share halves with two participants")
  T.eq(log[2].split, 4, "gen1: second fighter same share")
  T.eq(log[3].kind, "say", "gen1: the share line follows the fighters")
  T.eq(log[4].split, 12, "gen1: party pass = participants(2) x party(3) x 2")
  T.eq(#log, 6, "gen1: two fighter shares + share line + three party shares")
end

do
  -- single-mon party: no share line, the mon gets the vanilla amount
  local log = {}
  local monA = { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen1" }, party = { monA } } },
    sayNext = function(_, text) log[#log + 1] = { kind = "say", text = text } end,
  }
  local ctx = {
    battle = battle,
    participants = 1,
    alive = { monA },
    applyShare = function(mon, split, announce)
      log[#log + 1] = { kind = "share", mon = mon, split = split,
                        announce = announce }
    end,
  }
  ex.awardGen1(ctx)
  T.eq(#log, 2, "gen1: solo mon gets both halves")
  T.eq(log[1].split, 2, "gen1: solo fighter half")
  T.eq(log[2].split, 2, "gen1: solo party pass = 1 x 1 x 2")
end

-- ------------------------------------------------ GEN 5+ split

do
  local log = {}
  local monA, monB = { hp = 10 }, { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen5" },
                      party = { monA, monB } } },
    sayNext = function(_, text) log[#log + 1] = { kind = "say", text = text } end,
  }
  local ctx = {
    battle = battle,
    participants = 1,
    alive = { monA },
    applyShare = function(mon, split, announce)
      log[#log + 1] = { kind = "share", mon = mon, split = split,
                        announce = announce }
    end,
  }
  ex.awardGen5(ctx)
  T.eq(log[1].mon, monA, "gen5: the fighter keeps the full amount")
  T.eq(log[1].split, 1, "gen5: fighter split = participants(1)")
  T.eq(log[1].announce, true, "gen5: the fighter's own gain is announced")
  -- the share line lands before the bench level-ups
  T.eq(log[2].kind, "say", "gen5: the share line follows the fighter")
  T.eq(log[2].text, "Exp is shared\namongst the party!",
    "gen5: the single shared-exp line")
  T.eq(log[3].mon, monB, "gen5: the bench mon is paid after the share line")
  T.eq(log[3].split, 2, "gen5: bench gets half a fighter's share")
  T.eq(log[3].announce, nil, "gen5: bench gains are not announced per mon")
  T.eq(#log, 3, "gen5: fighter share + share line + one bench share")
end

do
  -- two fighters, one bench: participants split the full amount
  local log = {}
  local monA, monB, monC = { hp = 10 }, { hp = 10 }, { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen5" },
                      party = { monA, monB, monC } } },
    sayNext = function(_, text) log[#log + 1] = { kind = "say", text = text } end,
  }
  local ctx = {
    battle = battle,
    participants = 2,
    alive = { monA, monB },
    applyShare = function(mon, split, announce)
      log[#log + 1] = { kind = "share", mon = mon, split = split,
                        announce = announce }
    end,
  }
  ex.awardGen5(ctx)
  T.eq(log[1].split, 2, "gen5: fighter share splits by participants")
  T.eq(log[2].split, 2, "gen5: second fighter same share")
  T.eq(log[3].kind, "say", "gen5: the share line follows both fighters")
  T.eq(log[4].split, 4, "gen5: bench = participants(2) x 2")
  T.eq(#log, 4, "gen5: two fighter shares + share line + one bench share")
end

do
  -- fainted bench mons are skipped; a full-participant party shows no
  -- share line at all
  local log = {}
  local monA, monB, dead = { hp = 10 }, { hp = 10 }, { hp = 0 }
  local battle = {
    game = { save = { options = { expShare = "gen5" },
                      party = { monA, monB, dead } } },
    sayNext = function(_, text) log[#log + 1] = { kind = "say", text = text } end,
  }
  local ctx = {
    battle = battle,
    participants = 2,
    alive = { monA, monB },
    applyShare = function(mon, split, announce)
      log[#log + 1] = { kind = "share", mon = mon, split = split,
                        announce = announce }
    end,
  }
  ex.awardGen5(ctx)
  T.eq(#log, 2, "gen5: fainted bench mon is skipped")
end

do
  -- solo party: vanilla amounts, no message
  local log = {}
  local monA = { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen5" }, party = { monA } } },
    sayNext = function(_, text) log[#log + 1] = { kind = "say", text = text } end,
  }
  local ctx = {
    battle = battle,
    participants = 1,
    alive = { monA },
    applyShare = function(mon, split, announce)
      log[#log + 1] = { kind = "share", mon = mon, split = split,
                        announce = announce }
    end,
  }
  ex.awardGen5(ctx)
  T.eq(log[1].split, 1, "gen5: solo mon keeps the full amount")
  T.eq(#log, 1, "gen5: no share line for a solo party")
end

-- ------------------------------------------------ hook wiring

do
  -- OFF defers to the vanilla split (nextFn runs untouched)
  local sawVanilla = false
  local offBattle = {
    game = { save = { options = { expShare = "off" }, party = {} } },
  }
  Runtime.call("battle.exp_award", function() sawVanilla = true end,
    { battle = offBattle })
  T.eq(sawVanilla, true, "OFF calls through to the vanilla split")
end

do
  -- GEN 5+ replaces the vanilla split without calling it
  local sawVanilla = false
  local calls = {}
  local monA, monB = { hp = 10 }, { hp = 10 }
  local gen5Battle = {
    game = { save = { options = { expShare = "gen5" },
                      party = { monA, monB } } },
    sayNext = function() end,
  }
  local ctx = {
    battle = gen5Battle,
    participants = 1,
    alive = { monA },
    applyShare = function(mon, split) calls[#calls + 1] = split end,
  }
  Runtime.call("battle.exp_award", function() sawVanilla = true end, ctx)
  T.eq(sawVanilla, false, "GEN 5+ replaces the vanilla split")
  T.eq(#calls, 2, "the mod's split ran instead")
end

-- ------------------------------------------------ real battle integration

do
  local SaveData = require("src.core.SaveData")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local save = SaveData.newGame()
  local monA = Pokemon.new(Data, "FIXMON_A", 10)
  local monB = Pokemon.new(Data, "FIXMON_A", 10)
  save.party = { monA, monB }
  save.options = { expShare = "gen5" }
  local stack = { states = {} }
  function stack:push(state) self.states[#self.states + 1] = state end
  function stack:pop() return table.remove(self.states) end
  function stack:top() return self.states[#self.states] end
  local game = { data = Data, save = save, stack = stack,
                 input = { wasPressed = function() return true end } }
  local battle = BattleState.newWild(game, "FIXMON_B", 5)
  battle.participants = { [battle.player.mon] = true }
  local expBefore = monA.exp + monB.exp
  battle:awardExp()
  T.check(monA.exp > 0, "integration: the fighter gained exp")
  T.check(monB.exp > 0, "integration: the bench mon gained exp")
  T.check(monA.exp + monB.exp > expBefore, "integration: total exp went up")
  T.check(monA.exp > monB.exp,
    "integration: the fighter out-earns the half-share bench mon")
end

run.release()
T.finish("exp_share")
