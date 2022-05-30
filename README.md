## Create a hydra

If no `exit` key is specified, the `<Esc>` will be set by default.

## `config` table

### `pre` and `post`

You can specify code that will be called before hydra entering, and after hydra leave. For example:

### `exit`

The `exit` option is inherited by every head (they can override it) and influences what will happen
after executing head's command:

- `exit = nil` (the default) means that the hydra state will continue - you'll still see the hint
  and be able to use short bindings.
- `exit = true` means that the hydra state will stop.

### `foreign-keys`

The `foreign-keys` option belongs to the body and decides what to do when a key is pressed that doesn't
belong to any head:

- `foreign-keys = nil` (the default) means that the hydra state will stop and the foreign key will
  do whatever it was supposed to do if there was no hydra state.
- `foreign-keys = 'warn'` will not stop the hydra state, but instead will issue a warning without
  running the foreign key.
- `foreign-keys = 'run'` will not stop the hydra state, and try to run the foreign key.

### `color`

The `color` option is a shortcut for both `exit` and `foreign-keys` options and aggregates them in
the following way:

    | color    | toggle                             |
    |----------+------------------------------------|
    | red      |                                    |
    | blue     | exit = true                        |
    | amaranth | foreign-keys = 'warn'              |
    | teal     | foreign-keys = 'warn', exit = true |
    | pink     | foreign-keys = 'run'               |

It's also a trick to make you instantly aware of the current hydra keys that you're about to press:
the keys will be highlighted with the appropriate color.

**Note:** The `exit` and `foreign_keys` options are higher priority than `color` option and can't be
overridden by it. E.g: if manually set values of `exit` and `foreign_keys` options are contradicting
to the `color` option value, then thees values will be taken into account and for `color` the matching
value will be automatically set.

### `timeout`

The `timeout` option starts a timer for the corresponding amount of seconds that disables the hydra.
Calling any head will refresh the timer.

<!-- vim: set tw=100: -->
