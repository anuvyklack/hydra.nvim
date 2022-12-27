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
    * [Frequently used options](#frequently-used-options)
    * [More hydras](#more-hydras)
* [Installation](#installation)
* [How to create hydra](#how-to-create-hydra)
    * [`name`](#name)
    * [`mode`](#mode)
    * [`body`](#body)
    * [`config`](#config)
        * [`exit`](#exit)
        * [`foreign_keys`](#foreign_keys)
        * [`color`](#color)
            * [More about colors concept](#more-about-colors-concept)
            * [Amaranth color](#amaranth-color)
            * [Blue and teal colors](#blue-and-teal-colors)
            * [Pink color](#pink-color)
        * [`buffer`](#buffer)
        * [`invoke_on_body`](#invoke_on_body)
        * [`desc`](#desc)
        * [`on_enter` and `on_exit`](#on_enter-and-on_exit)
            * [meta-accessors](#meta-accessors)
        * [`on_key`](#on_key)
        * [`timeout`](#timeout)
        * [`hint`](#hint)
    * [Hydra's heads](#hydras-heads)
        * [`head`](#head)
        * [`rhs`](#rhs)
        * [`opts`](#opts)
            * [`private`](#private)
            * [`exit`](#exit-1)
            * [`exit_before`](#exit_before)
            * [`on_key`](#on_key-1)
            * [`desc`](#desc-1)
            * [`expr`, `silent`](#expr-silent)
            * [`nowait`](#nowait)
            * [`mode`](#mode-1)
    * [`hint`](#hint-1)
* [Public methods](#public-methods)
* [Highlight](#highlight)
* [Keymap utility functions](#keymap-utility-functions)
* [Statusline](#statusline)
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

[Link to the code](https://github.com/anuvyklack/hydra.nvim/wiki/Git)

![](https://user-images.githubusercontent.com/13056013/175947218-d1b70266-9964-48c9-aaae-75195501ef7e.png)

### Telescope menu

You can also create a fancy menu to easy recall seldom used mappings.

[Link to the code](https://github.com/anuvyklack/hydra.nvim/wiki/Telescope)

![](https://user-images.githubusercontent.com/13056013/179405895-b5206124-b091-42a4-ba5d-95bbc3e1b61b.png)


### Frequently used options

[Link to the code](https://github.com/anuvyklack/hydra.nvim/wiki/Vim-Options)

![](https://user-images.githubusercontent.com/13056013/179405898-190c609c-3474-4809-a59b-a11e6da4e4ed.png)


### More hydras

You can find more hydras in the [wiki](https://github.com/anuvyklack/hydra.nvim/wiki).
Feel free to add your own or edit the existing ones!

## Installation

To install with [packer](https://github.com/wbthomason/packer.nvim) use:

```lua
use 'anuvyklack/hydra.nvim' 
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
`string` (optional)

The name of the hydra. Not necessary, used only in auto-generated hint.

### `mode`
`string | string[]`\
default: `"n"`

Mode or modes in which this hydra will exist. Same format as `vim.keymap.set()` accepts.

### `body`
`string` (optional)

To summon the hydra you need to press in sequence keys corresponds to `body` + any `head`.
For example, if body is `z` and heads are: `a`, `b`, `c`, you can invoke hydra with any of
the `za`, `zb`, `zc` keybindings.

Hydra without body can only be summoned through `Hydra:activate()` method.

### `config`

`table`

With this table, you can set the behavior of the whole hydra, which later can be 
customized for each head particularly.  Below is a list of all options.

---

#### `exit`
`boolean`\
default: `false`\
parent table: `config`

The `exit` option (heads can override it) defines what will happen after executing head's
command:

- `exit = false` (the default) means that the hydra state will continue — you'll still see
  the hint and be able to use hydra bindings;
- `exit = true` means that the hydra state will stop.

#### `foreign_keys`
`"warn" | "run" | nil`\
default: `nil`\
parent table: `config`

The `foreign_keys` option belongs to the body and decides what to do when a key is pressed
that doesn't belong to any head:

- `foreign_keys = nil` (the default) means that the hydra state will stop and the foreign
  key will do whatever it was supposed to do if there was no hydra state.
- `foreign_keys = "warn"` will not stop the hydra state, but instead will issue a warning
  without running the foreign key.
- `foreign_keys = "run"` will not stop the hydra state, and try to run the foreign key.

#### `color`
`"red" | "amaranth" | "teal" | "pink"`\
default: `"red"`\
parent table: `config`

The `color` option is a shortcut for both `exit` and `foreign_keys` options and aggregates
them in the following way:

    | color    | toggle                             |
    |----------+------------------------------------|
    | red      |                                    |
    | blue     | exit = true                        |
    | amaranth | foreign_keys = 'warn'              |
    | teal     | foreign_keys = 'warn', exit = true |
    | pink     | foreign_keys = 'run'               |

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

Pink hydra is of a different nature. It is a [key-layer](https://github.com/anuvyklack/hydra.nvim/tree/master/lua/hydra/layer)
inside, so all keys except overwritten are work as usual. Even `[count]` prefixes.

#### `buffer`
`true | number`\
parent table: `config`

Define hydra only for particular buffer. If `true` — the current buffer will be used.

#### `invoke_on_body`

`boolean`\
default: `false`\
parent table: `config`

By default, to invoke the hydra you need to press in sequence keys corresponds to `body` +
any non-private `head` (about private heads see later).
This option allows you to summon hydra by pressing only the `body` keys.

#### `desc`

`string`\
default: `[Hydra]` + name \
parent table: `config`

If you set `invoke_on_body` option, then you can pass here the description for the hydra
body key sequence.

#### `on_enter` and `on_exit`
parent table: `config`

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

#### `on_key`
parent table: `config`

Function that will be called **after** every hydra head.

#### `timeout`
`boolean | number`
parent table: `config`

The `timeout` option set a timer after which the hydra will be automatically
disabled. Calling any head will refresh the timer. (see `:help timeout`, `:help timeoutlen`)

- `timeout = true` — enable timer and set its to `'timeoutlen'` option value;
- `timeout = false` — disabled timer: the hydra will wait as long as you want,
  until you manually cancel it;
- `timeout = 5000` — set timer to desired amount of milliseconds.

#### `hint`
`table | false`
parent table: `config`

If `false` — doesn't show hint. Or a table with settings for manually- or auto-generated
hint.

  - **`type`**   `"window" | "cmdline" | "statusline"`  (default: if hint passed: `"window"`, else: `"cmdline"`)

    - `"window"` — show hint in a floating window;

    - `"cmdline"` — show hint in a echo area;

    - `"statusline"` — show auto-generated hint in the statusline.  If hint is passed,
      then this value will be ignored and `"window"` will be used.

  - **`position`**   `string`   (default: `"bottom"`)\
    (valid when `type` is `"window"`)

    Set the position of the hint. Should be one from the next table:

    ```
      top-left   |   top    |  top-right
    -------------+----------+--------------
     middle-left |  middle  | middle-right
    -------------+----------+--------------
     bottom-left |  bottom  | bottom-right
    ```

  - **`offset`**  `number`   (default: `0`)\
    (valid when `type` is `"window"`)

    The offset from the nearest editor border.

  - **`border`**   `"single" | "double" | "rounded" | "solid" | "shadow" | "none" | string[]`  (default: `"none"`)\
    (valid when `type` is `"window"`)

    The border of the hint window. See `:help nvim_open_win()`

  - **`show_name`**   `boolean`   (default: `true`)

    Show hydras name or `HYDRA:` label at the beginning of an auto-generated hint.

  - **`funcs`**   `table<string, fun():string>`   ([built-in functions](https://github.com/anuvyklack/hydra.nvim/blob/master/lua/hydra/hint/vim-options.lua))

    Table where keys are function names and values are functions them self. Each
    function should return string. This functions can be required from `hint` with
    `%{func_name}` syntaxis.

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

##### `exit_before`
`boolean`

Like the previous option, stops hydra state but BEFORE executing a command corresponds to
head.

##### `on_key`
`boolean`

If `false` `config.on_key` function won't be executed after this head.

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

Only relevant for `pink` hydra. For all others will be skipped. The `pink` hydra is
a [layer](https://github.com/anuvyklack/hydra.nvim/tree/master/lua/hydra/layer) inside,
and Layer binds its keymaps buffer local, which makes flag `nowait` available. See `:help
:map-<nowait>`.

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

You can also create a Lua functions which returns a string and place it in
`config.hint.funcs` table under some key which will be used as a function name. Than
you can require this function from the `hint` wrap its name (key in the table) with
`%{...}`. The result of the function will be inserted in that place in the hint when it
will be shown. And later this function will be called every time when hydra head will be
pressed and the hint will be updated with the function result string. Some functions are
already built-in, you can find them in
[this file](https://github.com/anuvyklack/hydra.nvim/blob/master/lua/hydra/hint/vim-options.lua).
You may submit or request some others which you think may be useful.
The using of this feature is shown in [options hydra](https://github.com/anuvyklack/hydra.nvim/wiki/Vim-Options).

If you pass no `hint`, then one line hint will be generated automatically. The keys and
their descriptions will be placed in the order heads were passed in the `heads` table.
Heads with `desc = false` in `opts` table will be skipped.

Every head that won't be found in the manually created hint, will be automatically added
at the bottom of the hint window according to rules of auto generated hint.

## Public methods

- `Hydra:activate()` — a public method, which serves to activate hydra programmatically;
- `Hydra:exit()` — exit hydra if it is active.

## Highlight

Hydra defines next highlight groups with their defaults:

```
HydraRed        #FF5733
HydraBlue       #5EBCF6
HydraAmaranth   #ff1757
HydraTeal       #00a1a1
HydraPink       #ff55de
```

- `HydraHint` — linked to `NormalFloat`, defines the fore- and background of the hint window;
- `HydraBorder` —  linked to `FloatBorder`, defines the fore- and background of the border.

## Keymap utility functions

Utility functions to use in keymaps. Can be required from the next table:
```lua
require('hydra.keymap-util')
```

- `cmd(command)`

  Get a string and wrap it in `<Cmd>`, `<CR>`. I.e.: 
  ```
  cmd(vsplit)  ->  "<Cmd>vsplit<CR>"
  ```
  **param:**  `command` : `string`\
  **return:**  `string`

- `pcmd(try_cmd, catch?, catch_cmd?)`

  Protected `cmd`. Examples explain better:
  ```
  pcmd("wincmd k", "E11", "close")
  ->  "<Cmd>try | wincmd k | catch /^Vim\%((\a\+)\)\=:E11:/ | close | endtry<CR>"

  pcmd("wincmd k", nil, "close")
  ->  "<Cmd>try | wincmd k | catch | close | endtry<CR>"

  pcmd("close")
  ->  "<Cmd>try | close | catch | endtry<CR>"
  ```
  See: `:help exception-handling`

  **params:**

  * `try_cmd` : `string`
  * `catch` : `string` (optional) — String of the form `E` + some digits, like `E12` or `E444`.
  * `catch_cmd` : `string` (optional)

  **return:**  `string`

## Statusline

In the statusline module `require('hydra.statusline')` there are functions that can help
you to integrate Hydra in your statusline:

- `is_active()` — returns `true` if there is an active hydra;
- `get_name()` — get the name of an active hydra if it has it;
- `get_color()` — get the color of an active hydra;
- `get_hint()` — get an active hydra's statusline hint.  Return not `nil` only when
  `config.hint` is set to `false.`

## Drawbacks

`[count]` is not supported in a red, amaranth and teal hydras (see `:help count`).
But supported in pink hydra since it is a [layer](https://github.com/anuvyklack/hydra.nvim/tree/master/lua/hydra/layer).

## How it works under the hood

You can read about the internal mechanics in the [CONTRIBUTING](https://github.com/anuvyklack/hydra.nvim/blob/master/CONTRIBUTING.md)


<!-- vim: set tw=90: -->
