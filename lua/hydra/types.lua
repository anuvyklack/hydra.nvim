---@alias hydra.foreign_keys "warn" | "run" | nil
---@alias hydra.color "red" | "pink" | "amaranth" | "teal"
---@alias hydra.Color "Red" | "Pink" | "Amaranth" | "Teal"

---@class hydra.Config
---@field debug boolean
---@field buffer? integer
---@field exit boolean
---@field foreign_keys hydra.foreign_keys
---@field color hydra.color
---@field on_enter? function
---@field on_exit? function
---@field on_key? function
---@field invoke_on_body boolean
---@field timeout boolean | number
---@field hint hydra.hint.Config | "statusline" | false

---@class hydra.hint.Config
---@field position string
---@field border string | table | nil
---@field functions function[]

---@class hydra.HeadSpec
---@field index integer
---@field head string
---@field color hydra.Color
---@field desc? string | false

---@class hydra.Head
---@field rhs string | function | nil
---@field opts hydra.HeadOpts

---@class hydra.HeadOpts
---@field public private? boolean
---@field exit? boolean
---@field on_key? boolean
---@field mode? string[]
---@field silent? boolean
---@field expr? boolean
---@field nowait? boolean
---@field remap? boolean
---@field desc? string

---@class KeymapOpts
---@field buffer? integer | true
---@field expr? boolean
---@field remap? boolean
---@field nowait? boolean
---@field silent? boolean
---@field desc? string

---@class MetaAccessor

---@class libuv.Timer
---@field start function
---@field again function
---@field close function
