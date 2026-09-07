using CSV
using DataFrames
using TikzPictures
using BenchmarkProfiles
using Plots

# -----------------------------
# 1. Load CSV
# -----------------------------
# Change the file path to your actual CSV file
df = CSV.read("data/results/derived/benchmark_results_all.csv", DataFrame)

# -----------------------------
# 2. Filter out rows where gap_CF is missing
# -----------------------------
filter!(row -> !ismissing(row.gap_CF), df)

# -----------------------------
# 3. Identify each unique instance
# Instance = (Name, Size, Budget, Dev)
# -----------------------------
# If needed later, you can group by instance_id
df.instance_id = string.(df.Instance, "_", df.Size, "_", df.Budget, "_", df.Dev)

# -----------------------------
# 4. Extract runtimes
# -----------------------------
runtimes = select(df, :Runtime_CF, :Runtime_TIF, :Runtime_CRG)

# -----------------------------
# 5. Replace runtimes according to rules
#  - 0    → 0.1
#  - ≥3600 → Inf
# -----------------------------
function clean_runtime(x)
    if ismissing(x)
        return Inf
    elseif x == 0
        return 0.1
    elseif x >= 3600
        return Inf
    else
        return x
    end
end

for col in names(runtimes)
    runtimes[!, col] = clean_runtime.(runtimes[!, col])
end

# -----------------------------
# 6. Create the performance matrix
# Each row = one instance, columns = solvers
# -----------------------------
T = Matrix(runtimes)
T = Float64.(T)  # ensure correct type

# -----------------------------
# 7. Plot the performance profile
# -----------------------------
labels = ["CF", "TIF", "CRG"]
@show T
export_performance_profile_tikz(T, "data/results/tables/performance_profile_tikz.tex"; solvernames = labels, xlabel = "Performance ratio", ylabel = "Fraction of instances solved")
# plt = performance_profile(PlotsBackend(), T, labels)
# ylabel!(plt, "Fraction of instances solved")
# xlabel!(plt, "Performance ratio")

# savefig(plt, "perf_profile.pdf")   # PDF
# display(plt)
