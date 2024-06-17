local M = {}

M.link_colors = {
  LSPAIText = "Comment",
}

---Sets highlight groups
---@param ns_id integer
function M.set_hl(ns_id)
  for hl_group, link in pairs(M.link_colors) do
    vim.api.nvim_set_hl(ns_id, hl_group, {
      link = link,
      default = true,
    })
  end
end

return M
