# OneDiff — Performance Findings & Improvement Plan

## TL;DR

In Neovim every visible piece of text lives in a buffer (regular, scratch,
floating, popup — all buffers). There is **no lighter display primitive** than
a buffer. The buffer itself is not the bottleneck in `onediff` — the
**synchronous work around it** is.

If buffer-based rendering still feels slow after the fixes below, the only
real alternative is shelling out to `delta` / `diff-so-fancy` inside a
`:terminal` buffer — but that loses hunk-staging, treesitter highlighting,
and keymap interactivity, so it is strictly worse for this plugin's use case.

---

## Where the time actually goes

Per `display.render_current()` call (`nvim/lua/my_plugins/onediff/display.lua`)
and helpers in `nvim/lua/my_plugins/onediff/git_ops.lua`:

1. **3–4 blocking `io.popen` git calls.** `get_file_diff`,
   `get_staged_diff`, and frequently two more inside `is_binary_file`. Each
   one stalls the UI thread on `fork + exec + git`.
2. **`vim.fn.readfile(full_path)`** is synchronous and blocks the UI on
   large files.
3. **`vim.treesitter.start`** is invoked on every render and parses the
   entire buffer eagerly before the first paint.
4. **`apply_inline_diff` loops `nvim_buf_set_extmark` per changed line.**
   Fine for small diffs, expensive for diffs with thousands of changed
   lines.
5. **A new buffer is allocated on every render, and it's a *listed*
   buffer.** `open_file_with_diff` calls `nvim_create_buf(false, false)`
   each time the user switches files in the sidebar. That means a fresh
   allocation, the full `BufAdd` / `BufNew` autocmd cascade (statusline
   plugins, bufferline plugins, etc.), treesitter attach, then a
   `bufhidden=wipe` teardown on the next file. `open_binary_placeholder`
   and `render_deleted_file` already use `(false, true)` (scratch) — the
   main path should too, *and* the buffer should be reused across renders
   instead of recreated.
6. **`get_git_root()` runs on every call** (from `list_changed_files`,
   `get_current_content`, and elsewhere). It is a separate `git
   rev-parse` shell-out per invocation.
7. **Shell quoting in `git_ops.lua` uses `'%s'`** which is unsafe for paths
   containing single quotes or unusual characters. Switching to `vim.system`
   with an argv list fixes this *and* removes a `sh -c` layer.
8. **No upfront size gate.** The render path does the same work
   (`readfile` → treesitter → per-line extmarks) regardless of whether
   the file is 200 lines or 200 000 lines. A `vim.uv.fs_stat` check before
   reading lets the plugin pick a cheaper code path for pathologically
   large files instead of stalling Neovim.

---

## Improvements, in order of impact

### 1. Make git calls async with `vim.system`

Replace `io.popen` with `vim.system({...}, { text = true }, on_done)`. Fire
`git diff`, `git diff --cached`, and the binary-check in **parallel**, then
render in the callback when all have completed. This alone typically halves
perceived latency for the common case.

```lua
vim.system(
  { "git", "diff", base_ref, "--", file.path },
  { text = true },
  function(res)
    vim.schedule(function()
      -- render here
    end)
  end
)
```

Bonus: argv form avoids `sh -c` plus all the manual shell quoting in
`git_ops.lua`.

### 2. Read the file via `vim.uv` instead of `vim.fn.readfile`

`vim.fn.readfile` blocks until the entire file is in memory. Use libuv
async file IO so the UI thread keeps drawing while the file streams in.

```lua
vim.uv.fs_open(path, "r", 438, function(_, fd)
  vim.uv.fs_fstat(fd, function(_, stat)
    vim.uv.fs_read(fd, stat.size, 0, function(_, data)
      vim.uv.fs_close(fd)
      vim.schedule(function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(data, "\n"))
      end)
    end)
  end)
end)
```

### 3. Defer treesitter until after first paint

The user should see the diff highlights immediately; syntax can fade in a
frame later.

