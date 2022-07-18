# keymap-layer

**hydra/layer** is a allows to temporarily remap some keys while
all others will be working as usual — to create a layer above your keybindings which will
overlap some of them.
On exiting layer the original keybindings become available again like nothing have happened.

```
           --------------------------
          /  q  /     /     /  r  /
         /-----/-----/-----/-----/-
        /     /  s  /     /     /   <--- Layer overlap some keys
       /-----/-----/-----/-----/--
      /     /     /     /  v  /|
     /-----/-----/-----/-----/--
             |   |         |   |
           --|---|---------|---|-----
          /  !  /| w  /  e |/  !  /
         /-----/-|---/-----|-----/--
        /  a  /  !  /  d  /| f  /    <--- Original keybindings
       /-----/-----/-----/-|---/--
      /  z  /  x  /  c  /  !  /
     /-----/-----/-----/-----/--
```

<!-- vim-markdown-toc GFM -->

* [Creating a layer](#creating-a-layer)
    * [`enter`, `layer` and `exit` tables](#enter-layer-and-exit-tables)
        * [`opts`](#opts)
            * [`expr`, `silent`, `desc`](#expr-silent-desc)
            * [`nowait`](#nowait)
    * [`config` table](#config-table)
        * [`on_enter` and `on_exit`](#on_enter-and-on_exit)
            * [meta-accessors](#meta-accessors)
        * [`on_key`](#on_key)
        * [`timeout`](#timeout)
        * [`buffer`](#buffer)
* [Global variable](#global-variable)
* [Layer object](#layer-object)
* [Make buffer unmodifiable while layer is active](#make-buffer-unmodifiable-while-layer-is-active)

<!-- vim-markdown-toc -->

## Creating a layer

A simple example for illustration of what is written below:

```lua
local Layer = require('hydra.layer')

local m = {'n', 'x'} -- modes
local side_scroll = Layer({
    enter = {
       {m, 'zl', 'zl'},
       {m, 'zh', 'zh'},
    },
    layer = {
       {m, 'l', 'zl'},
       {m, 'h', 'zh'},
    },
    exit = {
       {m, 'q'}
    },
    config = {
       on_enter = function()
          print("Enter layer")
          vim.bo.modifiable = false
       end,
       on_exit  = function() print("Exit layer") end,
       timeout = 3000, -- milliseconds
    }
})
```

---

To creat a new Layer object, you need to call constructor with input table with 4 next
fields:

```lua
local Layer = require('hydra.layer')

local layer = Layer({
   enter = {...},
   layer = {...},
   exit = {...}
   config = {...},
})
```

### `enter`, `layer` and `exit` tables

`enter`, `layer` and `exit` tables containes the keys to remap.
They all accept a list of keymappings, each of the form:
```lua
{mode, lhs, rhs, opts}
```
which is pretty-much compares to the signature of the `vim.keymap.set()` function with
some modifications.  `layer` table is mandatory, `enter` and `exit` tables are optional.
Key mappings in `enter` table are activate layer. Key mappings in `layer` and `exit`
tables become available only when layer is active. Mappings in `exit` table deactivate
layer.  If no one `exit` key was passed (`exit` table is empty), the `<Esc>` will be bind
by default.

The `rhs` of the mapping can be `nil`.
For `enter` and `exit` tables it means just to enter/exit the layer and doesn't do any
side job.  For `layer` table, it means to disable this key while layer is active
(internally it will be mapped to `<Nop>`).

**Note:** Only one Layer can be active at a time. The next one will stop the previous.

#### `opts`
`table`

`opts` table modifies the keymap behaviour and accepts the following keys:

##### `expr`, `silent`, `desc`
`boolean`

Built-in map arguments. See:

- `:help :map-<expr>`
- `:help :map-<silent>`
- [desc](https://www.reddit.com/r/neovim/comments/rt0zzh/comment/hqpxolg/?utm_source=share&utm_medium=web2x&context=3)

##### `nowait`
`boolean`

Layer binds its keymaps as buffer local.  This makes flag `nowait` awailable.
See `:help :map-<nowait>`.
This allows, for example bind exit key:

```lua
exit = {
    { 'n', 'q', nil, { nowait = true } }
}
```

which will exit layer, without waiting `&timeoutlen` milliseconds for possible continuation.

### `config` table

#### `on_enter` and `on_exit`
`function | function[]`

`on_enter`/`on_exit` is a function or list of function, that will be executed
on entering / exiting the layer.

##### meta-accessors

Inside the `on_enter` functions the `vim.o`, `vim.go`, `vim.bo` and `vim.wo`
[meta-accessors](https://github.com/nanotee/nvim-lua-guide#using-meta-accessors)
are redefined to work the way you think they should.  If you want some option to be
temporary changed while Layer is active, you need just set it with one of this
meta-accessor.  And thats it. All other will be done automatically in the backstage.


For example, temporary unset `modifiable` (local to buffer) option while Layer is active:
```lua
Layer({
   config = {
      on_enter = function()
         vim.bo.modifiable = false
      end
   }
})
```
And that's all, nothing more.

#### `on_key`
`function`

A function that will be executed **after** any layer key sequence will be pressed.

#### `timeout`
`boolean | number` (default: `false`)

The `timeout` option starts a timer for the corresponding amount of seconds milliseconds
that disables the layer.  Calling any layer key will refresh the timer.
If set to `true`, the timer will be set to `timeoutlen` option value (see `:help timeoutlen`).

#### `buffer`
`true | number`

Define layer only for particular buffer. If `true` — the current buffer will be used.

## Global variable

The active layer set `_G.active_keymap_layer` global variable, which contains the
reference to the active layer object. If no active layer, it is `nil`.
With it one layer checks if there is any other
active layer.  It can also be used for statusline notification, or anything else.

## Layer object

Beside constructor, Layer object has next public methods:

- `layer:activate()` : activate layer;
- `layer:exit()` : deactivate layer.

## Make buffer unmodifiable while layer is active

To disable the possibility to edit buffer while layer is active, you can either manually
unmap desired keys with next snippet:

```lua
local m = {'n', 'x'}

Layer({
    enter = {...},
    layer = {
        {m, 'i'},   {m, 'a'},   {m, 'o'},   {m, 's'},
        {m, 'I'},   {m, 'A'},   {m, 'O'},   {m, 'S'},
        {m, 'gi'},
        {m, '#I'},

        {m, 'c', nil, { nowait = true } },
        {m, 'C'},
        {m, 'cc'},

        {m, 'd',  nil, { nowait = true } },
        {m, 'D'},
        {m, 'x'},
        {m, 'X'},
        ...
    },
    exit = {...}
})
```

or disable `modifiable` option:
```lua
Layer({
   config = {
      on_enter = function()
         vim.bo.modifiable = false
      end,
   }
   ...
})
```

<!-- vim: set tw=90: -->
