# push!(LOAD_PATH, ".")
import JSON
using NNS
using ArgParse
import NNS.save, NNS.load

include("src/io.jl")
include("src/textmodel.jl")
include("src/tfidf.jl")
include("src/diskdata.jl")

function create_model(args)
    if length(args["qlist"]) > 0
        qlist = parse.(split(args["qlist"], ','))
    else
        qlist = []
    end

    if length(args["nlist"]) > 0
        nlist = parse.(split(args["nlist"], ','))
    else
        nlist = []
    end
    
    key = args["key"]
    input = args["input"]

    corpus = Vector{String}()
    itertweets(input == "-" ? STDIN : input) do tweet
        push!(corpus, tweet[key])
    end

    
    model = TfidfModel(corpus, TextConfig(qlist, nlist))
    path = joinpath(args["env"], "model")
    savepath(path, model)
end

function convert_database(args)
    model = loadpath(joinpath(args["env"], "model"), TfidfModel)
    input = args["input"]
    output = args["output"]
    out = output == "-" ? STDOUT : open(output, "w")
    key = args["key"]
    itertweets(input == "-" ? STDIN : input) do tweet
        save(out, vectorize(tweet[key], model))
    end
    
    output != "-" && close(out)
end


### index related functions
function set_locality_oracle_handler(args, index, model)
    env = args["env"]
    fastlinks = KnnResult[]
    filename = joinpath(env, "fastlinks")
    if isfile(filename)
        open(filename) do f
            while !eof(f)
                links = load(f, KnnResult)
                push!(fastlinks, links)
            end
        end
    else
        num = args["fastlinks"]
        for i in 1:length(model.voc)
            push!(fastlinks, KnnResult(num))
        end
    end

    function locality_oracle(q::DocumentType)::Vector{Int32}
        L = Int32[]
        for term in q.terms
          for p in fastlinks[term.id]
            push!(L, p.objID)
          end
        end
        L
    end

    index.locality_oracle = locality_oracle
    fastlinks
end

function append_index(args)
    env = args["env"]
    key = args["key"]
    model = loadpath(joinpath(env, "model"), TfidfModel)
    index = loadindex(args)
    fastlinks = set_locality_oracle_handler(args, index, model)
    input = args["database"]
    wcorpus = DiskWriter(joinpath(env, "corpus"))
    fdb = open(joinpath(env, "db"), "a")
    istream = input == "-" ? STDIN : open(input)
    count = 0
 
    while !eof(istream)
        line = readline(istream)
        tweet = parsetweet(line)
        v = vectorize(tweet[key], model)
        length(v.terms) == 0 && continue
        links = push!(index, v)
        count += 1
	save(fdb, v)
        save(fdb, links)
        push!(wcorpus, line)
        if log(2, count) % 1 == 0
            info("saving a snapshot of the index")
            flush(fdb)
            flush(wcorpus)
            saveindex(args, index, fastlinks)
        end

        objID = length(index.db) |> Int32

        for i in 1:length(v.terms)
            termID = v.terms[i].id
            push!(fastlinks[termID], objID, -v.terms[i].weight)
        end
    end
    
    input != "-" && close(istream)
    close(wcorpus)
    close(fdb)
    saveindex(args, index, fastlinks)
end