```lua
vim.schedule(function()
  pcall(vim.treesitter.start, buf, lang)
end)
```

Also cap treesitter by file size: skip it for very large buffers (e.g.
`> 10000` lines) and fall back to `vim.bo[buf].syntax = ft`. Treesitter
parsing is O(file size) and dominates render time on minified or generated
files.

### 4. Batch extmarks and skip off-screen lines

For huge diffs, only highlight the lines near the viewport on the initial
render, then install a `WinScrolled` autocmd that highlights newly visible
ranges on demand. The diff namespace (`settings.get_ns()`) is already
isolated, so partial population is safe and easy to reason about.

Also keep all `nvim_buf_set_extmark` calls inside a single
`vim.api.nvim_buf_call(buf, function() ... end)` to avoid repeated window
revalidation.

### 5. Use one reusable scratch buffer across renders

This is the technique Telescope and fzf-lua's builtin previewer both rely
on: a **single scratch buffer** that is wiped and refilled as the user
moves through the picker, rather than a fresh buffer per entry.

Two changes in one:

1. Switch the allocation from listed to scratch:

   ```lua
   local buf = vim.api.nvim_create_buf(false, true)
   ```

   You already set `buftype = "nofile"`, `bufhidden = "wipe"`, and
   `swapfile = false`, so scratch (`true`) is consistent and skips the
   listed-buffer autocmd cascade (`BufAdd`, `BufNew`, statusline /
   bufferline plugins).

2. Stop recreating the buffer on every render. Keep a single diff buffer
   on the session (`session.set_diff_buf` already exists), and on each
   `open_file_with_diff` just clear and refill it:

   ```lua
   local buf = session.get_diff_buf()
   if not buf or not vim.api.nvim_buf_is_valid(buf) then
     buf = vim.api.nvim_create_buf(false, true)
     session.set_diff_buf(buf)
   end
   vim.bo[buf].modifiable = true
   vim.api.nvim_buf_clear_namespace(buf, settings.get_ns(), 0, -1)
   vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
   ```

   Because `bufhidden = "wipe"` currently destroys the buffer when the
   window switches to another file, this needs to change to
   `bufhidden = "hide"` (or no value, with explicit cleanup in
   `display.clear_all`).

This removes one of the largest per-render costs when arrowing through
the sidebar: no allocation, no treesitter re-attach, no bufferline churn.

### 6. Add a `vim.uv.fs_stat` size gate

Stat the file before reading and pick a cheaper render path above a
threshold. Direct copy of Telescope's `buffer_previewer_maker` /
`preview.filesize_limit` strategy.

```lua
local SIZE_GATE_BYTES = 2 * 1024 * 1024  -- 2 MB
local LINE_GATE        = 50000

vim.uv.fs_stat(file.full_path, function(_, stat)
  vim.schedule(function()
    if stat and stat.size > SIZE_GATE_BYTES then
      -- huge file: skip treesitter, skip per-line extmarks,
      -- show a "diff too large — N changes" placeholder header,
      -- still render plain text + statusline summary.
      return render_oversize(file, hunks)
    end
    render_normal(file, hunks)
  end)
end)
```

Notes:

- Use byte size as the primary gate. Line count is only known after
  reading, so use it as a secondary cap inside `render_normal` if needed.
- The gate should **also** disable the per-line extmark loop in
  `apply_inline_diff` for oversize files — that loop is O(changed
  lines) and is the second-biggest cost after treesitter.
