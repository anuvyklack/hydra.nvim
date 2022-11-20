---@alias hydra.foreign_keys "warn" | "run" | nil
---@alias hydra.color "red" | "pink" | "amaranth" | "teal" | "blue"
---@alias hydra.Color "Red" | "Pink" | "Amaranth" | "Teal" | "Blue"

---@class hydra.Config
---@field debug boolean
---@field desc string
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
---@field exit_before? boolean
---@field on_key? boolean
---@field mode? string[]
---@field silent? boolean
---@field expr? boolean
---@field nowait? boolean
---@field remap? boolean
---@field desc? string

---@class hydra.NvimKeymapOpts
---@field buffer? integer | true
---@field expr? boolean
---@field remap? boolean
---@field nowait? boolean
---@field silent? boolean
---@field desc? string

---@class hydra.MetaAccessor

---@class hydra.EchoChunk Chunk for vim.api.nvim_echo function
---@field [1] string Text
---@field [2] string | nil Highlight group name

---@class luv.Timer
---@field start function
---@field again function
---@field close function
