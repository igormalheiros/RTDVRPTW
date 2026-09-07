# RTDVRPTW

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Code, instances, and results for the **Robust Time-Dependent Vehicle Routing Problem with
Time Windows and budget uncertainty (RTDVRPTW)**.

If you use this repository, please cite:

> Malheiros, Igor, Poss, Michaël, Nesello, Vitor, and Subramanian, Anand. "The robust
> time-dependent vehicle routing problem with time windows and budget uncertainty."
> *Transportation Science* (2026).

```bibtex
@article{malheiros2026robust,
  title={The robust time-dependent vehicle routing problem with time windows and budget uncertainty},
  author={Malheiros, Igor and Poss, Micha{\"e}l and Nesello, Vitor and Subramanian, Anand},
  journal={Transportation Science},
  year={2026}
}
```

## Methods

The exact approaches implemented in `src/` are referred to throughout the code and results by
their abbreviations:

- **CF** — Compact Formulation
- **TIF** — Tournament Inequalities Formulation
- **CRG** — Column-and-Row Generation

## Repository structure

```
src/                    Julia implementation of the exact methods (CF, TIF, CRG)

script.jl, test.jl      entry points that run the algorithms on the instances

scripts/                post-processing: turns raw results into the paper's tables/figures
  preprocess_latex_tables.py   arc/breakpoint reduction table
  tables/                      mergecsv.py, separatetables.py, profiling.jl

data/
  instances/DM-TDVRPTW/  Solomon-based benchmark instances (JSON)
  heuristic_solutions/   ILS warm-start solutions (.sol) used by the exact methods
  results/
    raw/                 raw benchmark output per method (CF, TIF, CRG, ILS)
    derived/             aggregated CSVs used directly by the paper's tables
    tables/              generated .tex/.tikz table and figure sources
```

## Reproducing the paper's tables

```
julia --project=. script.jl                       # regenerate data/results/raw/benchmark_results_CF.csv
python3 scripts/preprocess_latex_tables.py         # -> data/results/tables/preprocess_table.tex
python3 scripts/tables/mergecsv.py                 # -> data/results/derived/benchmark_results_all.csv
python3 scripts/tables/separatetables.py           # -> data/results/derived/benchmark_exact_aggragate.csv
julia --project=. scripts/tables/profiling.jl      # -> data/results/tables/performance_profile_tikz.tex
```

`script.jl` requires a licensed [Gurobi](https://www.gurobi.com/) installation. The ILS
heuristic that produced `data/heuristic_solutions/` and `data/results/raw/benchmark_results_ILS.csv`
is not part of this repository; only its inputs/outputs are included.

## License

MIT — see [LICENSE](LICENSE).
