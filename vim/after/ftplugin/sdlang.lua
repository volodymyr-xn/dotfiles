-- SDLang accepts //, #, -- and /* */; `//` is what dub.sdl uses.
vim.opt_local.commentstring = "// %s"
vim.opt_local.comments = "s1:/*,mb:*,ex:*/,:--,://,:#"
