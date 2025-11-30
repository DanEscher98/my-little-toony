# rainbow-toon

Neovim plugin for [TOON (Token-Oriented Object Notation)](https://github.com/toon-format/spec) with rainbow column highlighting for tabular arrays.

## Features

- **Syntax highlighting** via [tree-sitter-toon](https://github.com/DanEscher98/tree-sitter-toon)
- **Rainbow column highlighting** for tabular arrays (10-color cycling palette)
- **Column alignment** with `:RainbowToonAlign`
- **JSON to TOON conversion** with `:RainbowJson2Toon`
- **Token counter** statusline component showing GPT token count (via [gpt-tokenizer](https://www.npmjs.com/package/gpt-tokenizer))
- **Filetype detection** for `.toon` files
- **Editor settings** optimized for TOON (2-space indentation)

## Requirements

- Neovim 0.9+
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

## Installation

### lazy.nvim

```lua
{
  'DanEscher98/rainbow-toon',
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  config = function()
    require('rainbow-toon').setup()
  end,
  ft = { 'toon', 'json' },  -- Load on both TOON and JSON files
}
```

### packer.nvim

```lua
use {
  'DanEscher98/rainbow-toon',
  requires = { 'nvim-treesitter/nvim-treesitter' },
  config = function()
    require('rainbow-toon').setup()
  end,
  ft = { 'toon', 'json' },  -- Load on both TOON and JSON files
}
```

### Manual

Clone to your Neovim packages directory:

```bash
git clone https://github.com/DanEscher98/rainbow-toon \
  ~/.local/share/nvim/site/pack/plugins/start/rainbow-toon
```

## Parser Installation

After installing the plugin, install the tree-sitter parser using one of these methods:

### Option 1: Via nvim-treesitter (Recommended)

```vim
:TSInstall toon
```

### Option 2: Via npm

If `:TSInstall toon` doesn't work, you can install the parser from npm and let nvim-treesitter compile it:

```bash
npm install -g @danyiel-colin/tree-sitter-toon
```

Then in Neovim, run:

```vim
:lua require('rainbow-toon').install_parser()
```

This will automatically configure and install the parser from the npm package.

### Option 3: Manual Installation

Build from source: [tree-sitter-toon](https://github.com/DanEscher98/tree-sitter-toon).

## Commands

| Command | Description | Filetype |
|---------|-------------|----------|
| `:RainbowToonEnable` | Enable rainbow column highlighting | toon |
| `:RainbowToonDisable` | Disable rainbow column highlighting | toon |
| `:RainbowToonToggle` | Toggle rainbow column highlighting | toon |
| `:RainbowToonAlign` | Align tabular array columns | toon |
| `:RainbowToonShrink` | Remove extra whitespace from columns | toon |
| `:RainbowToonTokens` | Enable token counter display | toon |
| `:RainbowToonTokensOff` | Disable token counter display | toon |
| `:RainbowToonTokensToggle` | Toggle token counter display | toon |
| `:RainbowJson2Toon` | Convert JSON to TOON (auto-saves) | json |
| `:RainbowJson2Toon!` | Convert JSON to TOON (no auto-save) | json |

## Configuration

```lua
require('rainbow-toon').setup({
  -- Enable rainbow column highlighting (default: true)
  rainbow_columns = true,

  -- Auto-enable on TOON files (default: true)
  auto_enable = true,

  -- Align tabular columns on save (default: false)
  align_on_save = false,

  -- Color palette for rainbow columns
  colors = {
    '#E06C75', -- red
    '#98C379', -- green
    '#E5C07B', -- yellow
    '#61AFEF', -- blue
    '#C678DD', -- purple
    '#56B6C2', -- cyan
    '#D19A66', -- orange
    '#ABB2BF', -- white
    '#BE5046', -- dark red
    '#7EC699', -- light green
  },

  -- Use named highlight groups instead of explicit colors
  -- (better for colorscheme compatibility)
  use_highlight_groups = false,
  highlight_groups = {
    'RainbowColumn1',
    'RainbowColumn2',
    'RainbowColumn3',
    'RainbowColumn4',
    'RainbowColumn5',
    'RainbowColumn6',
    'RainbowColumn7',
    'RainbowColumn8',
    'RainbowColumn9',
    'RainbowColumn10',
  },

  -- Token counter configuration (statusline component)
  token_counter = {
    enabled = false,           -- Auto-enable on TOON files
    debounce_ms = 500,         -- Delay before recounting
    format = '%d tokens',      -- Statusline format
    counting_format = '...',   -- Shown while counting
  },
})
```

## Example

TOON file with tabular array:

```toon
users[3]{id,name,role,active}:
  1,Alice,admin,true
  2,Bob,developer,true
  3,Charlie,designer,false
```

With rainbow highlighting, each column (`id`, `name`, `role`, `active`) gets a distinct color.

Use `:RainbowToonAlign` to align columns:

```toon
users[3]{id,name,role,active}:
  1, Alice,   admin,    true
  2, Bob,     developer, true
  3, Charlie, designer, false
```

## JSON to TOON Conversion

Open a JSON file and run `:RainbowJson2Toon` to convert it to TOON format:

**Input (users.json):**
```json
{
  "users": [
    {"id": 1, "name": "Alice", "role": "admin", "active": true},
    {"id": 2, "name": "Bob", "role": "developer", "active": true}
  ]
}
```

**Output (users.toon):**
```toon
users[2]{active,id,name,role}:
  true, 1, Alice, admin
  true, 2, Bob, developer
```

The converter automatically:
- Detects tabular arrays (objects with same keys) and uses compact `[N]{fields}:` format
- Chooses appropriate delimiters (comma, pipe, or tab) based on content
- Opens the result in a vertical split
- Saves to `<filename>.toon` (use `!` to skip auto-save)

## Token Counter

Show GPT token count in your statusline. Useful for staying within context limits when preparing data for LLMs.

### Setup

1. Install the tokenizer package:

```bash
npm install -g gpt-tokenizer
```

2. Enable the token counter:

```lua
require('rainbow-toon').setup({
  token_counter = {
    enabled = true,  -- Auto-enable on TOON files
  },
})
```

Or enable it manually with `:RainbowToonTokens`.

3. Add to your statusline. The module provides a `statusline()` function:

**lualine.nvim:**
```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      { require('rainbow-toon.token-counter').statusline },
      'encoding', 'fileformat', 'filetype'
    },
  },
})
```

**Native statusline:**
```lua
vim.o.statusline = '%f %m%=%{v:lua.require("rainbow-toon.token-counter").statusline()} %l:%c'
```

The counter updates automatically as you edit, with debouncing to avoid performance issues.

## Related

- [tree-sitter-toon](https://github.com/DanEscher98/tree-sitter-toon) - Tree-sitter grammar for TOON
- [toon-spec](https://github.com/toon-format/spec) - Official TOON specification

## License

MIT
