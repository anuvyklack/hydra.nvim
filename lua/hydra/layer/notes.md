# Notes about the internal structure of the code

## How key mappings stores inside

The Layer accepts keymaps in the one form, but stores them internally in the another. 
The `Layer:_normalize_input()` method is responsible for this.  It allows utilize built-in
Lua table properties, and simplifies such things like get desired normal mode keybinding
without looping through the whole list every time.

```
    -----------------------------+------------------------------------
               Input             |              Internal
    -----------------------------+------------------------------------
                                 |
       {mode, lhs, rhs, opts}    |    mode = { lhs = {rhs, opts} }
                                 |
    -----------------------------+------------------------------------
                                 |
                                 |      enter_keymaps = {
                                 |         n = {
       enter = {                 |            zl = {'zl', {}},
          {'n', 'zl', 'zl'},     |            zh = {'zh', {}},
          {'n', 'zh', 'zh'},     |            gz = {'<Nop>', {}}
          {'n', 'gz'},           |         }
       },                        |      },
       layer = {                 |      layer_keymaps = {
          {'n', 'l', 'zl'},      |         n = {
          {'n', 'h', 'zh'},      |            l = {'zl', {}},
       },                        |            h = {'zh', {}}
       exit = {                  |         }
          {'n', '<Esc>'},        |      },
          {'n', 'q'}             |      exit_keymaps = {
       }                         |         n = {
                                 |            ['<Esc>'] = {'<Nop>', {}},
                                 |            q = {'<Nop>', {}}
                                 |         }
                                 |      }
                                 |
```

## Dealing with original key mappings

The Layer class setup its keybindings as buffer local (except those to activate the layer).
This, among other things, allows the use of the `<nowait>` keymap option.

On activating, Layer sets its keymaps for the current buffer, and while active, for all
visited buffers.  Original key mappings, overwritten by Layer, are putted into
`self.saved_keymaps[bufnr]` table.  On deactivating Layer, the buffer local key bindings
are restoring where they were for all buffers that are still "listed". 

`self.saved_keymaps` table has the next structure:

``` lua
    self.saved_keymaps = {
       3 = { -- bufnr
          n = { -- normal mode
             l = true,
             h = {...},
             ['<Esc>'] = true,
             q = true,
          }
       }
       127 = { -- bufnr
          n = { -- normal mode
             l = true,
             h = {...},
             ['<Esc>'] = true,
             q = true,
          }
       }
    }
```

- `3` and `127` are buffer numbers for which buffer local mappings are stored;
- `{...}` denotes existing keymap stored for future restore;
- `true` is a placeholder, denotes that there is no specific keymap map for this lhs.

<!-- vim: set tw=90: -->
