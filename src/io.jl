#Pkg.add("GZip")
#Pkg.add("Glob")
#Pkg.add("JSON")

import GZip
import JSON

function iterlines(fun, filename; maxlines=typemax(Int))
    if endswith(filename, ".gz")
        f = GZip.open(filename)
        i = 0
        while !eof(f) && i < maxlines
            line = readline(f)
            i += 1
            if length(line) == 0
                continue
            end
            fun(line)
        end
        close(f)
    else
        open(filename) do f
            i = 0
            while !eof(f) && i < maxlines
                line = readline(f)
                i += 1
                fun(line)
            end
        end
    end
end

function parsetweet(line)
    if line[1] == '{'
        tweet = JSON.parse(line)
    else
        key, value = split(line, '\t', limit=2)
        tweet = JSON.parse(value)
        tweet["key"] = key
    end

    tweet
end

function itertweets(fun, filename::String; maxlines=typemax(Int))
    iterlines(filename, maxlines=maxlines) do line
        tweet = parsetweet(line)
        fun(tweet)
    end
end

function itertweets(fun, file; maxlines=typemax(Int))
    i = 0
    while !eof(file) && i < maxlines
        line = readline(file)
        i += 1
        try
            tweet = parsetweet(line)
            fun(tweet)
        catch
            continue
        end
    end
end

function getkeypath(dict, key)
    if contains(key, ".")
        v = dict
        for k in split(key, '.')
            v = v[k]
        end

        return v
    else
        return dict[key]
    end
end

function savepath{T}(filename::String, obj::T)
    d = dirname(filename)
    !isdir(d) && mkpath(d)

    open(filename, "w") do f
        save(f, obj)
    end
end

function loadpath{T}(filename::String, ::Type{T})
    return open(filename) do f
        load(f, T)
    end
end


function loaddatabase(filename)
    db = DocumentType[]
    if filename == "-"
        while !eof(f)
            push!(db, load(STDIN, DocumentType))
        end
    else
        open(filename) do f
            while !eof(f)
                push!(db, load(f, DocumentType))
            end
        end
    end

    db
end

function loadindex(args)
    local index
    env = args["env"]
    indexpath = joinpath(env, "index")
    if isfile(indexpath)
        open(indexpath) do f
            index = load(f, LocalSearchIndex, DocumentType, CosineDissimilarity(), loaditems=false)
        end

        open(joinpath(env, "db")) do f
            load(f, index)
        end
        return index
    else
        index = LocalSearchIndex(DocumentType, CosineDissimilarity(), recall=args["recall"], k=args["knn"])
    end

    index.neighborhood_algo = LogSatNeighborhood(1.1)
    index
end


function saveindex(args, index, fastlinks)
    env = args["env"]
    open(joinpath(env, "index"), "w") do f
        save(f, index, saveitems=false)
    end

    open(joinpath(env, "fastlinks"), "w") do f
        for fastlink in fastlinks
            save(f, fastlink)
        end
    end
end
