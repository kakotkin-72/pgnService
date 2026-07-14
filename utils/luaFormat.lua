----------------------------------------------------------------
-- pgnService 2026.07.15
-- Форматирование партий в PGN-файле
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
local SYM_CLN  = (";"):byte()
local SYM_BRK  = ("["):byte()
local FMT_ZERO = 0
local FMT_TAGS = 1
local FMT_TEXT = 2

local m_note = FMT_ZERO
local m_flow = false
local m_buff = ""
local m_tail = "*"
local c_tset = { "*$", "1%-0$", "0%-1$", "1/2%-1/2$" }

local
function rtest(line)
  if line:find(m_tail .. "$")
    then return true end

  for i = 1, #c_tset do
    if line:find(c_tset[i])
      then return true end
  end

  return false
end

local
function mprint(line)
  local list = {}

  for word in line:gmatch("[^ ]+") do
    table.insert(list, word)
  end

  local outs = ""
  local outl = 0

  for i = 1, #list do
    local sub = list[i]
    local len = select(2, sub:gsub("[^\128-\191]", ""))
    -- хак для универсальной нарезки CP1251 и UTF-8

    if outl == 0 then
      outs = sub
      outl = len
    elseif (outl + 1 + len) <= m_len then
      outs = outs .. " " .. sub
      outl = outl + 1 + len
    else
      print(outs)
      outs = sub
      outl = len
    end
  end

  if outl > 0 then print(outs) end
end

local
function mflush()
  if #m_buff == 0 then return end

  local text = m_buff
  m_buff = ""

  -- варианты и комментарии с пробелом в нужном месте
  text = text:gsub("([%({])", " %1"):gsub("([%)}])", "%1 ")
  text = text:gsub("%s+", " ")
  text = text:gsub("([%({]) ", "%1"):gsub(" ([%)}])", "%1")

  -- концевые пробелы
  text = text:gsub("^%s+", ""):gsub("%s+$", "")

  -- нумерация ходов по фэншую
  text = text:gsub("([^%s%.%?%!])%s+([%.%?%!])", "%1%2")
  text = text:gsub("(%.)%s+(%.)", "%1%2")
  text = text:gsub("%.%.%.%.+", "...")
  text = text:gsub("([^%.])%.%.([^%.])", "%1...%2")
  text = text:gsub("(%.+)%s+", "%1")
  text = text:gsub("([^%.])%.%.%.([^%s%.)}])", "%1... %2")
  text = text:gsub("([^%.])%.([^%s%.)}])", "%1. %2")

  -- исправление для Chessis: отсутствует символ =
  text = text:gsub(
    "([a-h][18])=?([qrbnQRBN])",
    function(sq, chip)
      return sq .. "=" .. chip:upper()
    end)

  -- удаление комментов
  if m_rem then
    text = text:gsub("{.-}", "")
    text = text:gsub("$%d+", "")
    text = text:gsub("%s+", " ")
  end

  -- удаление вариантов
  if m_var then
    local list = {}

    -- маскировка комментов
    text = text:gsub(
      "({.-})",
      function(item)
        list[#list + 1] = item; return "_STUB_"
      end)

    while text:find("%b()") do
      text = text:gsub("%b()", "")
    end

    -- удаление битой нумерации черных ходов
    text = text:gsub("(%w+)%s+%d+%.%.%.%s*", "%1 ")

    -- возврат комментов
    text = text:gsub(
      "_STUB_",
      function()
        return table.remove(list, 1)
      end)

    text = text:gsub("%s+", " ")
  end

  if m_rem or m_var then
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
  end

  -- на случай, если ничего не осталось
  if #text == 0 then
    print(m_tail)
    m_flow = true
    m_tail = "*"
    return
  end

  -- исправление для Chessis: отсутствует терминатор
  if not rtest(text) then
    text = text .. " " .. m_tail
  end

  mprint(text)

  m_flow = true
  m_tail = "*"
end

-- Лимит на количество партий в этом скрипте не используется
-- Ожидаются только правильные строки после luaClean
for line in io.lines() do
  local sym = line:byte(1)

  if sym == SYM_BRK then
    mflush()

    if m_flow and (m_note ~= FMT_TAGS)
      then print("") end

    print(line)

    local res = line:match('%[Result "([^"]+)"%]')
    if res then m_tail = res end

    m_note = FMT_TAGS
    m_flow = true
  elseif sym == SYM_CLN then
    if m_note == FMT_ZERO then
      print(line)
      m_flow = true
    end
  elseif line ~= "" then
    if m_note == FMT_TAGS then
      print("")
      m_flow = true
    end

    m_buff = m_buff .. " " .. line
    m_note = FMT_TEXT
  end
end

-- Подбор хвостов
mflush()
if m_flow then print("") end

