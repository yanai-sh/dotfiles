-- Feed zoxide whenever the CWD changes inside Yazi, so `z` in the shell
-- and `Z` in Yazi share one history. fzf is the picker Yazi already uses
-- for both that jump (`Z`) and subtree search (`z`).
require("zoxide"):setup({
	update_db = true,
})
