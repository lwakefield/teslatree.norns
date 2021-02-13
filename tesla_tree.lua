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
local Rand      = include "lib/random"

local alt = false
local seqs = {}
local seq_walk
local loop_num = 1
local seq_pos = 0
local page = 1
local tree_traversals = {}
--       1
--   2       3
-- 4   5   6   7
--8 9 a b c d e f
tree_traversals[1] = {1}
tree_traversals[2] = {1, 2, 1, 3}
tree_traversals[3] = {1, 2, 4, 2, 5, 2, 1, 3, 6, 3, 7, 3}
tree_traversals[4] = {1, 2, 4, 8, 4, 9, 4, 2, 5, 10, 5, 11, 5, 2, 1, 3, 6, 12, 6, 13, 6, 3, 7, 14, 7, 15, 7, 3}


engine.name = "PolyPerc"

local osc_from
local last_note = { -1, false }

local function get_bch()
  return tree_traversals[params:get("tree_size")][params:get("tree_step")]
end

local function next_step()
  seq_pos = seq_pos + 1
  if seq_pos > params:get("seqlen") then
    seq_pos = 1
    if params:get("walk") == 1 then loop_num = loop_num + 1 end
  end
  if loop_num > params:get("loops") then
    next_tree_step = params:get("tree_step") + 1
    if next_tree_step > #tree_traversals[params:get("tree_size")] then next_tree_step = 1 end
    params:set("tree_step", next_tree_step, true)
    loop_num = 1
  end
  
  if osc_from and last_note[2] then
    osc.send(osc_from, "/noteoff", { last_note[1] })
  end
  local this_note = seqs[get_bch()][seq_pos]
  should_play = this_note[2]
  if osc_from and this_note[2] then
    osc.send(osc_from, "/noteon", { this_note[1] })
  end
  if this_note[2] then
    engine.hz(MusicUtil.note_num_to_freq(this_note[1]))
  end
  last_note = this_note
  
  redraw()
end

local function internal_clock_loop()
  while true do
    div = params:get("div")
    if div >= 1 then
      clock.sync(1 / div)
    else
      clock.sync(-(div)+1)
    end
    next_step()
  end
end

local function osc_in(path, args, from)
  osc_from = from
end

