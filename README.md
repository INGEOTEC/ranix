# Ranix

Ranix is a document search engine mostly in barebones. It is intended
to be of use to create simple demonstration and a number of text
analytics tasks like exploratory analysis and near duplication
detection.
Other complex tasks are also possible with a little bit of effort.

If you are interested in the tasks performed by this package but you
cannot waste your time with costly preprocessing steps, please check
out the
[PatternAnalysisTools](https://github.com/INGEOTEC/PatternAnalysisTools.git)


# Disclaimer
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


# Usage

Please read `ranix.jl` command line tool


