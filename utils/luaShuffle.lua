-- Перемешивание партий в PGN-файле
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
if m_lim < 2 then return end

-- Правильный прогрев генератора
math.randomseed(os.time() + math.floor(os.clock() * 1000000))
for i = 1, 5 do math.random() end

local SYM_CLN  = (';'):byte()
local SYM_BRK  = ('['):byte()
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

-- Предварительный сдвиг для мелких файлов
if #m_base < 10 then
  if (math.random(1, 100) % 2) ~= 0 then
    table.insert(m_base, 1, table.remove(m_base))
  else
    table.insert(m_base, table.remove(m_base, 1))
  end
end

-- Тасование Фишера-Йетса (не того Фишера)
if #m_base > 3 then
  for i = #m_base, 2, -1 do
    local j = math.random(i)
    m_base[i], m_base[j] = m_base[j], m_base[i]
  end
end

-- Вывод
for i = 1, #m_base do
  io.write(m_base[i], "\n\n")
end

