if exists("b:syntax_loaded") | finish | endif

" Conceal any of ^ _ \ if they not prepent with \, i.e if they not escaped.
syntax match HydraIgnore    '\\\@<![\^_\\]' conceal

let b:syntax_loaded = 1
