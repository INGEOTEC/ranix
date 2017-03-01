# Ranix


Ranix is a document search engine mostly in barebones. It is intended to be of use to create simple demonstrations and perform text analytics tasks like exploratory analysis and near duplication detection. Other complex tasks are also possible with a little bit of effort.

If you are interested in the tasks performed by this package but you
cannot waste your time with costly preprocessing steps, please check
out the
[PatternAnalysisTools](https://github.com/INGEOTEC/PatternAnalysisTools.git)


# License
This is work in progress under the Apache 2.0 license.

# Dependencies

It is based on the Near Neighbor Search
([NNS.jl](https://github.com/sadit/NNS.jl)) library. The NNS.jl is not
indexed by the Julia's package manager, so it should be cloned

```julia

Pkg.clone("https://github.com/sadit/NNS.jl")
```

All command line scripts use ArgParse.jl

```julia

Pkg.add("ArgParse")
```

## Input format
Each document is a JSON-entry, with a given keyword, e.g.,

- `{"text": "hello world!", "additional-key": 3}`
- `{"text": "help!", "more-keys": "X"}`

the keyword `"text"` contains the text to be indexed.

# Usage 
Most of the functionalities are handled by the `ranix.jl` command line 
tool. 

The gross process is the following:
- A text model should be created with `julia ranix.jl model`
- Append documents to the index with `julia ranix.jl append`
- Search for relevant documents to given queries with `julia ranix.jl search`

### Creation of the model
```bash

julia ranix.jl model INEGI --input inegi-geo.json.gz --nlist=1 --qlist=5 --key text
```

where INEGI is the name of the environment where everything will be
stored

```bash
$ find INEGI/
INEGI/
INEGI/model
```

### Appending documents to the index
```bash
zcat < inegi-geo.json.gz  | julia ranix.jl append INEGI

INFO: added n=1, neighborhood=0, 2017-03-01T12:17:36.479
...
INFO: XXX NNS.BeamSearch. Starting parameter optimization; expected recall: 0.9, n: 7
INFO: XXX NNS.BeamSearch. Iteration: 1, expected recall: 0.9, n: 7
INFO: *** NNS.BeamSearch. A new best conf was found>
fitness: 0.27343749999999994, conf: {"candidates_size":2,"montecarlo_size":2,"beam_size":3}, perf: {"recall":0.27343749999999994,"seconds":1.6044825315475464e-5,"distances":5.21875},candidates: 1, n: 7
....
INFO: XXX NNS.BeamSearch. Optimization done; fitness: 3011.468071431149, conf: {"candidates_size":17,"montecarlo_size":13,"beam_size":5}, perf: {"recall":0.9164062500000001,"seconds":0.0003322754055261612,"distances":396.0234375}, n: 16383
INFO: saving a snapshot of the index
```
This command appends the documents inside inegi-geo.json.gz.
A number of output lines showing the index state as documents are
inserted.

The `append` command also supports several flags, amongs the more
significant ones:
- `--recall` controls the expected recall in the index
- `--knn` defines the number of expected nearest neighbors (it is
tightly linked to `--recall`)


### Querying the index (batch mode)
```bash
zcat < not-seen-before-documents.json.gz | julia ranix.jl search INEGI
... outputs one json per query ...
```
