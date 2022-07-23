---@alias hydra.foreign_keys "warn" | "run" | nil
---@alias hydra.color "red" | "pink" | "amaranth" | "teal"
---@alias hydra.Color "Red" | "Pink" | "Amaranth" | "Teal"

---@class hydra.Config
---@field debug boolean
---@field buffer? integer
---@field exit boolean
---@field foreign_keys hydra.foreign_keys
---@field color hydra.color
---@field on_enter? function  Before entering hydra
---@field on_exit? function   After leaving hydra
---@field on_key? function    After every hydra head
---@field invoke_on_body boolean
---@field timeout boolean | number  Number of milliseconds
---@field hint hydra.hint.Config | false

---@class hydra.hint.Config
---@field type 'statusline' | 'cmdline' | 'window'
---@field position hydra.hint.Config.position
---@field offset integer
---@field border? string | table
---@field funcs table<string, fun():string>
---@field show_name boolean

---@class hydra.hint.Config.position
---@field [1] 'top' | 'middle' | 'bottom'
---@field [2]? 'left' | 'right'

---@class hydra.HeadSpec
---@field index integer
---@field head string
---@field color hydra.Color
---@field desc? string | false

---@class hydra.Head
---@field [1] string | function | nil
---@field [2] hydra.HeadOpts

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
