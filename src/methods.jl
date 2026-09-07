const MOI = MathOptInterface
env = Gurobi.Env()
# env = CPLEX.Env()
EPS = 1e-6

mutable struct ModelInfo
    status::String
    runtime::Int
    best_lb::Float64
    best_ub::Float64
    gap::Float64
    gap_root::Float64
    runtime_root::Float64
    tree::Int
    rcc_cuts::Int
    tournament_cuts::Int
    scenarios::Int
end

function print_model_solution(model_solution::ModelInfo, algo::String, io::IO = stdout)
    @printf(
        io,
        "%s,%s,%.2f,%.2f,%.2f,%d,%.2f,%d,%d,%d,%d,%d\n",
        algo,
        model_solution.status,
        model_solution.best_ub,
        model_solution.best_lb,
        model_solution.gap * 100,  # Gap as percentage
        model_solution.runtime,
        model_solution.gap_root, # Gap as percentage
        model_solution.runtime_root,
        model_solution.tree,
        model_solution.rcc_cuts,
        model_solution.tournament_cuts,
        model_solution.scenarios,
    )
end

function get_root_info(log_output_str::String)
    open(log_output_str, "r") do file
        for line in eachline(file)
            if occursin("Root relaxation:", line)
                if occursin("cutoff", line)
                    root_value = NaN
                    m_runtime = match(r"cutoff, [\d\.eE\+\-]+.*?([\d\.]+) seconds", line)
                    root_runtime = Int(round(parse(Float64, m_runtime.captures[1])))
                else
                    m_value = match(r"objective ([\d\.eE\+\-]+)", line)
                    root_value = parse(Float64, m_value.captures[1])
                    m_runtime = match(r"objective [\d\.eE\+\-]+.*?([\d\.]+) seconds", line)
                    root_runtime = Int(round(parse(Float64, m_runtime.captures[1])))
                end                
                return root_value, root_runtime
            end
        end
    end
end

function mip_start(model::Model, solution::Solution, data::Data)
    A = keys(data.A)

    A_start = Set{Tuple{Int,Int}}()
    x = model[:x]
    for route in solution.routes
        for idx = 1:(length(route)-1)
            i = route[idx].id
            j = route[idx+1].id
            push!(A_start, (i, j))
        end
    end
    for (i, j) in A
        if (i, j) in A_start
            set_start_value(x[(i, j)], 1.0)
        else
            set_start_value(x[(i, j)], 0.0)
        end
    end
end

function solve(data::Data, Γ::Int, algo::String; start_solution = nothing, tim_lim = 90)
    log_output_str = string("temporary.log")
    if isfile(log_output_str)
        rm(log_output_str)
    end

    model = Model(() -> Gurobi.Optimizer(env))

    # Set Gurobi parameters
    # set_silent(model)
    set_optimizer_attribute(model, "LogFile", log_output_str)
    set_optimizer_attribute(model, "TimeLimit", tim_lim)
    set_optimizer_attribute(model, "NumericFocus", 2)
    set_optimizer_attribute(model, "Presolve", 2)
    set_optimizer_attribute(model, "FeasibilityTol", 1e-8)   # 100x mais preciso
    set_optimizer_attribute(model, "IntFeasTol", 1e-9)       # 10.000x mais preciso
    set_optimizer_attribute(model, "MIPGap", 1e-5)           # 10x mais preciso

    if algo == "CF"
        runtime = @elapsed model, model_info = solve_CF(model, data, Γ, start_solution)
    elseif algo == "TIF"
        runtime = @elapsed model, model_info = solve_TIF(model, data, Γ, start_solution)
    elseif algo == "CRG"
        runtime =
            @elapsed model, model_info = solve_CRG(model, data, Γ, start_solution, tim_lim)
    else
        error("Invalid algorithm specified. Use 'CF', 'TIF', or 'CRG'.")
        return
    end

    status = termination_status(model)
    prime_stats = primal_status(model)

    if status == MOI.INFEASIBLE_OR_UNBOUNDED || status == MOI.INFEASIBLE
        # Get Model Summary
        model_info.status = "Infeasible"
        solution = nothing
    elseif prime_stats == MOI.NO_SOLUTION
        model_info.status = "NoSolution"
        solution = nothing
    else
        model_info.status = "Feasible"
        model_info.best_ub = objective_value(model) # Best upper bound
        # model_info.best_lb = dual_objective_value(model) # Best lower bound only for LP relaxations
        model_info.best_lb = objective_bound(model) # Best lower bound
        model_info.gap = relative_gap(model) # Gap
        solution = Solution(model[:x], data)
        root_value, root_runtime = get_root_info(log_output_str)
        if isnan(root_value)
            model_info.gap_root = 0.0
        else
            model_info.gap_root = root_value # root value
        end
        model_info.runtime_root = root_runtime # Runtime root
    end
    model_info.runtime = Int(round(runtime)) # Runtime in seconds
    return solution, model_info
end

function solve_CF(model::Model, data::Data, Γ::Int, start_solution::Union{Solution,Nothing})
    n_rcc_cuts = 0
    compact_formulation(model, data, Γ)

    if !isnothing(start_solution)
        mip_start(model, start_solution, data)
    end

    function usercut_callback(cbdata)
        x = model[:x]
        xval = callback_value.(Ref(cbdata), x)

        cvrpsep_data = CVRPSEPData(xval, data, EPS)

        rcc_cuts = RCC(cvrpsep_data, model, data)
        n_rcc_cuts += length(rcc_cuts)
        for cut in rcc_cuts
            MOI.submit(model, MOI.UserCut(cbdata), cut)
        end
    end

    MOI.set(model, MOI.UserCutCallback(), usercut_callback)

    optimize!(model)
    model_info = ModelInfo(
        "",
        0,
        0,
        0,
        0,
        0, # Gap root
        0, # Runtime root
        MOI.get(model, MOI.NodeCount()), # Tree size
        n_rcc_cuts, # RCC cuts
        0, # Tournament cuts
        0, # Scenarios
    )
    return model, model_info
