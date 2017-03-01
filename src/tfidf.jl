
type TokenData
  id::Int32
  freq::Int32
end

TokenData() = new(0, 0)

type TfidfModel
  voc::Dict{String,TokenData}
  size::Int64
  filter_low::Int
  filter_high::Float64
  config::TextConfig
end

function save(ostream, model::TfidfModel)
    M = Dict{String,Any}(
        "length" => length(model.voc),
        "size" => model.size,
        "filter_low" => model.filter_low,
        "filter_high" => model.filter_high,
    )
    write(ostream, JSON.json(M), "\n")
    save(ostream, model.config)
    for (k, v) in model.voc
        write(ostream, JSON.json((k, v.id, v.freq)), "\n")
    end
end

function load(istream, ::Type{TfidfModel})
    m = JSON.parse(readline(istream))
    config = load(istream, TextConfig)
    voc = Dict{String,TokenData}()
    for i in 1:m["length"]
        k, id, freq = JSON.parse(readline(istream))
        voc[k] = TokenData(id, freq)
    end
    TfidfModel(voc, m["size"], m["filter_low"], m["filter_high"], config)
end

TfidfModel() = TfidfModel(Dict{String,TokenData}(), 0, 1, 0.70, TextConfig())

function TfidfModel(corpus, config::TextConfig)
  model = TfidfModel()
  model.config = config
  V = Dict{String,Int}()
  for text in corpus
    voc, maxfreq = compute_vocabulary(text, model.config)
    for (token, freq) in voc
      V[token] = get(V, token, 0) + freq
    end
    model.size += 1
  end

  for (token, freq) in V
    if freq < model.filter_low || freq > model.filter_high * model.size
      continue
    end
    model.voc[token] = TokenData(length(model.voc)+1, freq)
  end

  model
end

function compute_vocabulary(text::String, config::TextConfig)
    voc = Dict{String,Int}()
    maxfreq = 0
    for token in expand_tokens(text, config)
        freq = get(voc, token, 0) + 1
        voc[token] = freq
        maxfreq = max(maxfreq, freq)
    end
    
    voc, maxfreq
end

function vectorize(text::String, model::TfidfModel; maxlength=typemax(Int))
  localvoc = Dict{String,Int32}()
  vec = Term[]
  localvoc, maxfreq = compute_vocabulary(text, model.config)
  for (token, freq) in localvoc
    tokendata = try
      model.voc[token]
    catch err
      continue
    end

    tf = freq / maxfreq
    idf = log(model.size / tokendata.freq)
    push!(vec, Term(tokendata.id, tf * idf))
    # push!(vec, (token, tfidf))
  end

  if length(vec) > maxlength
     sort!(vec, by=(x) -> -x.weight)
     vec = vec[1:maxlength]
  end
  sort!(vec, by=(x) -> x.id)

  DocumentType(vec)
end
