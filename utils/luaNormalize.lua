----------------------------------------------------------------
-- pgnService 2026.07.15
-- Нормализация PGN-файла
-- (С) 2026 Владимир Какоткин
----------------------------------------------------------------

-- Упрощенная под JScript конфигурация
local m_cfg = "pgnService.cfg"

local CFG_SET = 1
local CFG_ECO = 2
local CFG_ELO = 3
local CFG_FID = 4
local CFG_FIX = 5
local CFG_REM = 6
local CFG_VAR = 7
local CFG_LEN = 8
local CFG_LIM = 9
local CFG_CNT = 9

-- 1 = Разрешение на тег SetUp
-- 2 = Разрешение на тег ECO
-- 3 = Разрешение на теги WhiteElo и BlackElo
-- 4 = Разрешение на теги WhiteFideId и BlackFideId
-- 5 = Сжимать неопределенную дату
-- 6 = Удалять комментарии при форматировании ходов
-- 7 = Удалять варианты при форматировании ходов
-- 8 = Максимальная длина строки для форматирования ходов
-- 9 = Количество первых партий для перемешивания и сортировки

local
function ctest()
  if (type(m_cfg) ~= "table") or (#m_cfg ~= CFG_CNT)
    then return false end

  for i = 1, CFG_CNT do
    if type(m_cfg[i]) ~= "number"
      then return false end
  end

  return true
end

if
  (not pcall(function() m_cfg = dofile(m_cfg) end)) or
  (not ctest())
then
  m_cfg = { 0, 0, 0, 0, 1, 1, 1, 60, 1000 } -- по умолчанию
end

-- Чтение всей конфигурации
local m_set = (m_cfg[CFG_SET] == 1) -- преобразование в boolean
local m_eco = (m_cfg[CFG_ECO] == 1)
local m_elo = (m_cfg[CFG_ELO] == 1)
local m_fid = (m_cfg[CFG_FID] == 1)
local m_fix = (m_cfg[CFG_FIX] == 1)
local m_rem = (m_cfg[CFG_REM] == 1)
local m_var = (m_cfg[CFG_VAR] == 1)
local m_len =  m_cfg[CFG_LEN]
local m_lim =  m_cfg[CFG_LIM]

-- Корректировка границ
m_len = math.min(math.max(m_len, 20), 180)
m_lim = math.min(math.max(m_lim, 0),  10000)

-- Основной код
if m_lim < 2 then return end

local SYM_CLN  = (";"):byte()
local SYM_BRK  = ("["):byte()
local SHF_ZERO = 0
local SHF_TAGS = 1
local SHF_CRLF = 2
local SHF_TEXT = 3

local m_game = {}
local m_base = {}
local m_note = SHF_ZERO

local
function append()
  if #m_game == 0 then return end

  while (#m_game > 0) and (m_game[#m_game] == "") do
    table.remove(m_game)
  end

  table.insert(m_base, table.concat(m_game, "\n"))
  m_game = {}
end

local
function compare(a, b)
  local aval, bval, rval

  local
  function cmp(x, y)
    if (x == y)                then return nil   end
    if (x == "?") or (x == "") then return false end
    if (y == "?") or (y == "") then return true  end
    return x < y
  end

-- Сортировка: Event, Site, Round, Date, White, Black
-- Можно изменить, переставив местами блоки сравнения

  aval = (a:match('%[Event "([^"]+)"%]') or ""):lower()
  bval = (b:match('%[Event "([^"]+)"%]') or ""):lower()
  rval = cmp(aval, bval)
  if rval ~= nil then return rval end

  aval = (a:match('%[Site "([^"]+)"%]') or ""):lower()
  bval = (b:match('%[Site "([^"]+)"%]') or ""):lower()
  rval = cmp(aval, bval)
  if rval ~= nil then return rval end

  aval = a:match('%[Round "(%d+)"%]')
  bval = b:match('%[Round "(%d+)"%]')
  aval = aval and tonumber(aval) or math.huge
  bval = bval and tonumber(bval) or math.huge
  if aval ~= bval then return aval < bval end

  aval = a:match('%[Date "([^"]+)"%]') or ""
  bval = b:match('%[Date "([^"]+)"%]') or ""
  rval = cmp(aval, bval)
  if rval ~= nil then return rval end

  aval = (a:match('%[White "([^"]+)"%]') or ""):lower()
  bval = (b:match('%[White "([^"]+)"%]') or ""):lower()
  rval = cmp(aval, bval)
  if rval ~= nil then return rval end

  aval = (a:match('%[Black "([^"]+)"%]') or ""):lower()
  bval = (b:match('%[Black "([^"]+)"%]') or ""):lower()
  rval = cmp(aval, bval)
  if rval ~= nil then return rval end

  return false
end

-- Ожидаются только правильные строки после luaClean
for line in io.lines() do
  local sym = line:byte(1)

  if sym == SYM_BRK then
    if (#m_game > 0) and (m_note ~= SHF_TAGS) then
      append()
      if #m_base >= m_lim
        then break end
    end

    if m_flow and (m_note == SHF_ZERO)
      then print("") end

    table.insert(m_game, line)
    m_note = SHF_TAGS
  elseif sym == SYM_CLN then
    if m_note == SHF_ZERO then
      print(line)
      m_flow = true
    end
  elseif line ~= "" then
    table.insert(m_game, line)
    m_note = SHF_TEXT
  elseif line == "" then
    if m_note == SHF_TAGS then
      table.insert(m_game, "")
    end

    m_note = SHF_CRLF
  end
end

-- Подбор хвостов
if (#m_game > 0) and (#m_base < m_lim)
  then append() end

if #m_base < 2 then return end

-- Сортировка
table.sort(m_base, compare)

-- Вывод
for i = 1, #m_base do
  io.write(m_base[i], "\n\n")
end

