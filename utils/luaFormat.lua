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
local CFG_LEN = 6
local CFG_LIM = 7
local CFG_CNT = 7

-- 1 = Разрешение на тег SetUp
-- 2 = Разрешение на тег ECO
-- 3 = Разрешение на теги WhiteElo и BlackElo
-- 4 = Разрешение на теги WhiteFideId и BlackFideId
-- 5 = Сжимать неопределенную дату
-- 6 = Максимальная длина строки для форматирования ходов
-- 7 = Количество первых партий для перемешивания и сортировки

local
function check()
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
  (not check())
then
  m_cfg = {0, 0, 0, 0, 1, 60, 3000} -- по умолчанию
end

-- Чтение всей конфигурации
local m_set = (m_cfg[CFG_SET] == 1) -- преобразование в boolean
local m_eco = (m_cfg[CFG_ECO] == 1)
local m_elo = (m_cfg[CFG_ELO] == 1)
local m_fid = (m_cfg[CFG_FID] == 1)
local m_fix = (m_cfg[CFG_FIX] == 1)
local m_len =  m_cfg[CFG_LEN]
local m_lim =  m_cfg[CFG_LIM]

-- Границы
m_len = math.min(math.max(m_len, 20), 180)
m_lim = math.min(math.max(m_lim, 0),  10000)

-- Основной код
local SYM_CLN  = (';'):byte()
local SYM_BRK  = ('['):byte()
local FMT_ZERO = 0
local FMT_TAGS = 1
local FMT_TEXT = 2

local m_note = FMT_ZERO
local m_flow = false
local m_buff = ""

local
function mflush()
  if #m_buff == 0 then return end

  local text = m_buff
  m_buff = ""

  -- варианты и комментарии с пробелом в нужном месте
  text = text:gsub("%(", " ("):gsub("%)", ") ")
  text = text:gsub( "{", " {"):gsub( "}", "} ")
  text = text:gsub("%s+", " ")
  text = text:gsub("%( ", "("):gsub(" %)", ")")
  text = text:gsub( "{ ", "{"):gsub( " }", "}")

  -- концевые пробелы
  text = text:gsub("^%s+", ""):gsub("%s+$", "")

  -- нумерация ходов по фэншую
  text = text:gsub("([^%s%.])%s+(%.)", "%1%2")
  text = text:gsub("(%.)%s+(%.)", "%1%2")
  text = text:gsub("%.%.%.%.+", "...")
  text = text:gsub("([^%.])%.%.([^%.])", "%1...%2")
  text = text:gsub("(%.+)%s+", "%1")
  text = text:gsub("([^%.])%.%.%.([^%s%.)}])", "%1... %2")
  text = text:gsub("([^%.])%.([^%s%.)}])", "%1. %2")

  if #text == 0 then
    print("*\n")
    m_flow = true
    return
  end

  while #text > 0 do
    if #text <= m_len then
      print(text); break
    end

    local chunk = text:sub(1, m_len + 1)
    local last = chunk:match("^.*() ")

    if last == nil then
      local first = text:find(" ")

      if first then
        print(text:sub(1, first - 1))
        text = text:sub(first + 1)
      else
        print(text)
        break
      end
    else
      print(text:sub(1, last - 1))
      text = text:sub(last + 1)
    end
  end

  m_flow = true
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

