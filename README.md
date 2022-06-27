# Hydra.nvim

<!-- <img align="right" width="300" src="./hydra.png"> -->
<img align="right" width="300" src="https://user-images.githubusercontent.com/13056013/172239710-a18e3a2f-1b96-40f2-833e-c424f2962577.png">

<!--
<p align="center">
  <img width="200" src="./hydra.png">
</p>
-->

This is the Neovim implementation of the famous [Emacs Hydra](https://github.com/abo-abo/hydra)
package.

## Description for Poets

Once you summon the Hydra through the prefixed binding (the body + any one head), all
heads can be called in succession with only a short extension.

The Hydra is vanquished once Hercules, any binding that isn't the Hydra's head, arrives.
Note that Hercules, besides vanquishing the Hydra, will still serve his original purpose,
calling his proper command.  This makes the Hydra very seamless.

## Description for Pragmatics

Imagine you want to change the size of your current window. Vim allows you to do it with
`<C-w>+`, `<C-w>-`, `<C-w><`, `<C-w>>` bindings. So, you have to press
`<C-w>+<C-w>+<C-w>+<C-w><<C-w><<C-w><...` as many times as you need
(I know about count prefixes, but I was never fun of them).
Hydra allows you to press `<C-w>` just once and then get access to any `<C-w>...` bindings
without pressing the prefix again: `<C-w>+++++--<<<<`.
Or buffer side scrolling: instead of `zlzlzlzlzlzl...` press `zlllllllllhhhl` to freely
scroll buffer left and right. Any key other than bind to a hydra will stop hydra
state and do what they should.

Hydra also allows assigning a custom hint to such group of keybindings to allows you an
easy glance at what you can do.

If you want to quickly understand the concept, you can watch
[the original Emacs Hydra video demo](https://www.youtube.com/watch?v=_qZliI1BKzI)
<!-- (mabe I will create our own later :smile:). -->


<!-- vim-markdown-toc GFM -->

* [Sample Hydras](#sample-hydras)
    * [Side scroll](#side-scroll)
    * [Git submode](#git-submode)
    * [Telescope menu](#telescope-menu)
    * [Community wiki](#community-wiki)
* [Instalation](#instalation)
* [How to create hydra](#how-to-create-hydra)
    * [`name`](#name)
    * [`mode`](#mode)
    * [`body`](#body)
    * [`config`](#config)
        * [`exit`](#exit)
        * [`foreign-keys`](#foreign-keys)
        * [`color`](#color)
            * [More about colors concept](#more-about-colors-concept)
            * [Amaranth color](#amaranth-color)
            * [Blue and teal colors](#blue-and-teal-colors)
            * [Pink color](#pink-color)
        * [`buffer`](#buffer)
        * [`invoke_on_body`](#invoke_on_body)
        * [`on_enter` and `on_exit`](#on_enter-and-on_exit)
            * [meta-accessors](#meta-accessors)
        * [`timeout`](#timeout)
        * [`hint`](#hint)
    * [Hydra's heads](#hydras-heads)
        * [`head`](#head)
        * [`rhs`](#rhs)
        * [`opts`](#opts)
            * [`private`](#private)
            * [`exit`](#exit-1)
            * [`desc`](#desc)
            * [`expr`, `silent`](#expr-silent)
            * [`nowait`](#nowait)
            * [`mode`](#mode-1)
    * [`hint`](#hint-1)
* [Public methods](#public-methods)
* [Highlight](#highlight)
* [Drawbacks](#drawbacks)
* [How it works under the hood](#how-it-works-under-the-hood)

<!-- vim-markdown-toc -->
## Sample Hydras

### Side scroll

Simple hydra to scroll screen to the side with auto generated hint.

![](https://user-images.githubusercontent.com/13056013/174493857-eb30b9a9-9078-40f8-a076-bc290acc26bf.png)

```lua
local Hydra = require('hydra')

Hydra({
   name = 'Side scroll',
   mode = 'n',
   body = 'z',
   heads = {
      { 'h', '5zh' },
      { 'l', '5zl', { desc = '←/→' } },
      { 'H', 'zH' },
      { 'L', 'zL', { desc = 'half screen ←/→' } },
   }
})
```

### Git submode

A full fledged git "submode".

<!-- Finally, you can even create your custom submode, for example for git: -->

![](https://user-images.githubusercontent.com/13056013/175947218-d1b70266-9964-48c9-aaae-75195501ef7e.png)

<details> 
  <summary>Click this spoiler to see the code </summary>

The code is huge but, simple. For this hydra you need next plugins:

- [Gitsigns](https://github.com/lewis6991/gitsigns.nvim)
- [Neogit](https://github.com/TimUntersberger/neogit)

```lua
local Hydra = require('hydra')
local gitsigns = require('gitsigns')

local hint = [[
 _J_: next hunk   _s_: stage hunk        _d_: show deleted   _b_: blame line
 _K_: prev hunk   _u_: undo stage hunk   _p_: preview hunk   _B_: blame show full 
 ^ ^              _S_: stage buffer      ^ ^                 _/_: show base file
 ^
 ^ ^              _<Enter>_: Neogit              _q_: exit
]]

Hydra({
   hint = hint,
   config = {
      color = 'pink',
      invoke_on_body = true,
      hint = {
         position = 'bottom',
         border = 'rounded'
      },
      on_enter = function()
         vim.bo.modifiable = false
         gitsigns.toggle_signs(true)
         gitsigns.toggle_linehl(true)
      end,
      on_exit = function()
         gitsigns.toggle_signs(false)
         gitsigns.toggle_linehl(false)
         gitsigns.toggle_deleted(false)
         vim.cmd 'echo' -- clear the echo area
      end
   },
   mode = {'n','x'},
   body = '<leader>g',
   heads = {
      { 'J', function()
            if vim.wo.diff then return ']c' end
            vim.schedule(function() gitsigns.next_hunk() end)
            return '<Ignore>'
         end, { expr = true } },
      { 'K', function()
            if vim.wo.diff then return '[c' end
            vim.schedule(function() gitsigns.prev_hunk() end)
            return '<Ignore>'
         end, { expr = true } },
      { 's', ':Gitsigns stage_hunk<CR>', { silent = true } },
      { 'u', gitsigns.undo_stage_hunk },
      { 'S', gitsigns.stage_buffer },
      { 'p', gitsigns.preview_hunk },
      { 'd', gitsigns.toggle_deleted, { nowait = true } },
      { 'b', gitsigns.blame_line },
      { 'B', function() gitsigns.blame_line{ full = true } end },
      { '/', gitsigns.show, { exit = true } }, -- show the base of the file
      { '<Enter>', '<cmd>Neogit<CR>', { exit = true } },
      { 'q', nil, { exit = true, nowait = true } },
   }
})
```
</details>

### Telescope menu

You can also create a fancy menu to easy recall seldom used mappings.

![](https://user-images.githubusercontent.com/13056013/175949898-29c88460-1661-43f0-9c2d-61eb0cc7d663.png)

<details> 
  <summary>Click this spoiler to see the code </summary>
```lua
local Hydra = require('hydra')

local hint = [[
                 _f_: files       _m_: marks
   🭇🬭🬭🬭🬭🬭🬭🬭🬭🬼    _o_: old files   _g_: live grep
  🭉🭁🭠🭘    🭣🭕🭌🬾   _p_: projects    _/_: search in file
  🭅█ ▁     █🭐
  ██🬿      🭊██   _h_: vim help    _c_: execute command
 🭋█🬝🮄🮄🮄🮄🮄🮄🮄🮄🬆█🭀  _k_: keymap      _;_: commands history
 🭤🭒🬺🬹🬱🬭🬭🬭🬭🬵🬹🬹🭝🭙  _r_: registers   _?_: search history

                 _<Enter>_: Telescope           _<Esc>_ 
]]

Hydra({
   name = 'Telescope',
   hint = hint,
   config = {
      color = 'teal',
      invoke_on_body = true,
      hint = {
         position = 'middle',
         border = 'rounded',
      },
   },
   mode = 'n',
   body = '<Leader>f',
   heads = {
      { 'f', cmd 'Telescope find_files' },
      { 'g', cmd 'Telescope live_grep' },
      { 'h', cmd 'Telescope help_tags', { desc = 'Vim help' } },
      { 'o', cmd 'Telescope oldfiles', { desc = 'Recently opened files' } },
      { 'm', cmd 'MarksListBuf', { desc = 'Marks' } },
      { 'k', cmd 'Telescope keymaps' },
      { 'r', cmd 'Telescope registers' },
      { 'p', cmd 'Telescope projects', { desc = 'Projects' } },
      { '/', cmd 'Telescope current_buffer_fuzzy_find', { desc = 'Search in file' } },
      { '?', cmd 'Telescope search_history',  { desc = 'Search history' } },
      { ';', cmd 'Telescope command_history', { desc = 'Command-line history' } },
      { 'c', cmd 'Telescope commands', { desc = 'Execute command' } },
      { '<Enter>', cmd 'Telescope', { exit = true, desc = 'List all pickers' } },
      { '<Esc>', nil, { exit = true, nowait = true } },
   }
})
```
</details>


### Community wiki

You can find more hydras in the project's [community wiki](https://github.com/anuvyklack/hydra.nvim/wiki/Community-hydras).
Feel free to add your own or edit the existing ones.

## Instalation

To install with [packer](https://github.com/wbthomason/packer.nvim) use:

```lua
use { 'anuvyklack/hydra.nvim', 
    requires = 'anuvyklack/keymap-layer.nvim' -- needed only for pink hydras
}
```

## How to create hydra

To create hydra you need to call Hydra's constructor with input parameters table of the
next form:

```lua
local Hydra = require('hydra')
Hydra({
    name = "Hydra's name",
    hint = [[...]] -- multiline string
    config = {...}
    mode = 'n',
    body = '<leader>o',
    heads = {...},
})
```

Each of the fields of this table is described in details below.

### `name`
`string`

The name of the hydra. Not necessary, used only in auto-generated hint.

### `mode`
`string | string[]`     (default: `'n'`)

Mode or modes in which this hydra will exist. Same format as `vim.keymap.set()` accepts.

### `body`
`string`

To summon the hydra you need to press in sequence keys corresponds to `body` + any `head`.

For example, if body is `z` and heads are: `a`, `b`, `c`, you can invoke hydra with any of
the `za`, `zb`, `zc` keybindings.

### `config`

`table`

With this table, you can set the behavior of the whole hydra, which later can be 
customized for each head particularly.  Below is a list of all options.

---

#### `exit`
`boolean`

The `exit` option (heads can override it) defines what will happen after executing head's
command:

- `exit = false` (the default) means that the hydra state will continue — you'll still see
  the hint and be able to use hydra bindings;
- `exit = true` means that the hydra state will stop.

#### `foreign-keys`

The `foreign-keys` option belongs to the body and decides what to do when a key is pressed
that doesn't belong to any head:

- `foreign-keys = nil` (the default) means that the hydra state will stop and the foreign
  key will do whatever it was supposed to do if there was no hydra state.
- `foreign-keys = "warn"` will not stop the hydra state, but instead will issue a warning
  without running the foreign key.
- `foreign-keys = "run"` will not stop the hydra state, and try to run the foreign key.

#### `color`
`string`

The `color` option is a shortcut for both `exit` and `foreign-keys` options and aggregates
them in the following way:

    | color    | toggle                             |
    |----------+------------------------------------|
    | red      |                                    |
    | blue     | exit = true                        |
    | amaranth | foreign-keys = 'warn'              |
    | teal     | foreign-keys = 'warn', exit = true |
    | pink     | foreign-keys = 'run'               |

It's also a trick to make you instantly aware of the current hydra keys that you're about
to press: the keys will be highlighted with the appropriate color.

**Note:** The `exit` and `foreign_keys` options are higher priority than `color` option
and can't be overridden by it.  I.e, if manually set values of `exit` and `foreign_keys`
options contradict the color option value, then exactly thees values will be taken into
account and for `color` option the matching value will be automatically set

##### More about colors concept

Each hydra head has a basic associated color, red or blue, that determines whether or not
the hydra will continue after the head is called:

- red head will execute the command and continue the state
- blue head will execute the command and stop the state

They may have a reddish or a bluish face that isn't exactly red or blue, but that's what
they are underneath.

Overall, the hydra body can have one of five variants of the basic colors: amaranth, teal,
pink, red, blue.  They (according to basic color) determines the default behavior of
all the heads; and determines what happens when a key that is not associated to a
head is pressed. The following table summarizes the effects of the different colors.

| Body Color | Basic color | Executing NON-HEAD    | Executing HEAD |
|------------|-------------|-----------------------|----------------|
| amaranth   | red         | Disallow and Continue | Continue       |  
| teal       | blue        | Disallow and Continue | Quit           |  
| pink       | red         | Allow and Continue    | Continue       |  
| red        | red         | Allow and Quit        | Continue       |  
| blue       | blue        | Allow and Quit        | Quit           |  

##### Amaranth color

The amaranth color wasn't chosen by accident because it is the variation of the red color,
but it has the sense underneath. According to [Wikipedia](http://en.wikipedia.org/wiki/Amaranth):

> The word amaranth comes from the Greek word amaranton, meaning "unwilting" (from the
> verb marainesthai, meaning "wilt"). The word was applied to amaranth because it
> did not soon fade and so symbolized immortality.

Hydras with amaranth body are impossible to quit with any binding except a blue head.

##### Blue and teal colors

A blue hydra has little sense in Vim since it works exactly like standard Vim multi-key
keybinding with addition you can add a custom hint to it.

A teal hydra working the same way, except it blocks all other keys which are not hydra
heads, what can be useful.

##### Pink color

Pink hydra is of a different nature. It is a [key-layer](https://github.com/anuvyklack/keymap-layer.nvim)
inside, so all keys except overwritten are work as usual. Even `[count]` prefixes.

#### `buffer`
`true | number`

Define hydra only for particular buffer. If `true` — the current buffer will be used.

#### `invoke_on_body`

`boolean`   (default: `false`)

By default, to invoke the hydra you need to press in sequence keys corresponds to `body` +
any non-private `head` (about private heads see later).
This option allows you to summon hydra by pressing only the `body` keys.

<!-- When `true` invoke hydra when only `body` keys have been pressed. -->

#### `on_enter` and `on_exit`

Functions that will be called on enter and on exit hydra.

##### meta-accessors

Inside the `on_enter` functions the `vim.o`, `vim.go`, `vim.bo` and `vim.wo`
[meta-accessors](https://github.com/nanotee/nvim-lua-guide#using-meta-accessors)
are redefined to work the way you think they should.  If you want some option value to be
temporary changed while Hydra is active, you need just set it with one of this
meta-accessor in the `on_enter` function.  And that's it. No need to set it back in
`on_exit` function. All other will be done automatically in the backstage.

```lua
config = {
    on_enter = function()
       print('Hydra enter')
       vim.bo.modifiable = false  -- temporary set `nomodifiable` while Hydra is active
    end,
    on_exit = function()
       print('Hydra exit')
       -- No need to set modifiable back here
    end
}
```

#### `timeout`

The `timeout` option set a timer after which the hydra will be automatically
disabled. Calling any head will refresh the timer. (see `:help timeout`, `:help timeoutlen`)

- `timeout = true` — enable timer and set its to `'timeoutlen'` option value;
- `timeout = false` — disabled timer: the hydra will wait as long as you want,
  until you manually cancel it;
- `timeout = 5000` — set timer to desired amount of milliseconds.

#### `hint`
`table | 'window' | 'statusline' | false`

Configure the manually- or auto-generated hint.

- `'statusline'` — By default auto-generated hint is shown in a floating
  window above statusline.  When this option set, it will be shown in the statusline.;
- `false` — disable auto-generating hint;
- `{...}` — a table with settings for the manually created hint. Read about hint below.
   Accepts following keys:
  - **position**     `string`    (default: `"bottom"`)

    Set the position of the hint. Should be one from the next table:

    ```
      top-left   |   top    |  top-right
    -------------+----------+--------------
     middle-left |  middle  | middle-right
    -------------+----------+--------------
     bottom-left |  bottom  | bottom-right
    ```

  - **border**   `string`    (default: `'none'`)

    The border of the hint window. See `:help nvim_open_win()`

### Hydra's heads

Each hydra's head has the form:

```lua
{ head, rhs, opts }
```

which is pretty-much compares to the signature of the `vim.keymap.set()` function.

#### `head`
`string`

The `lhs` (left-hand-side) of the mapping, i.e the keys you press to call an action.

#### `rhs`
`string | function | nil`

Right-hand-side of the mapping.  Can be `nil` which means just do nothing, but if you also
want to pass `opts` table, you need to pass `nil` explicitly.

#### `opts`
`table`

A table with head options to tune its behavior.

##### `private`
`boolean`

When the hydra hides (not active), the private head does not bounce outside.
<!-- When the hydra hides, this head does not stick out.  -->
I.e., the private head is unreachable outside of the hydra state.

##### `exit`
`boolean`

Stop the hydra state after executing a command corresponds to such head.

**Note:** All exit heads are also private.

**Note:** If no `exit` head is specified, the `<Esc>` key will be set by default.

**Note:** Remind that `rhs` can be `nil`, so the pure escape head looks like this:
```lua
{ '<Esc>', nil, { exit = true } }
```

##### `desc`
`string | false`

The description that will be shown in the auto-generated part of the hint.
If `false` won't be show in the hint window

##### `expr`, `silent`
`boolean`

Built-in map arguments. See:

- `:help :map-<expr>`
- `:help :map-<silent>`

##### `nowait`
`boolean`

Only relevant for `pink` hydra. For all others will be skipped. The `pink` hydra is a
[layer](https://github.com/anuvyklack/keymap-layer.nvim) inside, and Layer binds its
keymaps buffer local, which makes flag `nowait` available. See `:help :map-<nowait>`.

This allows, for example bind exit key:

```lua
config = {
    color = 'pink',
}
...
heads = {
    { 'q', nil, { nowait = true } }
    ...
}
```

which will exit layer, without waiting `&timeoutlen` milliseconds for possible continuation.

##### `mode`
`string | string[]`

Overwrite `mode` field for this particular head.
Only relevant for `pink` hydra, for all others will be ignored.

### `hint`
`multiline string`

You can create any hint you wish. 

 horizontal | vertical
:----------:|:--------:
![](https://user-images.githubusercontent.com/13056013/174572353-ffa1961d-39ab-4b29-be31-f71196fc91cf.png) | ![](https://user-images.githubusercontent.com/13056013/174571913-898b4d23-393b-4bda-8358-44acf5ce9b71.png)

To highlight a key, just wrap it in underscores. Note that the key must belong to one of
the heads.  The key will be highlighted with the color that is appropriate to the behavior
of the key, i.e.  if the key will make the hydra exit, the color will be blue.

To insert an empty character, use `^`. It won't be rendered. The only use of it is to have
your code aligned as nicely as the result.

If you pass no `hint`, then one line hint will be generated automatically. The keys and
their descriptions will be placed in the order heads were passed in the `heads` table.
Heads with `desc = false` in `opts` table will be skipped.

Every head that won't be found in the manually created hint, will be automatically added
at the bottom of the hint window according to rules of auto generated hint.

## Public methods

- `Hydra:activate()` — a public method, which serves to activate hydra programmatically.

## Highlight

Hydra defines next highlight groups with their defaults:

```
HydraRed         #FF5733
HydraBlue        #5EBCF6
HydraAmaranth    #ff1757
HydraTeal        #00a1a1
HydraPink        #ff55de
HydraHint  link  NormalFloat
```

`HydraHint` defines the fore- and background of the hint window.

## Drawbacks

`[count]` is not supported in a red, amaranth and teal hydras (see `:help count`).
But supported in pink hydra since it is a [layer](https://github.com/anuvyklack/keymap-layer.nvim).

## How it works under the hood

You can read about the internal mechanics in the [CONTRIBUTING](https://github.com/anuvyklack/hydra.nvim/blob/master/CONTRIBUTING.md)


<!-- vim: set tw=90: -->