function search_index(args)
    env = args["env"]
    key = args["key"]

    index = loadindex(args)
    model = loadpath(joinpath(env, "model"), TfidfModel)
    fastlinks = set_locality_oracle_handler(args, index, model)

    k = args["knn"]
    if args["opt-recall"] > 0
        _k = args["opt-knn"] > 0 ? args["opt-knn"] : k
        _db = args["opt-queries"] == "" ? index.db : loaddatabase(args["opt-queries"])
        perf = Performance(_db, index.dist)
        optimize!(index, recall=args["opt-recall"], k=_k, perf=perf)
    end

    # t = time()
    raw_output = args["raw-output"]
    rcorpus = DiskReader(joinpath(env, "corpus"))
    input = args["queries"]
    istream = input == "-" ? STDIN : open(input)

    while !eof(istream)
        tweet = readline(istream) |> parsetweet
        q = vectorize(tweet[key], model)
        if length(q.terms) == 0
            warn("no terms were found:", tweet[args["key"]])
            continue
        end

        res = search(index, q, KnnResult(k))
        if raw_output
            tweet["knn"] = res
        else
            L = []
            for p in res
                s = rcorpus[p.objID] |> JSON.parse
                push!(L, (p, s))
            end
            tweet["knn"] = L
        end
        write(STDOUT, JSON.json(tweet, 2))

        push!(L, tweet)
    end
    # t = time() - t
    # info("Solved $count queries in ", t, "seconds, avg search time: ", t/count)

    input != "-" && close(istream)
end

function main()
    s = ArgParseSettings(description = "Ranix command line")

    @add_arg_table s begin
        "model"
            action = :command
            help = "creates a new model"
        "convert"
            action = :command
            help = "converts an json-like input to a sparse vector output"
        "append"
            action = :command
            help = "append items to the index"
        "search"
            action = :command
            help = "opens a repl for searching over a given index"
    end

    @add_arg_table s["model"] begin
      "env"
        required = true
        arg_type = String
        help = "The output environment"
      "--input"
        arg_type = String
        default = "-"
        help = "The input dataset"
      "--qlist"
        required = true
        help = "a comma separated list of q sizes (character q-grams)"
        arg_type = String
      "--nlist"
        required = true
        help = "a comma separated list of n sizes (word n-grams)"
        arg_type = String
      "--key"
        help = "The keyword that contains the text data to be modeled"
        arg_type = String
        default = "text"
    end

    @add_arg_table s["convert"] begin
        "env"
            required = true
            arg_type = String
            help = "index's environment"
        "--input"
            arg_type = String
            default = "-"
            help = "The input dataset"
        "--output"
            arg_type = String
            default = "-"
            help = "filename to store the output"
        "--key"
            arg_type = String
            help = "The keyword that contains the text data"
            default = "text"
    end

    @add_arg_table s["append"] begin
        "env"
            required = true
            arg_type = String
            help = "index's environment"
        "--database"
            arg_type = String
            default = "-"
            help = "input database"
        "--key"
            arg_type = String
            help = "The keyword that contains the text data"
            default = "text"
        "--knn"
            arg_type = Int
            default = 10
            help = "the index should be optimized to solve k queries"
        "--recall"
            arg_type = Float64
            default = 0.90
            help = "the index will be optimized to solve queries with this expected recall"
        "--fastlinks"
            arg_type = Int
            default = 3
            help = "the number of fast links"
    end

    @add_arg_table s["search"] begin
        "env"
            required = true
            arg_type = String
            help = "index's environment"
        "--queries"
            arg_type = String
            default = "-"
            help = "the input queries, in database format"
        "--knn"
            arg_type = Int
            default = 10
            help = "the number of neighbors to be retrieved"
        "--key"
            arg_type = String
            help = "The keyword that contains the text data"
            default = "text"
        "--raw-output"
            action = :store_true
            help = "The output is shown without accessing the corpus"
        "--opt-recall"
            arg_type = Float64
            default = 0.0
            help = "if given, the search parameters will be adjusted to try to reach this recall"
        "--opt-knn"
            arg_type = Int
            default = -1
            help = "if given, the search parameters will be adjusted to try to reach --opt-recall for this number of neighbors"
        "--opt-queries"
            arg_type = String
            default = ""
            help = "a small sample of items following the query set distribution (useful to optimize parameters --opt-*)"
    end
    args = parse_args(s)
    cmd = args["%COMMAND%"]

    if cmd == "model"
        create_model(args["model"])
    elseif cmd == "convert"
        convert_database(args["convert"])
    elseif cmd == "append"
        append_index(args["append"])
    elseif cmd == "search"
        search_index(args["search"])
    end
end

if !isinteractive()
    textindex = main()
end
