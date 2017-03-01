#Pkg.add("GZip")
#Pkg.add("Glob")
#Pkg.add("JSON")
#Pkg.add("PyCall")

# using PyCall

const PUNCTUACTION = ";:,.@#&\\-\"'/:*"
const SYMBOLS = "()[]¿?¡!{}~<>|"
const SKIP_SYMBOLS = string(PUNCTUACTION, SYMBOLS)
const BLANK = ' '
# SKIP_WORDS = set(["…", "..", "...", "...."])

type TextConfig
    lc::Bool
    del_diac::Bool
    del_dup::Bool
    del_punc::Bool
    del_num::Bool
    del_url::Bool
    qlist::Vector{Int}
    nlist::Vector{Int}
end

TextConfig() = TextConfig(true, true, false, false, true, true, [], [1])
TextConfig(qlist, nlist) = TextConfig(true, true, false, false, true, true, qlist, nlist)

function save(ostream, config::TextConfig)
    write(ostream, JSON.json(config), '\n')
end

function load(istream, ::Type{TextConfig})
    obj = TextConfig()
    line = readline(istream)
    
    for (k, v) in JSON.parse(line)
        if k in ("qlist", "nlist")
            v = Int[x for x in v]
        end
        setfield!(obj, Symbol(k), v)
    end

    obj
end

function normalize_text(text::String, config::TextConfig)::Vector{Char}
    if config.lc
        text = lowercase(text)
    end

    if config.del_url
        text = replace(text, r"(http|ftp|https)://\S+", s"")
    end

    L = Char[BLANK]
    prev = BLANK

    for u in normalize_string(text, :NFD)
        if config.del_diac
            o = Int(u)
            0x300 <= o && o <= 0x036F && continue
        end

        if u in ('\n', '\r', ' ', '\t')
            u = BLANK
        elseif config.del_dup && prev == u
            continue
        elseif config.del_punc && u in SKIP_SYMBOLS
            prev = u
            continue
        elseif config.del_num && isdigit(u)
            continue
        end

        prev = u
        push!(L, u)
    end
    push!(L, BLANK)

    L
end

function text_tokens(text::Vector{Char})
    n = length(text)
    L = String[]
    W = Char[]
    for i in 1:n
        c = text[i]
        
        c in SKIP_SYMBOLS && continue
        
        if c == BLANK
            length(W) == 0 && continue
            
            push!(L, W |> join)
            W = Char[]
        else
            push!(W, c)
        end
    end
    
    length(W) > 0 && push!(L, W |> join)
    return L
end

function expand_tokens(text::String, config::TextConfig)
    expand_tokens(normalize_text(text, config), config)
end

function expand_tokens(text::Vector{Char}, config::TextConfig)
    n = length(text)
    L = String[]

    for q in config.qlist
        for i in 1:(n - q + 1)
            w = text[i:i+q-1] |> join
            push!(L, w)
        end
    end
    
    if length(config.nlist) > 0
        ltext = text_tokens(text)
        n = length(ltext)
        
        for q in config.nlist
            for i in 1:(n - q + 1)
                wl = ltext[i:i+q-1]
                push!(L, join(wl, BLANK))
            end
        end
    end
    
    L
end
