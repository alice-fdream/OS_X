local process = {}

-------------------------------------------------------------------------------

--Initialize coroutine library--
process.list = setmetatable({}, {__mode="k"})

function process.findProcess(co)
  co = co or coroutine.running()
  for main, p in pairs(process.list) do
    if main == co then
      return p
    end
    for _, instance in pairs(p.instances) do
      if instance == co then
        return p
      end
    end
  end
end

-------------------------------------------------------------------------------
function process.load(path, env, init, name)
  checkArg(1, path, "string", "function")
  checkArg(2, env, "table", "nil")
  checkArg(3, init, "function", "nil")
  checkArg(4, name, "string", "nil")

  assert(type(path) == "string" or env == nil, "process cannot load function environments")


  local thread = nil
  thread = coroutine.create(function(...)
    -- pcall code so that we can remove it from the process list on exit
    local result =
    {
      xpcall(function(...)
          init = init or function(...) return ... end
          return code(init(...))
        end,
        function(msg)
          if type(msg) == "table" and msg.reason == "terminated" then
            return msg.code or 0
          end
          local stack = debug.traceback():gsub("^([^\n]*\n)[^\n]*\n[^\n]*\n","%1")
          io.stderr:write(string.format("%s:\n%s", msg or "", stack))
          return 128 -- syserr
        end, ...)
    }

    --result[1] is false if the exception handler also crashed
    if not result[1] and type(result[2]) ~= "number" then
      io.stderr:write("process library exception handler crashed: ", tostring(result[2]))
    end

    -- onError opens a file, you can't open a file without a process, we close the process last
    process.internal.close(thread, result)

    return select(2, table.unpack(result))
  end, true)
  local new_proc =
  {
    path = path,
    command = name or tostring(path),
    env = env,
    data =
    {
      handles = {},
      io = {},
    },
    parent = p,
    instances = setmetatable({}, {__mode="v"}),
  }
  for i,fd in pairs(p.data.io) do
    new_proc.data.io[i] = io.dup(fd)
  end
  setmetatable(new_proc.data, {__index=p.data})
  process.list[thread] = new_proc

  return thread
end

function process.info(levelOrThread)
  checkArg(1, levelOrThread, "thread", "number", "nil")
  local p
  if type(levelOrThread) == "thread" then
    p = process.findProcess(levelOrThread)
  else
    local level = levelOrThread or 1
    p = process.findProcess()
    while level > 1 and p do
      p = p.parent
      level = level - 1
    end
  end
  if p then
    return {path=p.path, env=p.env, command=p.command, data=p.data}
  end
end

--table of undocumented api subject to change and intended for internal use
process.internal = {}
--this is a future stub for a more complete method to kill a process
function process.internal.close(thread, result)
  checkArg(1,thread,"thread")
  local pdata = process.info(thread).data
  pdata.result = result
  while pdata.handles[1] do
    local h = table.remove(pdata.handles)
    if h.close then
      pcall(h.close, h)
    end
  end
  process.list[thread] = nil
end

function process.internal.continue(co, ...)
  local result = {}
  -- Emulate CC behavior by making yields a filtered event.pull()
  local args = table.pack(...)
  while coroutine.status(co) ~= "dead" do
    result = table.pack(coroutine.resume(co, table.unpack(args, 1, args.n)))
    if coroutine.status(co) ~= "dead" then
      args = table.pack(coroutine.yield(table.unpack(result, 2, result.n)))
    elseif not result[1] then
      io.stderr:write(result[2])
    end
  end
  return table.unpack(result, 2, result.n)
end

function process.removeHandle(handle, proc)
  local handles = (proc or process.info()).data.handles
  for pos, h in ipairs(handles) do
    if h == handle then
      return table.remove(handles, pos)
    end
  end
end

function process.closeOnExit(stream, proc)
  local handles = (proc or process.info()).data.handles
  if not handles[stream] then
    handles[stream] = stream.close
    stream.close = function(...)
      local close = handles[stream]
      handles[stream] = nil
      if close then
        return close(...)
      end
    end
  end
end

function process.addHandle(handle, proc)
  local _close = handle.close
  local handles = (proc or process.info()).data.handles
  table.insert(handles, handle)
  function handle:close(...)
    if _close then
      self.close = _close
      _close = nil
      process.removeHandle(self, proc)
      return self:close(...)
    end
  end
  return handle
end

function process.running(level) -- kept for backwards compat, prefer process.info
  local info = process.info(level)
  if info then
    return info.path, info.env, info.command
  end
end

return process
