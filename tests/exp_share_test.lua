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
T.eq(row.step(game, 1), true, "step again")
T.eq(game.save.options.expShare, "balanced", "GEN 5+ cycles to BALANCED")
T.eq(row.value(game), "BALANCED", "BALANCED label")
T.eq(row.step(game, 1), true, "step again")
T.eq(game.save.options.expShare, "average", "BALANCED cycles to AVERAGE")
T.eq(row.value(game), "AVERAGE", "AVERAGE label")
T.eq(row.step(game, -1), true, "stepping left works")
T.eq(game.save.options.expShare, "balanced", "AVERAGE left-cycles to BALANCED")
T.eq(row.step(game, 1), true, "step again")
T.eq(game.save.options.expShare, "average", "BALANCED right-cycles to AVERAGE")
T.eq(row.step(game, 1), true, "step again")
T.eq(game.save.options.expShare, "off", "AVERAGE cycles back to OFF")
T.eq(written, 7, "each step persists via writeOptions")

game.save.options.expShare = "bogus"
T.eq(ex.modeOf(game), "off", "a garbage value normalizes to OFF")
game.save.options.expShare = "average"
T.eq(ex.modeOf(game), "average", "AVERAGE is a recognized mode")
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
  T.eq(log[2].text, "EXP is shared\namongst the party!",
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
  T.eq(log[2].text, "EXP is shared\namongst the party!",
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

-- ------------------------------------------------ BALANCED split

do
  -- bench below the active fighter's level: half share + share line
  local log = {}
  local monA, monB = { hp = 10, level = 12 }, { hp = 10, level = 10 }
  local battle = {
    game = { save = { options = { expShare = "balanced" },
                      party = { monA, monB } } },
    player = { mon = { level = 12 } },
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
  ex.awardBalanced(ctx)
  T.eq(log[1].mon, monA, "balanced: the fighter keeps the full amount")
  T.eq(log[1].split, 1, "balanced: fighter split = participants(1)")
  T.eq(log[2].kind, "say", "balanced: the share line follows the fighter")
  T.eq(log[3].mon, monB, "balanced: the under-leveled bench mon is paid")
  T.eq(log[3].split, 2, "balanced: bench gets half a fighter's share")
  T.eq(log[3].announce, nil, "balanced: bench gains are not announced per mon")
  T.eq(#log, 3, "balanced: fighter share + share line + one bench share")
end

do
  -- bench AT the active fighter's level: no exp, no share line
  local log = {}
  local monA, monB = { hp = 10, level = 12 }, { hp = 10, level = 12 }
  local battle = {
    game = { save = { options = { expShare = "balanced" },
                      party = { monA, monB } } },
    player = { mon = { level = 12 } },
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
  ex.awardBalanced(ctx)
  T.eq(#log, 1, "balanced: a bench mon at the fighter's level gets nothing")
end

do
  -- bench ABOVE the active fighter's level: no exp, no share line
  local log = {}
  local monA, monB = { hp = 10, level = 10 }, { hp = 10, level = 14 }
  local battle = {
    game = { save = { options = { expShare = "balanced" },
                      party = { monA, monB } } },
    player = { mon = { level = 10 } },
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
  ex.awardBalanced(ctx)
  T.eq(#log, 1, "balanced: an over-leveled bench mon gets nothing")
end

do
  -- mixed bench: only the under-leveled mon is paid, share line still
  -- shows once
  local log = {}
  local monA = { hp = 10, level = 12 }
  local under, equal = { hp = 10, level = 9 }, { hp = 10, level = 12 }
  local battle = {
    game = { save = { options = { expShare = "balanced" },
                      party = { monA, under, equal } } },
    player = { mon = { level = 12 } },
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
  ex.awardBalanced(ctx)
  T.eq(log[1].mon, monA, "balanced: the fighter is paid first")
  T.eq(log[2].kind, "say", "balanced: one share line")
  T.eq(log[3].mon, under, "balanced: only the under-leveled bench mon is paid")
  T.eq(#log, 3, "balanced: the at-level bench mon is skipped")
end

do
  -- solo party: vanilla amounts, no gate involvement
  local log = {}
  local monA = { hp = 10, level = 7 }
  local battle = {
    game = { save = { options = { expShare = "balanced" },
                      party = { monA } } },
    player = { mon = { level = 7 } },
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
  ex.awardBalanced(ctx)
  T.eq(log[1].split, 1, "balanced: solo mon keeps the full amount")
  T.eq(#log, 1, "balanced: no share line for a solo party")
end

-- ------------------------------------------------ AVERAGE split

do
  -- party {12, 10, 8} averages 10; the bench at 9 is below it and is
  -- paid, the bench at 10 is at the average and is skipped
  local log = {}
  local monA, monB, monC = { hp = 10, level = 12 }, { hp = 10, level = 9 },
                            { hp = 10, level = 10 }
  local battle = {
    game = { save = { options = { expShare = "average" },
                      party = { monA, monB, monC } } },
    player = { mon = { level = 12 } },
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
  ex.awardAverage(ctx)
  T.eq(log[1].mon, monA, "average: the fighter keeps the full amount")
  T.eq(log[1].split, 1, "average: fighter split = participants(1)")
  T.eq(log[2].kind, "say", "average: the share line follows the fighter")
  T.eq(log[3].mon, monB, "average: the below-average bench mon is paid")
  T.eq(log[3].split, 2, "average: bench gets half a fighter's share")
  T.eq(log[3].announce, nil, "average: bench gains are not announced per mon")
  T.eq(#log, 3, "average: the at-average bench mon is skipped")
end

do
  -- flat party {10, 10, 10} averages 10: the bench at 10 gets nothing
  local log = {}
  local monA, monB = { hp = 10, level = 10 }, { hp = 10, level = 10 }
  local battle = {
    game = { save = { options = { expShare = "average" },
                      party = { monA, monB } } },
    player = { mon = { level = 10 } },
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
  ex.awardAverage(ctx)
  T.eq(#log, 1, "average: a bench mon at the party average gets nothing")
end

do
  -- party {14, 12, 8} averages 11 (floored): the bench at 12 is above
  -- the average and gets nothing (even though it is below the fighter);
  -- only the level-8 bench mon is paid
  local log = {}
  local monA, monHigh, monLow = { hp = 10, level = 14 }, { hp = 10, level = 12 },
                                { hp = 10, level = 8 }
  local battle = {
    game = { save = { options = { expShare = "average" },
                      party = { monA, monHigh, monLow } } },
    player = { mon = { level = 14 } },
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
  ex.awardAverage(ctx)
  T.eq(log[1].mon, monA, "average: the fighter is paid first")
  T.eq(log[2].kind, "say", "average: one share line")
  T.eq(log[3].mon, monLow, "average: only the below-average bench mon is paid")
  T.eq(#log, 3, "average: the above-average bench mon is skipped")
end

do
  -- solo party: no gate involvement
  local log = {}
  local monA = { hp = 10, level = 7 }
  local battle = {
    game = { save = { options = { expShare = "average" },
                      party = { monA } } },
    player = { mon = { level = 7 } },
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
  ex.awardAverage(ctx)
  T.eq(log[1].split, 1, "average: solo mon keeps the full amount")
  T.eq(#log, 1, "average: no share line for a solo party")
end

-- ------------------------------------------------ SINGLE EXP SHARE row

local function findSlotRow(game)
  local rows = Runtime.call("ui.options.rows", function(_, r) return r end,
    game, { { id = "text_speed" } })
  for _, row in ipairs(rows) do
    if row.id == "exp_share_single" then return row end
  end
  return nil
end

local slotWritten = 0
local slotGame = {
  save = { options = {} },
  writeOptions = function(self)
    assert(type(self) == "table" and self.save ~= nil,
           "writeOptions must be called with a colon")
    slotWritten = slotWritten + 1
  end,
}

local slotRow = findSlotRow(slotGame)
T.neq(slotRow, nil, "the SINGLE EXP SHARE row joins the options menu")
T.eq(slotRow.label, "SINGLE EXP SHARE", "slot row label")
T.eq(slotRow.value(slotGame), "ALL", "slot defaults to ALL")
for _, want in ipairs({ "1", "2", "3", "4", "5", "6" }) do
  T.eq(slotRow.step(slotGame, 1), true, "slot step right (" .. want .. ")")
  T.eq(slotGame.save.options.expShareSingle, want, "slot value follows the save")
  T.eq(slotRow.value(slotGame), want, "slot label shows the slot")
end
T.eq(slotRow.step(slotGame, 1), true, "slot step right wraps")
T.eq(slotGame.save.options.expShareSingle, "all", "slot 6 wraps back to ALL")
T.eq(slotRow.value(slotGame), "ALL", "slot ALL label after the wrap")
T.eq(slotRow.step(slotGame, -1), true, "slot step left works")
T.eq(slotGame.save.options.expShareSingle, "6", "slot ALL left-cycles to 6")
T.eq(slotWritten, 8, "each slot step persists via writeOptions")

slotGame.save.options.expShareSingle = "all"
T.eq(ex.slotOf(slotGame), nil, "ALL means the whole party")
slotGame.save.options.expShareSingle = "3"
T.eq(ex.slotOf(slotGame), 3, "slot 3 is recognized")
slotGame.save.options.expShareSingle = "0"
T.eq(ex.slotOf(slotGame), nil, "slot 0 is out of range")
slotGame.save.options.expShareSingle = "7"
T.eq(ex.slotOf(slotGame), nil, "slot 7 is out of range")
slotGame.save.options.expShareSingle = "bogus"
T.eq(ex.slotOf(slotGame), nil, "a garbage slot value means ALL")
T.eq(ex.cycleSlot({}), nil, "no save -> nil (launcher is untouched)")
T.eq(ex.cycleSlot({ save = {} }), nil, "no options table -> nil")

-- ------------------------------------------------ SINGLE-slot splits

do
  -- GEN 5+ with slot 3: only the designated bench mon is paid
  local log = {}
  local monA, monB, monC = { hp = 10 }, { hp = 10 }, { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen5", expShareSingle = "3" },
                      party = { monA, monB, monC } } },
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
  T.eq(log[1].mon, monA, "single: the fighter keeps the full amount")
  T.eq(log[1].split, 1, "single: fighter split = participants(1)")
  T.eq(log[1].announce, true, "single: the fighter's own gain is announced")
  T.eq(log[2].kind, "say", "single: the share line follows the fighter")
  T.eq(log[3].mon, monC, "single: only the designated slot mon is paid")
  T.eq(log[3].split, 2, "single: the designated mon gets half a fighter's share")
  T.eq(log[3].announce, nil, "single: the designated gain is not announced")
  T.eq(#log, 3, "single: the other bench mon is skipped")
end

do
  -- GEN 5+ slot pointing at the fighter: nothing is shared, no line
  local log = {}
  local monA, monB = { hp = 10 }, { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen5", expShareSingle = "1" },
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
  T.eq(log[1].mon, monA, "single-to-fighter: the fighter keeps the full amount")
  T.eq(#log, 1, "single-to-fighter: no bench, no share line")
end

do
  -- GEN 5+ slot beyond the party size: the empty slot shares to nobody
  local log = {}
  local monA, monB = { hp = 10 }, { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen5", expShareSingle = "6" },
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
  T.eq(log[1].mon, monA, "empty-slot: the fighter keeps the full amount")
  T.eq(#log, 1, "empty-slot: an empty designated slot shares to nobody")
end

do
  -- GEN 1 with slot 2: the party pass reaches only the designated mon
  local log = {}
  local monA, monB, monC = { hp = 10 }, { hp = 10 }, { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen1", expShareSingle = "2" },
                      party = { monA, monB, monC } } },
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
  T.eq(log[1].mon, monA, "gen1 single: the fighter gets its announced half")
  T.eq(log[1].split, 2, "gen1 single: fighter split = participants(1) x 2")
  T.eq(log[1].announce, true, "gen1 single: the fighter's gain is announced")
  T.eq(log[2].kind, "say", "gen1 single: the share line follows the fighter")
  T.eq(log[2].text, "EXP is shared\namongst the party!",
    "gen1 single: the single shared-exp line")
  T.eq(log[3].mon, monB, "gen1 single: only the designated slot mon is in the party pass")
  T.eq(log[3].split, 6, "gen1 single: party pass = 1 x party(3) x 2")
  T.eq(log[3].announce, nil, "gen1 single: the party-pass gain is not announced")
  T.eq(#log, 3, "gen1 single: the other party mons are skipped")
end

do
  -- GEN 1 slot pointing at the fighter: the party pass stays with the
  -- fighter (no share line -- nothing is shared to anyone else)
  local log = {}
  local monA, monB = { hp = 10 }, { hp = 10 }
  local battle = {
    game = { save = { options = { expShare = "gen1", expShareSingle = "1" },
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
  T.eq(log[1].mon, monA, "gen1 single-to-fighter: the announced half")
  T.eq(log[2].mon, monA, "gen1 single-to-fighter: the party pass stays with the fighter")
  T.eq(log[2].split, 4, "gen1 single-to-fighter: party pass = 1 x party(2) x 2")
  T.eq(#log, 2, "gen1 single-to-fighter: no share line for a fighter-only pass")
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

do
  -- BALANCED replaces the vanilla split without calling it
  local sawVanilla = false
  local calls = {}
  local monA, monB = { hp = 10, level = 12 }, { hp = 10, level = 10 }
  local balancedBattle = {
    game = { save = { options = { expShare = "balanced" },
                      party = { monA, monB } } },
    player = { mon = { level = 12 } },
    sayNext = function() end,
  }
  local ctx = {
    battle = balancedBattle,
    participants = 1,
    alive = { monA },
    applyShare = function(mon, split) calls[#calls + 1] = split end,
  }
  Runtime.call("battle.exp_award", function() sawVanilla = true end, ctx)
  T.eq(sawVanilla, false, "BALANCED replaces the vanilla split")
  T.eq(#calls, 2, "the mod's split ran instead")
end

do
  -- AVERAGE replaces the vanilla split without calling it
  local sawVanilla = false
  local calls = {}
  local monA, monB = { hp = 10, level = 12 }, { hp = 10, level = 9 }
  local averageBattle = {
    game = { save = { options = { expShare = "average" },
                      party = { monA, monB } } },
    player = { mon = { level = 12 } },
    sayNext = function() end,
  }
  local ctx = {
    battle = averageBattle,
    participants = 1,
    alive = { monA },
    applyShare = function(mon, split) calls[#calls + 1] = split end,
  }
  Runtime.call("battle.exp_award", function() sawVanilla = true end, ctx)
  T.eq(sawVanilla, false, "AVERAGE replaces the vanilla split")
  T.eq(#calls, 2, "the mod's split ran instead")
end

do
  -- SINGLE EXP SHARE filters the bench through the real hook
  local sawVanilla = false
  local calls = {}
  local monA, monB, monC = { hp = 10 }, { hp = 10 }, { hp = 10 }
  local slotBattle = {
    game = { save = { options = { expShare = "gen5", expShareSingle = "3" },
                      party = { monA, monB, monC } } },
    sayNext = function() end,
  }
  local ctx = {
    battle = slotBattle,
    participants = 1,
    alive = { monA },
    applyShare = function(mon, split) calls[#calls + 1] = mon end,
  }
  Runtime.call("battle.exp_award", function() sawVanilla = true end, ctx)
  T.eq(sawVanilla, false, "single-slot replaces the vanilla split")
  T.eq(#calls, 2, "single through the hook: fighter + one designated mon")
  T.eq(calls[1], monA, "single through the hook: the fighter is paid first")
  T.eq(calls[2], monC, "single through the hook: only the slot-3 mon is paid")
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
