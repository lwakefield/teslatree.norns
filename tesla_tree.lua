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

local TreeusicUtil = require "musicutil"
local TabUtil   = require "tabutil"
local Tree      = include "lib/tree"

local SCALES_LEN = #TreeusicUtil.SCALES
local CHORDS_LEN = #TreeusicUtil.CHORDS

local alt = false
params:add_number("seed", "seed", 0, math.maxinteger, 0)
local amp = 0.5
local tempo = 60
local scl_idx = 1
local seq_len = 8
local root = 60
local seqs = {}
local should_walk = true
local seq_walk
local bch   = 1
local loops_per_bch = 2
local loop_num = 1
local seq_pos = 0
local range = 3
local num_bch = 7
local num_mut = 2
local page = 1

engine.name = "PolyPerc"

local function loop()
  while true do
    clock.sync(60 / tempo / 4)
    seq_pos = seq_pos + 1
    if seq_pos > seq_len then
      seq_pos = 1
      if should_walk then loop_num = loop_num + 1 end
    end
    if loop_num > loops_per_bch then
      bch = seq_walk()
      loop_num = 1
    end
    -- seq_pos = util.wrap(seq_pos + 1, 1, seq_len)
    engine.hz(TreeusicUtil.note_num_to_freq(seqs[bch][seq_pos]))
    redraw()
  end
end

local function gen_seqs()
  math.randomseed(params:get("seed"))
  scale = TreeusicUtil.generate_scale(24 + root % 12, TreeusicUtil.SCALES[scl_idx].name, 8)
  root_idx = TabUtil.key(scale, root)

  seq = { root }
  for i = 2, seq_len do
    last_idx = TabUtil.key(scale, seq[#seq])
    offset = util.round(math.random() * 2 * range - range)
    seq[#seq+1] = scale[last_idx+offset]
  end

  seqs = Tree.mktree(num_bch, function (i, t)
    if i == 1 then
      return seq
    else
      mut_seq = {table.unpack(t[Tree.parent(i)])}
      for i = 1, num_mut do
        mut_idx = util.round(util.linlin(0, 1, 1, #mut_seq, math.random()))
        offset = util.round(math.random() * 2 * range - range)
        scale_idx = TabUtil.key(scale, mut_seq[mut_idx])
        mut_seq[mut_idx] = scale[scale_idx+offset]
      end
      return mut_seq
    end
  end)

  seq_walk = Tree.walker(#seqs)
  bch = seq_walk()
end

function init()
  engine.amp(amp)
  engine.cutoff(500)
  engine.release(0.5)

  gen_seqs()
  clock_id = clock.run(loop)
  
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
      scl_idx = util.clamp(scl_idx + d, 1, #TreeusicUtil.SCALES)
    elseif alt==false and n==2 then
      params:delta("seed", d)
    elseif alt==true and n==2 then
      seq_len = util.clamp(seq_len + d, 1, 16)
    elseif alt==false and n == 3 then
      root = util.clamp(root + d, 24, 108)
    elseif alt==true and n==3 then
      range = util.clamp(range + d, 1, 8)
    end
  elseif page == 2 then
    if alt==false and n == 1 then
      if should_walk == false then
        bch = util.clamp(bch + d, 1, #seqs)
      end
    elseif alt==true and n == 1 then
      loops_per_bch = util.clamp(loops_per_bch + d, 1, 32)
    elseif alt==false and n == 2 then
      num_muts = util.clamp(num_muts + d, 1, 32)
    elseif alt==true and n == 2 then
      should_walk = d == 1
    elseif alt==false and n == 3 then
      num_bch = util.clamp(num_bch + d, 1, 255)
    elseif alt==true and n == 3 then
      tempo = util.clamp(tempo + d, 1, 1024)
    elseif false then
    end
  end

  gen_seqs()
  redraw()
end

function redraw()
  screen.clear()
  -- screen.level(15)

  if page == 1 then
    if alt == false then screen.level(15) else screen.level(1) end

    screen.move(10,10)
    screen.text("scale: " .. TreeusicUtil.SCALES[scl_idx].name)
    screen.move(10,20)
    screen.text("seed: " .. params:get("seed"))
    screen.move(10,30)
    screen.text("root: " .. TreeusicUtil.note_num_to_name(root, true))

    if alt == true then screen.level(15) else screen.level(1) end

    -- screen.move(75,10)
    -- screen.text("bch: " .. bch)
    screen.move(75,20)
    screen.text("len: " .. seq_len)
    screen.move(75,30)
    screen.text("range: " .. range)
  elseif page == 2 then
    if alt == false then screen.level(15) else screen.level(1) end

    screen.move(10,10)
    screen.text("bch: " .. bch)
    screen.move(10,20)
    screen.text("muts: " .. num_mut)
    screen.move(10,30)
    screen.text("bchs: " .. num_bch)

    if alt == true then screen.level(15) else screen.level(1) end

    screen.move(75,10)
    screen.text("loops: " .. loops_per_bch)
    screen.move(75,20)
    screen.text("walk: " .. tostring(should_walk))
    screen.move(75,30)
    screen.text("tempo: " .. tempo)
  end

  screen.line_width(1)

  y = 50
  seq = seqs[bch]
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
