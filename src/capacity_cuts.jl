using CVRPSEP
struct CVRPSEPData
    demands::Vector{Int}
    capacity::Int
    heads::Vector{Int}
    tails::Vector{Int}
    xs::Vector{Float64}
    cut_manager::CutManager
    max_n_cuts::Int
end

function CVRPSEPData(xval::JuMP.Containers.DenseAxisArray, data::Data, EPS::Float64)
    n = data.n + 2
    o = data.o
    d = data.d
    V = data.V
    A = keys(data.A)
    C = [v for v in data.V if v.id != data.o.id && v.id != data.d.id]

    demands = [i.q for i in C]
    capacity = data.Q
    tails = Int[]
    heads = Int[]
    xs = Float64[]
    cut_manager = CutManager()

    for i = 2:(n-1)
        u = ((o.id, i) in A && xval[(o.id, i)] > EPS) ? xval[(o.id, i)] : 0.0
        v = ((i, d.id) in A && xval[(i, d.id)] > EPS) ? xval[(i, d.id)] : 0.0
        if u + v > EPS
            push!(tails, o.id)
            push!(heads, i)
            push!(xs, u + v)
        end
    end

    for i = 2:(n-1)
        for j = (i+1):(n-1)
            u = ((i, j) in A && xval[(i, j)] > EPS) ? xval[(i, j)] : 0.0
            v = ((j, i) in A && xval[(j, i)] > EPS) ? xval[(j, i)] : 0.0
            if u + v > EPS
                push!(tails, i)
                push!(heads, j)
                push!(xs, u + v)
            end
        end
    end
    return CVRPSEPData(demands, capacity, heads, tails, xs, cut_manager, 50)
end

function RCC(cvrpsep_data::CVRPSEPData, model::Model, data::Data)
    o = data.o.id
    d = data.d.id
    A = data.A
    adjust(j) = j == o ? d : j

    x = model[:x]
    cuts = Vector{JuMP.ScalarConstraint{JuMP.AffExpr,MOI.LessThan{Float64}}}()
    S, RHS = rounded_capacity_inequalities!(
        cvrpsep_data.cut_manager,
        cvrpsep_data.demands,
        cvrpsep_data.capacity,
        cvrpsep_data.tails,
        cvrpsep_data.heads,
        cvrpsep_data.xs,
        integrality_tolerance = 1e-6,
        max_n_cuts = cvrpsep_data.max_n_cuts,
    )

    # @show S, RHS
    # readline()

    for (s_idx, s) in enumerate(S)
        rhs = RHS[s_idx]
        cut = @build_constraint(
            sum(x[(i, adjust(j))] for i in s, j in s if haskey(A, (i, adjust(j)))) <= rhs
        )
        push!(cuts, cut)
    end
    return cuts
end
