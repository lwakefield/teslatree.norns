-- Tesla Tree
-- . . .
-- . . .
-- . . .
--   .
--   . 
-- 

function unrequire(name)
  package.loaded[name] = nil
  _G[name] = nil
end
unrequire("musicutil")

local MusicUtil = require "musicutil"
local TabUtil   = require "tabutil"
local Tree      = include "lib/tree"

local alt = false
local seqs = {}
local seq_walk
local loop_num = 1
local seq_pos = 0
local page = 1

engine.name = "PolyPerc"

local function loop()
  while true do
    clock.sync(1 / params:get("div"))
    seq_pos = seq_pos + 1
    if seq_pos > params:get("seqlen") then
      seq_pos = 1
      if params:get("walk") then loop_num = loop_num + 1 end
    end
    if loop_num > params:get("loops") then
      params:set("bch", seq_walk(), true)
      loop_num = 1
    end
    engine.hz(MusicUtil.note_num_to_freq(seqs[params:get("bch")][seq_pos]))
    redraw()
  end
end

local function gen_seqs()
  math.randomseed(params:get("seed"))
  root = params:get("root")
  scale = MusicUtil.generate_scale(24 + root % 12, params:string("scale"), 8)
  range = params:get("range")
  root_idx = TabUtil.key(scale, root)

  seq = { root }
  for i = 2, params:get("seqlen") do
    last_idx = TabUtil.key(scale, seq[#seq])
    offset = util.round(math.random() * 2 * range - range)
    seq[#seq+1] = scale[last_idx+offset]
  end

  seqs = Tree.mktree(params:get("bchs"), function (i, t)
    if i == 1 then
      return seq
    else
      mut_seq = {table.unpack(t[Tree.parent(i)])}
      for i = 1, params:get("muts") do
        mut_idx = util.round(util.linlin(0, 1, 1, #mut_seq, math.random()))
        offset = util.round(math.random() * 2 * range - range)
        scale_idx = TabUtil.key(scale, mut_seq[mut_idx])
        mut_seq[mut_idx] = scale[scale_idx+offset]
      end
      return mut_seq
    end
  end)

  if seq_walk then
    last_idx = params:get("bch")
    next_idx = seq_walk()
    if next_idx <= #seqs then
      next_idx = Tree.parent(#seqs)
      last_idx = #seqs
    end
    seq_walk = Tree.walker(#seqs, next_idx, last_idx)
  else
    seq_walk = Tree.walker(#seqs)
    params:set("bch", seq_walk())
  end
end

function init()
  engine.amp(1.0)
  engine.cutoff(500)
  engine.release(0.5)

  params:add{
    type="number", id="scale", name="scale",
    min=1, max=#MusicUtil.SCALES, default=1,
    action=gen_seqs,
    formatter=function (p) 
      return MusicUtil.SCALES[p:get()].name
    end
  }
  params:add{
    type="number", id="seed", name="seed",
    min=0, max=math.maxinteger, default=0,
    action=gen_seqs
  }
  params:add{
    type="number", id="root", name="root",
    min=24, max=128, default=60,
    action=gen_seqs,
    formatter=function (p) 
      return MusicUtil.note_num_to_name(p:get(), true)
    end
  }

  params:add{
    type="number", id="seqlen", name="seqlen",
    min=1, max=16, default=8,
    action=gen_seqs
  }
  params:add{
    type="number", id="range", name="range",
    min=0, max=8, default=3,
    action=gen_seqs
  }

  params:add{
    type="number", id="bch", name="bch",
    min=1, max=128, default=4,
    action=gen_seqs -- need to set the max to bchs
  }
  params:add{
    type="number", id="muts", name="muts",
    min=1, max=16, default=2,
    action=gen_seqs
  }
  params:add{
    type="number", id="bchs", name="bchs",
    min=1, max=255, default=7,
    action=gen_seqs
  }

  params:add{
    type="number", id="loops", name="loops",
    min=1, max=255, default=2,
    action=gen_seqs
  }
  params:add{
    type="binary", id="walk", name="walk", behavior="toggle",
    default=1,
    action=gen_seqs
  }
  params:add{
    type="number", id="div", name="div",
    min=1, max=128, default=4
  }

  gen_seqs()
  clock.run(loop)
end

function key(n,z)
  if n==1 then
    alt = z==1
  end

  if n==2 and z==1 then page=util.clamp(page-1,1,2) end
  if n==3 and z==1 then page=util.clamp(page+1,1,2) end
end

function enc(n,d)
  if page == 1 then
    if alt==false and n == 1 then
      params:delta("scale", d)
    elseif alt==false and n==2 then
      params:delta("seed", d)
    elseif alt==true and n==2 then
      params:delta("seqlen", d)
    elseif alt==false and n == 3 then
      params:delta("root", d)
    elseif alt==true and n==3 then
      params:delta("range", d)
    end
  elseif page == 2 then
    if alt==false and n == 1 then
      if params:get("walk") == false then
        params:delta("bch", d)
      end
    elseif alt==true and n == 1 then
      params:delta("loops", d)
    elseif alt==false and n == 2 then
      params:delta("muts", d)
    elseif alt==true and n == 2 then
      params:set("walk", d)
    elseif alt==false and n == 3 then
      params:delta("bchs", d)
    elseif alt==true and n == 3 then
      params:delta("div", d)
      -- tempo = util.clamp(tempo + d, 1, 1024)
    elseif false then
    end
  end

  redraw()
end

function redraw()
  screen.clear()
  -- screen.level(15)

  if page == 1 then
    if alt == false then screen.level(15) else screen.level(1) end

    screen.move(10,10)
    screen.text("scale: " .. params:string("scale"))
    screen.move(10,20)
    screen.text("seed: " .. params:get("seed"))
    screen.move(10,30)
    screen.text("root: " .. MusicUtil.note_num_to_name(params:get("root"), true))

    if alt == true then screen.level(15) else screen.level(1) end

    -- screen.move(75,10)
    -- screen.text("bch: " .. bch)
    screen.move(75,20)
    screen.text("len: " .. params:get("seqlen"))
    screen.move(75,30)
    screen.text("range: " .. params:get("range"))
  elseif page == 2 then
    if alt == false then screen.level(15) else screen.level(1) end

    screen.move(10,10)
    screen.text("bch: " .. params:get("bch"))
    screen.move(10,20)
    screen.text("muts: " .. params:get("muts"))
    screen.move(10,30)
    screen.text("bchs: " .. params:get("bchs"))

    if alt == true then screen.level(15) else screen.level(1) end

    screen.move(75,10)
    screen.text("loops: " .. params:get("loops"))
    screen.move(75,20)
    screen.text("walk: " .. tostring(params:get("walk")))
    screen.move(75,30)
    screen.text("tempo: " .. params:get("div"))
  end

  screen.line_width(1)

  y = 50
  seq = seqs[params:get("bch")]
  for i = 1,#seq do
    if i > 1 then
      y = y - (seq[i] - seq[i-1])
    end
    if seq_pos == i then
      screen.level(15)
    else
      screen.level(1)
    end
    screen.move(i*5, y)
    screen.line_rel(5,0)
    screen.stroke()
  end

  screen.update()
end

function cleanup()
end
