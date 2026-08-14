-- Workaround: disable treesitter injections in snacks scope/indent
-- to avoid nil node error on Neovim 0.12.x

---@type LazySpec
return {
  "folke/snacks.nvim",
  opts = {
    scope = {
      treesitter = {
        injections = false,
      },
    },
  },
}
