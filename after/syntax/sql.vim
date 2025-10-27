" BigQuery SQL syntax enhancements
"
" Backtick-quoted identifiers for table names
syntax region sqlBacktickIdentifier start=/`/ end=/`/ oneline containedin=ALL
" highlight color for backtick-quoted idnetifiers
highlight default sqlBacktickIdentifier guifg=#98c379 ctermfg=114