- The MIME-type check Telescope also does is **redundant** for OneDiff:
  `is_binary_file` already covers the binary case via `git diff
  --numstat` + a `\0` scan. Don't add a third process spawn for `file
  --mime-type`.

### 7. Cache `git rev-parse --show-toplevel`

The git root never changes during a session. Cache it on the `session`
module (which already exists at
`nvim/lua/my_plugins/onediff/session.lua`) and reuse on every subsequent
call. This removes one shell-out per file open.

### 8. Coalesce `is_binary_file` into the main diff call

`is_binary_file` currently runs **two** separate `git diff --numstat`
invocations before the real diff. The numstat info is already produced by
`list_changed_files` (`numstat_staged` / `numstat_unstaged`). Store the
binary flag on the file record at listing time and read it back instead of
re-shelling.

---

## What about non-buffer renderers?

Listed for completeness, all rejected for `onediff`:

- **Floating windows / popups** — still backed by a buffer; no perf win.
- **`:terminal` with `delta` / `diff-so-fancy`** — pretty output, but you
  lose treesitter, hunk staging, and per-line keymaps. Strictly worse for
  this plugin.
- **Image-based preview (`image.nvim`, Kitty graphics)** — orders of
  magnitude slower and non-interactive.
- **External TUI (e.g. `lazygit`, `gitui`)** — different product, not a
  rendering optimization.

---

## How Telescope and fzf-lua do file previews

Both are the reference implementations for "show a file fast in a floating
pane" in the Neovim ecosystem, so it's worth knowing exactly what they do
and which tricks apply to `onediff`.

### Telescope — `buffer_previewer`

Source: `lua/telescope/previewers/buffer_previewer.lua`.

- **One reusable scratch buffer per previewer instance.** As the user
  scrolls the picker, the same buffer is wiped and refilled — no
  `nvim_create_buf` per entry, no `BufAdd` / `BufNew` cascade.
- **Debounced updates.** Preview is not re-rendered on every cursor move;
  Telescope debounces selection changes before calling `define_preview`.
- **Timeout-guarded line splitting.** A modified `vim.split` checks elapsed
  time via `vim.uv.hrtime()` and bails out early if the preview budget
  (`opts.preview.timeout`, default ~250 ms) is exceeded. This prevents
  freezes on multi-MB files and huge single lines.
- **Size-gated previewing.** `buffer_previewer_maker` calls
  `vim.uv.fs_stat` first and skips files above a configurable byte limit
  (`preview.filesize_limit`).
- **MIME / binary detection** via `file --mime-type` to skip non-text files
  before reading them.
- **Filetype is set, not started.** Telescope writes `vim.bo[buf].filetype
  = ft` which lazily triggers syntax/treesitter through the FileType
  autocmd chain — but for the preview buffer, autocmds are disabled with
  `eventignore` so LSP / formatters / linters do not attach.
- **Known limitation:** the previewer still uses synchronous `io.popen` for
  the MIME check (`utils.capture`), which can freeze Neovim on slow
  filesystems (issue #3389). A pending PR (#3261) switches the hot loop
  off `vim.gsplit` for ~4–5× faster line splitting on large files.

### fzf-lua — two completely different modes

fzf-lua is the more interesting case because it has **two preview
backends**, and one of them is the closest thing to a "non-buffer" preview
you can get inside an editor.

#### 1. `previewer = 'builtin'` (the default in modern fzf-lua)

Effectively the same architecture as Telescope:

- A single reused Neovim **floating window + scratch buffer** rendered next
  to fzf.
- Communicates with the running fzf process over **RPC via a headless
  `nvim --headless` instance + named pipe**. When fzf needs a preview, it
  spawns `shell_helper.lua`, which connects back to the main Neovim
  instance and pulls the buffer contents.
- The headless-RPC layer is the main reason builtin feels less snappy than
  fzf-native — every preview pays a process-spawn + RPC round-trip cost.
- fzf itself adds a **100 ms preview debounce** that you cannot fully
  eliminate (you can lower it with `winopts.preview.delay = 0` but fzf's
  internal coalescing remains).

#### 2. `previewer = 'bat_native'` / `'git_diff'` / shell-command native

This is the architecturally different one:

- **No Neovim buffer is involved at all.** fzf is told to run a shell
  command (e.g. `bat --color=always --style=numbers,changes {file}` or
  `git diff -- {file} | delta`) and pipe its **ANSI-colored stdout
  directly to fzf's own preview pane**.
- Rendering is done by the **terminal emulator**, not by Neovim. No
  treesitter, no extmarks, no autocmds, no RPC.
- This is genuinely faster than any buffer-based approach on huge files
  because there is no parse, no highlight pass, and no Neovim event loop
  in the hot path — fzf just streams bytes.
- For diffs specifically, fzf-lua's `git_status` / `git_diff` pickers
  auto-detect `delta` on `$PATH` and pipe through it, giving high-quality
  diff highlighting essentially for free.
- The trade-off is total loss of interactivity inside the preview: no
  cursor, no keymaps on the previewed content, no per-line actions.

### What's transferable to `onediff`

Picking the techniques that apply to a hunk-stageable, interactive diff
viewer:

| Technique | Source | Applicable to OneDiff? |
| --- | --- | --- |
| Reuse one scratch buffer across renders | Both | **Yes** — currently a new buffer is created per `open_file_with_diff`. Reuse the buffer stored on `session.set_diff_buf` and just `nvim_buf_set_lines` into it. |
| Debounce preview update | Both | Partial — `render_current` isn't fired on cursor move, but the sidebar's "jump-while-arrowing" navigation could debounce by ~50 ms. |
| Timeout-guarded splitting | Telescope | **Yes** — for very large files cap the work in `vim.split` and bail out with a "diff too large" placeholder. |
| `vim.uv.fs_stat` size gate | Telescope | **Yes** — skip inline highlighting (or skip preview entirely) for files above N bytes. |
| MIME / binary check before read | Telescope | **Already done** in `is_binary_file`, but currently via two synchronous git calls — async-ify them. |
| Set `filetype` instead of calling `treesitter.start` directly | Telescope | Optional — your current treesitter call already avoids `FileType` autocmds via `eventignore`-equivalent skipping. Keep, but defer (see fix #3). |
| `eventignore` while populating | Both | **Yes** — wrap the buffer-fill in `vim.opt.eventignore:append("FileType,BufRead,BufReadPost")` or use `noautocmd` so plugins don't attach to the preview. |
| RPC / headless preview | fzf-lua | **No** — fzf-lua only needs it because fzf is a separate process. OneDiff runs in-process, so this is overhead, not optimization. |
| Native fzf shell-pipe preview | fzf-lua | **No (in current form)** — would mean rendering inside `:terminal` with `delta`, losing hunk staging. Could be added as an **optional read-only "fast preview" mode** for files above a size threshold (e.g. > 5 MB or > 50k lines) where interactivity is not useful anyway. |

### Remaining Telescope/fzf-lua tricks worth borrowing

The two big ones (reusable scratch buffer, `fs_stat` size gate) are now in
the main improvements list as #5 and #6. What's left from the research:

1. **Wrap the fill phase in `noautocmd`.** Either `vim.cmd("noautocmd
   ...")` or temporarily set `vim.opt.eventignore` while populating the
   buffer. Prevents LSP / formatters / bufferline plugins from reacting
   to the preview buffer. Small but free win.
2. **Optional escape hatch: "fast mode" `:terminal` preview** using
   `git diff <ref> -- <path> | delta --paging=never` for files / diffs
   above the size gate. Bind it to a separate keymap so the default path
   stays fully interactive — only used when interactivity isn't useful
   anyway (very large files).

---

## Suggested execution order

1. Async-ify `git_ops.lua` with `vim.system` (#1, #8).
2. Cache git root on the session (#7).
3. Reusable scratch buffer across renders (#5).
4. `fs_stat` size gate + oversize fallback path (#6).
5. Defer treesitter + size cap (#3).
6. Async file read via `vim.uv` (#2).
7. Viewport-bounded extmark population (#4).

Steps 1–4 are mechanical and give the largest perceived speedup
(async git + no buffer churn + bounded work on huge files). Steps 5–7
matter mainly for very large files / diffs.
