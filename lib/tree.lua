local Tree = {}

function Tree.parent(n)
  return math.floor(n/2)
end

function Tree.leftchild(n)
  return n*2
end

function Tree.rightchild(n)
  return n*2+1
end

function Tree.ischildof(p,c)
  return Tree.leftchild(p)==c or Tree.rightchild(p)==c
end

function Tree.isparentof(c,p)
  return Tree.ischildof(p,c)
end

function Tree.mktree(size, fn)
  tree = {}
  queue = {}
  while #tree < size do
    tree[#tree+1] = fn(#tree+1, tree)
  end
  return tree
end

--        1
--    2       3
--  4   5   6   7
function Tree.walker(size, next_idx, last_idx)
  next_idx = next_idx or 1
  last_idx = last_idx or nil
  return function ()
    curr_idx = next_idx
    if size == 1 then return 1 end

    if Tree.leftchild(curr_idx) > size then
      -- no more children
      next_idx = math.max(Tree.parent(curr_idx), 1)
    elseif last_idx == Tree.rightchild(curr_idx) then
        if curr_idx == 1 then
          -- we are back at the root, go left and start over
          next_idx = Tree.leftchild(curr_idx)
        else
          next_idx = Tree.parent(curr_idx)
        end
    elseif last_idx == Tree.leftchild(curr_idx) then
      next_idx = Tree.rightchild(curr_idx)
      if next_idx > size then
        -- handle cases where last node in tree is left child
        -- also 2 node trees
        next_idx = math.max(Tree.parent(curr_idx), 2)
      end
    else
      next_idx = Tree.leftchild(curr_idx)
    end

    last_idx = curr_idx
    return curr_idx
  end
end

return Tree