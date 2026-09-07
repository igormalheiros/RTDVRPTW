using JuMP,
    Gurobi,
    CPLEX,
    TimeDependentFunctions,
    OffsetArrays,
    Test,
    Printf,
    Random,
    Graphs,
    GraphsFlows,
    CVRPSEP
import MathOptInterface # Replaces MathProgBase

include("src/data_json.jl")
include("src/solution.jl")
include("src/formulations.jl")
include("src/capacity_cuts.jl")
include("src/tournament_cuts.jl")
include("src/methods.jl")

function load_heuristic_solution(filename::String)
    if isfile(filename)
        obj = parse(Float64, readlines(filename)[1])
        if obj > 1e6
            return nothing
        end
        lines = readlines(filename)[2:end]  # skip first line (objective)
        return [parse.(Int, split(strip(line), ",")) for line in lines]
    else
        return nothing
    end
end

# run_input_test()
vector_solution = nothing


# 3717
input_file = "data/instances/DM-TDVRPTW/R209_25.json"
dev_percentage = 0.25
budget = 3
solution_bound_file = "data/heuristic_solutions/R209_25_025_3.sol"


vector_solution = load_heuristic_solution(solution_bound_file)
data = read_json(input_file, dev_percentage)
preprocess(data, budget)

const METHOD = "TIF"  # CF, CRG, TIF

if !isnothing(vector_solution)
    init_solution = Solution(vector_solution, data)
    @test visit_constraints(init_solution, data)
    @test capacity_constraints(init_solution, data)
    @test time_window_constraints(init_solution, data)
    @test isapprox(init_solution.obj, objective(init_solution, data))
    solution, model_sol =
        solve(data, budget, METHOD; start_solution = init_solution, tim_lim = 180)
else
    solution, model_sol = solve(data, budget, METHOD)
end

if !isnothing(solution)
    @test visit_constraints(solution, data)
    @test capacity_constraints(solution, data)
    @test time_window_constraints(solution, data)
    @test robust_constraints(solution, data, budget)
    @test isapprox(solution.obj, objective(solution, data))
end

println("$input_file  $dev_percentage  $budget: ")
print_model_solution(model_sol, METHOD)
