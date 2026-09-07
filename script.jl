using JuMP,
    Gurobi,
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

function run_benchmark_test()
    budgets = [0, 1, 3, 5]
    dev_percentages = [0.25, 0.5]
    sizes = ["25"]
    instances_name = [
        "C101",
        "C102",
        "C103",
        "C104",
        "C105",
        "C106",
        "C107",
        "C108",
        "C109",
        "C201",
        "C202",
        "C203",
        "C204",
        "C205",
        "C206",
        "C207",
        "C208",
        "R101",
        "R102",
        "R103",
        "R104",
        "R105",
        "R106",
        "R107",
        "R108",
        "R109",
        "R110",
        "R111",
        "R112",
        "R201",
        "R202",
        "R203",
        "R204",
        "R205",
        "R206",
        "R207",
        "R208",
        "R209",
        "R210",
        "R211",
        "RC101",
        "RC102",
        "RC103",
        "RC104",
        "RC105",
        "RC106",
        "RC107",
        "RC108",
        "RC201",
        "RC202",
        "RC203",
        "RC204",
        "RC205",
        "RC206",
        "RC207",
        "RC208",
    ]
    __TIM_LIM__ = 3600
    methods = ["CF", "TIF", "CRG"]    
    output_file = "data/results/benchmark_results.csv"
    open("data/results/benchmark_results_25.csv", "w") do io
        println(
            io,
            "Instance,Size,Budget,Dev,Method,Status,UB,LB,Gap,Runtime,GapRoot,RuntimeRoot,Tree,RCCCuts,TCuts,Scenarios",
        )
        flush(io)
        for method in methods
            for size in sizes
                for instance_name in instances_name
                    path = string("data/instances/DM-TDVRPTW/", instance_name, "_", size, ".json")
                    for budget in budgets

                        if budget == 0
                            print(io, instance_name, ",", size, ",", budget, ",", 0.0, ",")
                            print(instance_name, ",", size, ",", budget, ",", 0.0, ",")

                            data = read_json(path, 0.0)
                            preprocess(data, budget)
                            
                            heuristic_file = get_solution_bound_file(instance_name, size, 0.0, budget)
                            vector_solution = load_heuristic_solution(heuristic_file)
                            if !isnothing(vector_solution)
                                println("\nPRIMAL BOUND PROVIDED")
                                init_solution = Solution(vector_solution, data)
                                solution, model_sol = solve(data, budget, method; start_solution = init_solution, tim_lim = __TIM_LIM__)
                            else
                                println("\nNO PRIMAL BOUND PROVIDED")
                                solution, model_sol = solve(data, budget, method; tim_lim = __TIM_LIM__)
                            end

                            print_model_solution(model_sol, method, io)
                            print_model_solution(model_sol, method)
                            flush(io)
                        else
                            for dev_percentage in dev_percentages
                                print(
                                    io,
                                    instance_name,
                                    ",",
                                    size,
                                    ",",
                                    budget,
                                    ",",
                                    dev_percentage,
                                    ",",
                                )
                                print(
                                    instance_name,
                                    ",",
                                    size,
                                    ",",
                                    budget,
                                    ",",
                                    dev_percentage,
                                    ",",
                                )

                                data = read_json(path, dev_percentage)
                                preprocess(data, budget)

                                heuristic_file = get_solution_bound_file(instance_name, size, dev_percentage, budget)
                                vector_solution = load_heuristic_solution(heuristic_file)
                                if !isnothing(vector_solution)
                                    println("\nPRIMAL BOUND PROVIDED")
                                    init_solution = Solution(vector_solution, data)
                                    solution, model_sol = solve(data, budget, method; start_solution = init_solution, tim_lim = __TIM_LIM__)
                                else
                                    println("\nNO PRIMAL BOUND PROVIDED")
                                    solution, model_sol = solve(data, budget, method; tim_lim = __TIM_LIM__)
                                end

                                print_model_solution(model_sol, method, io)
                                print_model_solution(model_sol, method)
                                flush(io)
                            end
                        end
                    end
                end
            end
        end
    end
end

function get_solution_bound_file(instance_name::String, size::String, dev_percentage::Float64, budget::Int)
    # Format the deviation percentage as a 3-digit string (e.g., 0.5 → "050")
    dev_str = lpad(string(round(Int, dev_percentage * 100)), 3, '0')

    # Construct the solution file name
    solution_filename = "$(instance_name)_$(size)_$(dev_str)_$(budget).sol"

    # Return the full path
    return "data/heuristic_solutions/$solution_filename"
end

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

function warmup()
    data = read_json("data/instances/DM-TDVRPTW/C101_25.json", 0.0)
    preprocess(data, 0)
    solution, model_sol = solve(data, 0, "CF")
end

warmup()
run_benchmark_test()
