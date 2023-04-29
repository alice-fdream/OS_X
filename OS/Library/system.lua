local internet = require("internet")
local string = require("string")
local buffer = require("NyaDraw")
local GUI = require("GUI")
local computer = require("computer")
local fs = require('filesystem')
local event = require('event')
local unicode = require('unicode')
local component = require('component')
local key = require('serialization')
local md5 = require("md5")
local island = require("island")

local system = {}

function system.urlencode (str)
   local str = string.gsub (str, "([^0-9a-zA-Z !'()*._~-])", -- locale independent
      function (c) return string.format ("%%%02X", string.byte(c)) end)
   str = string.gsub (str, " ", "+")
   return str
end

function system.getRequest(url)
	local handle = internet.request(url)
	local result = ""
	for chunk in handle do result = result..chunk end
	local result = unicode.sub(result, 2, -1)
	
	return result
end

function system.prompt(title, a, b)
	island.close()
  island.overs:remove()
  island.overs = GUI.container(3, 4, 40, 20)
  island.container:addChild(island.overs)
  local input = GUI.input(2, 1, 39, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", title)
  island.overs:addChild(input)
  island.overs:addChild(GUI.roundedButton(2, 4, 16, 3, 0xaa51b0, 0xFFFFFF, 0x880000, 0xFFFFFF, "ОК")).onTouch = function()
    island.close()
    island.overs.callback(input.text)
  end
  island.overs:addChild(GUI.roundedButton(25, 4, 16, 3, 0xaa51b0, 0xFFFFFF, 0x880000, 0xFFFFFF, "Отмена")).onTouch = function()
    island.close()
    if island.overs.back then
      island.overs.back()
    end
  end
  if a == nil or a == 0 then
    island.open(12, 8)
  else
    island.open(a, b)
  end
end


function fs.makeDirectory(path)
  if fs.exists(path) then
    return nil, "file or directory with that name already exists"
  end
  local node, rest = fs.findNode(path)
  if node.fs and rest then
    local success, reason = node.fs.makeDirectory(rest)
    if not success and not reason and node.fs.isReadOnly() then
      reason = "fs is readonly"
    end
    return success, reason
  end
  if node.fs then
    return nil, "virtual directory with that name already exists"
  end
  return nil, "cannot create a directory in a virtual directory"
end

function fs.lastModified(path)
  local node, rest, vnode, vrest = fs.findNode(path, false, true)
  if not node or not vnode.fs and not vrest then
    return 0 -- virtual directory
  end
  if node.fs and rest then
    return node.fs.lastModified(rest)
  end
  return 0 -- no such file or directory
end

function fs.mounts()
  local tmp = {}
  for path,node in pairs(fs.fstab) do
    table.insert(tmp, {node.fs,path})
  end
  return function()
    local next = table.remove(tmp)
    if next then return table.unpack(next) end
  end
end

function fs.link(target, linkpath)
  checkArg(1, target, "string")
  checkArg(2, linkpath, "string")

  if fs.exists(linkpath) then
    return nil, "file already exists"
  end
  local linkpath_parent = fs.path(linkpath)
  if not fs.exists(linkpath_parent) then
    return nil, "no such directory"
  end
  local linkpath_real, reason = fs.realPath(linkpath_parent)
  if not linkpath_real then
    return nil, reason
  end
  if not fs.isDirectory(linkpath_real) then
    return nil, "not a directory"
  end

  local _, _, vnode, _ = fs.findNode(linkpath_real, true)
  vnode.links[fs.name(linkpath)] = target
  return true
end

function fs.umount(fsOrPath)
  checkArg(1, fsOrPath, "string", "table")
  local real
  local fs
  local addr
  if type(fsOrPath) == "string" then
    real = fs.realPath(fsOrPath)
    addr = fsOrPath
  else -- table
    fs = fsOrPath
  end

  local paths = {}
  for path,node in pairs(fs.fstab) do
    if real == path or addr == node.fs.address or fs == node.fs then
      table.insert(paths, path)
    end
  end
  for _,path in ipairs(paths) do
    local node = fs.fstab[path]
    fs.fstab[path] = nil
    node.fs = nil
    node.parent.children[node.name] = nil
  end
  return #paths > 0
end

function fs.size(path)
  local node, rest, vnode, vrest = fs.findNode(path, false, true)
  if not node or not vnode.fs and (not vrest or vnode.links[vrest]) then
    return 0 -- virtual directory or symlink
  end
  if node.fs and rest then
    return node.fs.size(rest)
  end
  return 0 -- no such file or directory
end

function fs.isLink(path)
  local name = fs.name(path)
  local node, rest, vnode, vrest = fs.findNode(fs.path(path), false, true)
  if not node then return nil, rest end
  local target = vnode.links[name]
  -- having vrest here indicates we are not at the
  -- owning vnode due to a mount point above this point
  -- but we can have a target when there is a link at
  -- the mount point root, with the same name
  if not vrest and target ~= nil then
    return true, target
  end
  return false
end

function fs.copy(fromPath, toPath)
  local data = false
  local input, reason = fs.open(fromPath, "rb")
  if input then
    local output = fs.open(toPath, "wb")
    if output then
      repeat
        data, reason = input:read(1024)
        if not data then break end
        data, reason = output:write(data)
        if not data then data, reason = false, "failed to write" end
      until not data
      output:close()
    end
    input:close()
  end
  return data == nil, reason
end

local function readonly_wrap(proxy)
  checkArg(1, proxy, "table")
  if proxy.isReadOnly() then
    return proxy
  end

  local function roerr() return nil, "fs is readonly" end
  return setmetatable({
    rename = roerr,
    open = function(path, mode)
      checkArg(1, path, "string")
      checkArg(2, mode, "string")
      if mode:match("[wa]") then
        return roerr()
      end
      return proxy.open(path, mode)
    end,
    isReadOnly = function()
      return true
    end,
    write = roerr,
    setLabel = roerr,
    makeDirectory = roerr,
    remove = roerr,
  }, {__index=proxy})
end

local function bind_proxy(path)
  local real, reason = fs.realPath(path)
  if not real then
    return nil, reason
  end
  if not fs.isDirectory(real) then
    return nil, "must bind to a directory"
  end
  local real_fs, real_fs_path = fs.get(real)
  if real == real_fs_path then
    return real_fs
  end
  -- turn /tmp/foo into foo
  local rest = real:sub(#real_fs_path + 1)
  local function wrap_relative(fp)
    return function(mpath, ...)
      return fp(fs.concat(rest, mpath), ...)
    end
  end
  local bind = {
    type = "fs_bind",
    address = real,
    isReadOnly = real_fs.isReadOnly,
    list = wrap_relative(real_fs.list),
    isDirectory = wrap_relative(real_fs.isDirectory),
    size = wrap_relative(real_fs.size),
    lastModified = wrap_relative(real_fs.lastModified),
    exists = wrap_relative(real_fs.exists),
    open = wrap_relative(real_fs.open),
    remove = wrap_relative(real_fs.remove),
    read = real_fs.read,
    write = real_fs.write,
    close = real_fs.close,
    getLabel = function() return "" end,
    setLabel = function() return nil, "cannot set the label of a bind point" end,
  }
  return bind
end

fs.internal = {}
function fs.internal.proxy(filter, options)
  checkArg(1, filter, "string")
  checkArg(2, options, "table", "nil")
  options = options or {}
  local address, proxy, reason
  if options.bind then
    proxy, reason = bind_proxy(filter)
  else
    -- no options: filter should be a label or partial address
    for c in component.list("fs", true) do
      if component.invoke(c, "getLabel") == filter then
        address = c
        break
      end
      if c:sub(1, filter:len()) == filter then
        address = c
        break
      end
    end
    if not address then
      return nil, "no such file system"
    end
    proxy, reason = component.proxy(address)
  end
  if not proxy then
    return proxy, reason
  end
  if options.readonly then
    proxy = readonly_wrap(proxy)
  end
  return proxy
end

function fs.remove(path)
  local function removeVirtual()
    local _, _, vnode, vrest = fs.findNode(fs.path(path), false, true)
    -- vrest represents the remaining path beyond vnode
    -- vrest is nil if vnode reaches the full path
    -- thus, if vrest is NOT NIL, then we SHOULD NOT remove children nor links
    if not vrest then
      local name = fs.name(path)
      if vnode.children[name] or vnode.links[name] then
        vnode.children[name] = nil
        vnode.links[name] = nil
        while vnode and vnode.parent and not vnode.fs and not next(vnode.children) and not next(vnode.links) do
          vnode.parent.children[vnode.name] = nil
          vnode = vnode.parent
        end
        return true
      end
    end
    -- return false even if vrest is nil because this means it was a expected
    -- to be a real file
    return false
  end
  local function removePhysical()
    local node, rest = fs.findNode(path)
    if node.fs and rest then
      return node.fs.remove(rest)
    end
    return false
  end
  local success = removeVirtual()
  success = removePhysical() or success -- Always run.
  if success then return true
  else return nil, "no such file or directory"
  end
end

function fs.rename(oldPath, newPath)
  if fs.isLink(oldPath) then
    local _, _, vnode, _ = fs.findNode(fs.path(oldPath))
    local target = vnode.links[fs.name(oldPath)]
    local result, reason = fs.link(target, newPath)
    if result then
      fs.remove(oldPath)
    end
    return result, reason
  else
    local oldNode, oldRest = fs.findNode(oldPath)
    local newNode, newRest = fs.findNode(newPath)
    if oldNode.fs and oldRest and newNode.fs and newRest then
      if oldNode.fs.address == newNode.fs.address then
        return oldNode.fs.rename(oldRest, newRest)
      else
        local result, reason = fs.copy(oldPath, newPath)
        if result then
          return fs.remove(oldPath)
        else
          return nil, reason
        end
      end
    end
    return nil, "trying to read from or write to virtual directory"
  end
end

local isAutorunEnabled = nil
local function saveConfig()
  local root = fs.get("/OS/")
  if root and not root.isReadOnly() then
    local f = fs.open("/etc/fs.cfg", "w")
    if f then
      f:write("autorun="..tostring(isAutorunEnabled))
      f:close()
    end
  end
end

function fs.isAutorunEnabled()
  if isAutorunEnabled == nil then
    local env = {}
    local config = loadfile("/etc/fs.cfg", nil, env)
    if config then
      pcall(config)
      isAutorunEnabled = not not env.autorun
    else
      isAutorunEnabled = true
    end
    saveConfig()
  end
  return isAutorunEnabled
end

function fs.setAutorunEnabled(value)
  checkArg(1, value, "boolean")
  isAutorunEnabled = value
  saveConfig()
end

os.execute = function(command)
  if not command then
    return type(shell) == "table"
  end
  return shell.execute(command)
end

function os.exit(code)
  error({reason="terminated", code=code}, 0)
end


return system