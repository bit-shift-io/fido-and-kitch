local tbl = {}

function tbl.findIndexEq(tab, el)
   for index, value in pairs(tab) do
      if value == el then
         return index
      end
   end
   return nil
end

function tbl.includes(tab, el)
   local idx = tbl.findIndexEq(tab, el)
   return idx ~= nil
end

function tbl.findIndex(tab, fn)
   for index, value in pairs(tab) do
      if fn(value) then
         return index
      end
   end
   return nil
end

function tbl.find(tab, fn)
   local index = tbl.findIndex(tab, fn)
   if index == nil then
      return nil
   end
   return tab[index]
 end

function tbl.length(t)
   local count = 0
   for _ in pairs(t) do count = count + 1 end
   return count
end

return tbl