local function gen_seqs()
  math.randomseed(params:get("seed"))
  root = params:get("root")
  scale = MusicUtil.generate_scale(24 + root % 12, params:string("scale"), 8)
  range = params:get("range")
  root_idx = TabUtil.key(scale, root)

  seq = { { root, true } }
  rand = Rand()
  rand:seed(params:get("seed"))

  last_idx = root_idx
  for i = 2, params:get("seqlen") do
    offset = util.round(rand:next_float() * 2 * range - range)
    last_idx = last_idx + offset
    last_idx = util.clamp(last_idx, 1, #scale)
    seq[#seq+1] = { scale[last_idx], (rand:next_float() * 100) < params:get("chance") } -- { note, play? }
  end
  
  seqs = Tree.mktree(tonumber(params:string("tree_size")), function (i, t)
    if i == 1 then
      return seq
    else
      parent_seq = t[Tree.parent(i)]
      mut_seq = {}
      for i=1,#parent_seq do
        mut_seq[i] = { parent_seq[i][1], parent_seq[i][2] }
      end
      
      for i = 1, params:get("muts") do
        -- which note are we mutating?
        mut_idx = util.round(util.linlin(0, 1, 1, #mut_seq, rand:next_float()))
        -- how far are we mutating it?
        offset = util.round(rand:next_float() * 2 * range - range)
        
        -- get the old idx in the scale and add the offset
        scale_idx = TabUtil.key(scale, mut_seq[mut_idx][1])
        scale_idx = scale_idx + offset
        scale_idx = util.clamp(scale_idx, 1, #scale)
        
        mut_seq[mut_idx][1] = scale[scale_idx]
      end
      
      return mut_seq
    end
  end)
end

function init()
  engine.amp(1.0)

  -- root sequence params
  params:add{
    type="number", id="scale", name="scale",
    min=1, max=#MusicUtil.SCALES, default=2,
    action=gen_seqs,
    formatter=function (p) 
      return MusicUtil.SCALES[p:get()].name
    end
  }
  params:add{
    type="number", id="seed", name="seed",
    min=1, max=math.maxinteger, default=1,
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
    type="number", id="chance", name="chance",
    min=1, max=100, default=80,
    action=gen_seqs
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
    type="number", id="muts", name="muts",
    min=1, max=16, default=2,
    action=gen_seqs
  }
  params:add{
    type="option", id="tree_size", options={1, 3, 7, 15}, default=2,
    action=function ()
      if params:get("tree_step") > #tree_traversals[params:get("tree_size")] then
        params:set("tree_step", 1)
      end
      gen_seqs()
    end
  }
  params:add{
    type="number", id="tree_step", default=1,
    action=function (p)
      if p > #tree_traversals[params:get("tree_size")] then
        params:set("tree_step", 1, true)
      elseif p < 1 then
        params:set("tree_step", #tree_traversals[params:get("tree_size")], true)
      end
    end
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
    min=-128, max=128, default=4,
    formatter=function (p)
      val = p:get()
      if val > 0 then
        return "1/" .. val
      else
        return (-(val)+1) .. "/1"
      end
    end
  }

  params:add{
    type="number", id="clk_src", name="clk_src",
    min=1, max=2, default=1
  }

  cs_CUT = controlspec.new(50,5000,'exp',0,500,'hz')
  params:add{
    type="control", id="cutoff", controlspec=cs_CUT,
    action=function()
      engine.cutoff(params:get("cutoff"))
    end
  }
  cs_REL = controlspec.new(0.1,10,'lin',0,5,'s')
  params:add{
    type="control", id="release", controlspec=cs_REL,
    action=function()
      engine.release(params:get("release"))
    end
  }

  engine.cutoff(params:get("cutoff"))
  engine.release(params:get("release"))

  gen_seqs()
  
  osc.event = osc_in
  
  clock.run(internal_clock_loop)
end

function key(n,z)
  if n==1 then
    alt = z==1
  end

  if n==2 and z==1 then page=util.clamp(page-1,1,2) end
  if n==3 and z==1 then page=util.clamp(page+1,1,2) end
  
  redraw()
end

local pages = {}
pages[1] = { "seed", "chance", "range", "seqlen", "div", nil }
pages[2] = { "tree_step", "tree_size", nil, nil, "loops", "walk" }

function enc(n,d)
  param_idx = n
  if alt then param_idx = param_idx + 3 end
  
  if pages[page][param_idx] then params:delta(pages[page][param_idx], d) end

  redraw()
end

function redraw()
  screen.clear()
  
  curr_page = pages[page]
  
  function draw_item (idx, x, y)
    if curr_page[idx] == nil then return end
    screen.move(x,y)
    screen.text(curr_page[idx] .. ": " .. params:string(curr_page[idx]))
  end
  
  if alt == false then screen.level(15) else screen.level(1) end
  draw_item(1, 10, 10)
  draw_item(2, 10, 20)
  draw_item(3, 10, 30)
  if alt == true then screen.level(15) else screen.level(1) end
  draw_item(4, 75, 10)
  draw_item(5, 75, 20)
  draw_item(6, 75, 30)

  screen.line_width(1)

  y = 50
  seq = seqs[get_bch()]
  for i = 1, #seq do
    if i > 1 then
      y = y - (seq[i][1] - seq[i-1][1])
    end
    if seq_pos == i then
      screen.level(15)
    else
      screen.level(1)
    end
    screen.move(i*5, y)
    if seq[i][2] then
      screen.line_rel(5,0)
      screen.stroke()
    end
  end

  screen.update()
end

function cleanup()
end