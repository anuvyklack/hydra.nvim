# How does it work

Every hydra (except pink) is an infinite chain of `<Plug>(...)` kyebindings.

To enter Hydra used

```lua
keymap.set(body..lhs, table.concat{
   '<Plug>(hydra_enter)',
   '<Plug>(hydra_lhs)',
   '<Plug>(hydra_wait)'
})
```

Then for every red (non-exiting) head the next binding used:
```lua
keymap.set('<Plug>(hydra_wait)'..lhs, table.concat{
   '<Plug>(hydra_lhs)',
   '<Plug>(hydra_wait)'
})
```

Blue (exiting) head:
```lua
keymap.set('<Plug>(hydra_wait)'..lhs, table.concat{
   '<Plug>(hydra_exit)',
   '<Plug>(hydra_lhs)'
})
```

And to correctly exit from hydra, next bindings are set:

```lua
keymap.set('<Plug>(hydra_wait)', '<Plug>(hydra_leave)')
```

```lua
keymap.set('<Plug>(hydra_wait)'..<the first N keys in lhs>,
   '<Plug>(hydra_leave)'
)
```

So the infinite chain of the form
```
<Plug>(hydra_enter)
<Plug>(hydra_lhs)
<Plug>(hydra_wait)
<Plug>(hydra_lhs)
<Plug>(hydra_wait)
...
<Plug>(hydra_wait)
<Plug>(hydra_exit)
<Plug>(hydra_lhs)
```
comes out.

Every head's mapping ends with `<Plug>(hydra_wait)`, and since there are exist
keymaps that starts with it, Vim is waiting for possible continuation.
Pressing any non-head key at this moment will execute:
```
<Plug>(hydra_wait) --> <Plug>(hydra_leave)
```
`<Plug>(hydra_leave)` will check the hydra's color and if hydra is amaranth or teal
it will consume the pressed key and send `<Plug>(hydra_wait)`. Otherway it will
execute `<Plug>(hydra_exit)` after which the pressed  key will be executed.