end

function solve_TIF(
    model::Model,
    data::Data,
    Γ::Int,
    start_solution::Union{Solution,Nothing},
)
    n_rcc_cuts = 0
    n_ti_cuts = 0

    relaxed_formulation(model, data, Vector{BitMatrix}())

    if !isnothing(start_solution)
        mip_start(model, start_solution, data)
    end

    function usercut_callback(cbdata)
        x = model[:x]
        xval = callback_value.(Ref(cbdata), x)

        cvrpsep_data = CVRPSEPData(xval, data, EPS)

        rcc_cuts = RCC(cvrpsep_data, model, data)
        n_rcc_cuts += length(rcc_cuts)
        for cut in rcc_cuts
            MOI.submit(model, MOI.UserCut(cbdata), cut)
        end
    end

    function lazy_callback(cbdata)
        x = model[:x]
        xval = callback_value.(Ref(cbdata), x)

        if Γ > 0
            tournament_cuts = TournamentCuts(x, xval, Γ, data)
            n_ti_cuts += length(tournament_cuts)
            for cut in tournament_cuts
                MOI.submit(model, MOI.LazyConstraint(cbdata), cut)
            end
        end
    end

    MOI.set(model, MOI.UserCutCallback(), usercut_callback)
    MOI.set(model, MOI.LazyConstraintCallback(), lazy_callback)
    optimize!(model)

    model_info = ModelInfo(
        "",
        0,
        0,
        0,
        0,
        0, # Gap root
        0, # Runtime root
        MOI.get(model, MOI.NodeCount()), # Tree size
        n_rcc_cuts, # RCC cuts
        n_ti_cuts, # Tournament cuts
        0, # Scenarios
    )

    return model, model_info
end

function solve_CRG(
    model::Model,
    data::Data,
    Γ::Int,
    start_solution::Union{Solution,Nothing},
    tim_lim::Int,
)
    n_rcc_cuts = 0

    n = data.n + 2
    V = data.V
    l = [i.tw.l for i in V]
    Δ = Vector{BitMatrix}()
    feasibility = false
    start_time = time()

    while !feasibility && (time() - start_time) < tim_lim
        remaining_time = Int(round(tim_lim - (time() - start_time)))
        set_optimizer_attribute(model, "TimeLimit", remaining_time)

        relaxed_formulation(model, data, Δ)
        if !isnothing(start_solution)
            mip_start(model, start_solution, data)
        end

        function usercut_callback(cbdata)
            x = model[:x]
            xval = callback_value.(Ref(cbdata), x)

            cvrpsep_data = CVRPSEPData(xval, data, EPS)

            rcc_cuts = RCC(cvrpsep_data, model, data)
            n_rcc_cuts += length(rcc_cuts)
            for cut in rcc_cuts
                MOI.submit(model, MOI.UserCut(cbdata), cut)
            end
        end

        MOI.set(model, MOI.UserCutCallback(), usercut_callback)
        optimize!(model)

        status = termination_status(model)
        prime_stats = primal_status(model)

        if status == MOI.INFEASIBLE_OR_UNBOUNDED ||
           status == MOI.INFEASIBLE ||
           status == MOI.TIME_LIMIT ||
           prime_stats == MOI.NO_SOLUTION
            break
        end

        Δ_l = length(Δ)
        solution = Solution(model[:x], data)
        routes = solution.routes
        for route in routes
            α, mask = max_time_dependent_arrival(route, data, Γ)
            best_scenario = Vector{Tuple{Int,Int}}()
            for i = 2:length(route)
                v = route[i]
                if α[i, Γ] > l[v.id]
                    new_scenario = generate_scenario(route, i, mask, Γ)
                    if length(new_scenario) > length(best_scenario)
                        best_scenario = new_scenario
                        if length(best_scenario) == Γ
                            break
                        end
                    end
                end
            end
            if length(best_scenario) > 0
                scenario_matrix = falses(n, n)
                for (i, j) in best_scenario
                    scenario_matrix[i, :] .= true
                    scenario_matrix[:, j] .= true
                end
                push!(Δ, scenario_matrix)
            end
        end
        if length(Δ) == Δ_l
            feasibility = true
        else
            empty!(model)
        end
    end

    model_info = ModelInfo(
        "",
        0,
        0,
        0,
        0,
        0, # Gap root
        0, # Runtime root
        MOI.get(model, MOI.NodeCount()), # Tree size
        n_rcc_cuts, # RCC cuts
        0, # Tournament cuts
        length(Δ), # Scenarios
    )

    return model, model_info
end

function generate_scenario(
    route::Vector{SolutionNode},
    viol_pos::Int,
    mask::OffsetArray,
    Γ::Int,
)
    scenario = Vector{Tuple{Int,Int}}()
    i = viol_pos
    γ = Γ
    while i > 1
        if mask[i, γ]
            push!(scenario, (route[i-1].id, route[i].id))
            γ -= 1
        end
        i -= 1
    end
    return scenario
end
