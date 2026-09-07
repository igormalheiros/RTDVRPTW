function add_objective_function!(
    model::Model,
    x::AbstractArray{<:JuMP.VariableRef},
    data::Data,
)
    A = keys(data.A)
    c = Dict([a => data.A[a].c for a in A])
    @objective(model, Min, sum(c[a] * x[a] for a in A))
end

function add_flow_constraints!(
    model::Model,
    x::AbstractArray{<:JuMP.VariableRef},
    data::Data,
)
    V = data.V
    A = keys(data.A)
    o = data.o
    d = data.d
    C = [v for v in V if v.id != o.id && v.id != d.id]

    # Flow constraints (2)
    @constraint(
        model,
        [j in [v.id for v in C]],
        sum(x[(v.id, j)] for v in V if (v.id, j) in A) == 1
    )

    # Flow constraints (3)
    @constraint(
        model,
        [vi in C],
        sum(x[(vi.id, vj.id)] for vj in V if (vi.id, vj.id) in A) -
        sum(x[(vj.id, vi.id)] for vj in V if (vj.id, vi.id) in A) == 0
    )

    # Flow constraints (4)
    @constraint(
        model,
        sum(x[(o.id, v.id)] for v in V if (o.id, v.id) in A) -
        sum(x[(v.id, d.id)] for v in V if (v.id, d.id) in A) == 0
    )
end

function add_capacity_constraints!(
    model::Model,
    x::AbstractArray{<:JuMP.VariableRef},
    w::Vector{VariableRef},
    data::Data,
)
    V = data.V
    A = keys(data.A)
    Q = data.Q
    q = Dict([v.id => v.q for v in V])
    C = [v for v in V if v.id != data.o.id && v.id != data.d.id]

    # Capacity constraints (5)
    @constraint(model, [(i, j) in A], w[j] >= w[i] + q[j] * x[(i, j)] - Q * (1 - x[(i, j)]))
    # Capacity constraints (6)
    @constraint(model, [v in C], q[v.id] <= w[v.id] <= Q)
end

function CVRP_formulation!(model::Model, data::Data)
    n = data.n + 2
    A = keys(data.A)

    @variable(model, x[A], Bin)
    @variable(model, w[1:n] >= 0)

    add_objective_function!(model, x, data)
    add_flow_constraints!(model, x, data)
    add_capacity_constraints!(model, x, w, data)
end

function compact_formulation(model::Model, data::Data, Γ::Int)
    n = data.n + 2
    V, A, B̄, B̂, p̄, p̂, e, l, T̄, T̂, x̄, ȳ, x̂, ŷ = get_tw_sets(data)

    CVRP_formulation!(model, data)
    x = model[:x]

    @variable(model, α[1:n, 0:Γ] >= 0)
    @variable(model, z̄[(i, j) in A, k in 1:p̄[(i, j)], 0:Γ] >= 0)
    @variable(model, ẑ[(i, j) in A, k in 1:p̂[(i, j)], 0:Γ] >= 0)

    # Time constraints (3)
    @constraint(model, [v in V, γ = 0:Γ], e[v.id] <= α[v.id, γ] <= l[v.id])

    # SOS2 constraints (18)
    @constraint(
        model,
        [(i, j) in A, γ = 0:Γ],
        sum(z̄[(i, j), k, γ] for k = 1:p̄[(i, j)]) == 1
    )

    @constraint(
        model,
        [(i, j) in A, γ = 0:Γ],
        sum(ẑ[(i, j), k, γ] for k = 1:p̂[(i, j)]) == 1
    )

    @constraint(
        model,
        [(i, j) in A, γ = 0:Γ],
        α[i, γ] >=
        sum(x̄[(i, j)][k] * z̄[(i, j), k, γ] for k = 1:p̄[(i, j)]) -
        T̄[i, j] * (1 - x[(i, j)])
    )

    @constraint(
        model,
        [(i, j) in A, γ = 0:Γ],
        α[i, γ] <=
        sum(x̄[(i, j)][k] * z̄[(i, j), k, γ] for k = 1:p̄[(i, j)]) +
        T̄[i, j] * (1 - x[(i, j)])
    )

    @constraint(
        model,
        [(i, j) in A, γ = 0:Γ],
        α[i, γ] >=
        sum(x̂[(i, j)][k] * ẑ[(i, j), k, γ] for k = 1:p̂[(i, j)]) -
        T̂[i, j] * (1 - x[(i, j)])
    )

    @constraint(
        model,
        [(i, j) in A, γ = 0:Γ],
        α[i, γ] <=
        sum(x̂[(i, j)][k] * ẑ[(i, j), k, γ] for k = 1:p̂[(i, j)]) +
        T̂[i, j] * (1 - x[(i, j)])
    )

    # SOS2 constraints (23)
    @constraint(
        model,
        [(i, j) in A, γ = 0:Γ],
        α[j, γ] >=
        sum((x̄[(i, j)][k] + ȳ[(i, j)][k]) * z̄[(i, j), k, γ] for k = 1:p̄[(i, j)]) -
        (T̄[i, j]) * (1 - x[(i, j)])
    )

    @constraint(
        model,
        [(i, j) in A, γ = 1:Γ],
        α[j, γ] >=
        (sum(
            ((x̄[(i, j)][k] + ȳ[(i, j)][k]) * z̄[(i, j), k, γ-1]) +
            ŷ[(i, j)][k] * ẑ[(i, j), k, γ-1] for k = 1:p̄[(i, j)]
        )) - T̂[i, j] * (1 - x[(i, j)])
    )

    # SOS2 constraints (24)
    @constraint(model, [(i, j) in A, γ = 0:Γ], z̄[(i, j), :, γ] in SOS2())

    # SOS2 constraints (25)
    @constraint(model, [(i, j) in A, γ = 0:Γ], ẑ[(i, j), :, γ] in SOS2())

    return model
end

function add_no_scenarios_constraints!(
    model::Model,
    x::AbstractArray{<:JuMP.VariableRef},
    data::Data,
)
    n = data.n + 2
    V, A, B̄, _, p̄, _, e, l, T̄, _, x̄, ȳ, _, _ = get_tw_sets(data)

    @variable(model, y[1:n] >= 0)
    @variable(model, z̄[(i, j) in A, 1:p̄[(i, j)]] >= 0)

    # Time constraints
    @constraint(model, [v in V], e[v.id] <= y[v.id] <= l[v.id])
    # SOS2 constraints
    @constraint(model, [(i, j) in A], sum(z̄[(i, j), k] for k = 1:p̄[(i, j)]) == 1)

    # SOS2 constraints (20)
    @constraint(
        model,
        [(i, j) in A],
        y[i] <=
        sum(x̄[(i, j)][k] * z̄[(i, j), k] for k = 1:p̄[(i, j)]) +
        T̄[i, j] * (1 - x[(i, j)])
    )

    # SOS2 constraints (20)
    @constraint(
        model,
        [(i, j) in A],
        y[i] >=
        sum(x̄[(i, j)][k] * z̄[(i, j), k] for k = 1:p̄[(i, j)]) -
        T̄[i, j] * (1 - x[(i, j)])
    )

    @constraint(
        model,
        [(i, j) in A],
        y[j] >=
        (sum((x̄[(i, j)][k] + ȳ[(i, j)][k]) * z̄[(i, j), k] for k = 1:p̄[(i, j)])) -
        T̄[i, j] * (1 - x[(i, j)])
    )

    # SOS2 constraints (24)
    @constraint(model, [(i, j) in A], z̄[(i, j), :] in SOS2())
end

function add_scenarios_constraints!(
    model::Model,
    x::AbstractArray{<:JuMP.VariableRef},
    data::Data,
    Δ::Vector{BitMatrix},
)
    n = data.n + 2
    V, A, B̄, B̂, p̄, p̂, e, l, T̄, T̂, x̄, ȳ, x̂, ŷ = get_tw_sets(data)

    Δ_l = length(Δ)
    @variable(model, y[1:n, 1:Δ_l] >= 0)
    @variable(model, z̄[(i, j) in A, 1:p̄[(i, j)], 1:Δ_l] >= 0)
    @variable(model, ẑ[(i, j) in A, 1:p̄[(i, j)], 1:Δ_l] >= 0)
    # Time constraints
    @constraint(model, [v in V, δ in 1:Δ_l], e[v.id] <= y[v.id, δ] <= l[v.id])
    # SOS2 constraints
    @constraint(
        model,
        [(i, j) in A, δ in 1:Δ_l],
        sum(z̄[(i, j), k, δ] for k = 1:p̄[(i, j)]) == 1
    )
    @constraint(
        model,
        [(i, j) in A, δ in 1:Δ_l],
        sum(ẑ[(i, j), k, δ] for k = 1:p̂[(i, j)]) == 1
    )

    # SOS2 constraints (20)
    @constraint(
        model,
        [(i, j) in A, δ in 1:Δ_l],
        y[i, δ] <=
        sum(x̄[(i, j)][k] * z̄[(i, j), k, δ] for k = 1:p̄[(i, j)]) +
        T̄[i, j] * (1 - x[(i, j)])
    )

    # SOS2 constraints (20)
    @constraint(
        model,
        [(i, j) in A, δ in 1:Δ_l],
        y[i, δ] >=
        sum(x̄[(i, j)][k] * z̄[(i, j), k, δ] for k = 1:p̄[(i, j)]) -
        T̄[i, j] * (1 - x[(i, j)])
    )

    @constraint(
        model,
        [(i, j) in A, δ in 1:Δ_l],
        y[i, δ] <=
        sum(x̂[(i, j)][k] * ẑ[(i, j), k, δ] for k = 1:p̂[(i, j)]) +
        T̂[i, j] * (1 - x[(i, j)])
    )

    @constraint(
        model,
        [(i, j) in A, δ in 1:Δ_l],
        y[i, δ] >=
        sum(x̂[(i, j)][k] * ẑ[(i, j), k, δ] for k = 1:p̂[(i, j)]) -
        T̂[i, j] * (1 - x[(i, j)])
    )

    @constraint(
        model,
        [(i, j) in A, δ in 1:Δ_l],
        y[j, δ] >=
        (sum(
            (x̄[(i, j)][k] + ȳ[(i, j)][k]) * z̄[(i, j), k, δ] +
            Δ[δ][i, j] * ŷ[(i, j)][k] * ẑ[(i, j), k, δ] for k = 1:p̄[(i, j)]
        )) - T̂[i, j] * (1 - x[(i, j)])
    )

    # SOS2 constraints (24)
    @constraint(model, [(i, j) in A, δ in 1:Δ_l], z̄[(i, j), :, δ] in SOS2())
    @constraint(model, [(i, j) in A, δ in 1:Δ_l], ẑ[(i, j), :, δ] in SOS2())
end

function relaxed_formulation(model::Model, data::Data, Δ::Vector{BitMatrix})
    CVRP_formulation!(model, data)
    x = model[:x]

    if length(Δ) > 0
        add_scenarios_constraints!(model, x, data, Δ)
    else
        add_no_scenarios_constraints!(model, x, data)
    end
end

function get_tw_sets(data::Data)
    n = data.n + 2
    V = data.V
    A = keys(data.A)
    B̄ = Dict([a => data.A[a].B̄ for a in A])
    B̂ = Dict([a => data.A[a].B̂ for a in A])
    p̄ = Dict([a => length(B̄[a]) for a in A])
    p̂ = Dict([a => length(B̂[a]) for a in A])
    e = [v.tw.e for v in V]
    l = [v.tw.l for v in V]

    nom_pwfs = Dict([a => build_segments(B̄[a]) for a in A])
    dev_pwfs = Dict([a => build_segments(B̂[a]) for a in A])

    T̄ = [
        ((i, j) in A ? l[i] + bs_piecewise_affine_t(l[i], nom_pwfs[(i, j)]) : 0.0) for
        i = 1:n, j = 1:n
    ]
    T̂ = [
        ((i, j) in A ? T̄[i, j] + bs_piecewise_affine_t(l[i], dev_pwfs[(i, j)]) : 0.0)
        for i = 1:n, j = 1:n
    ]

    x̄ = Dict([a => [B̄[a][k][1] for k = 1:p̄[a]] for a in A])
    ȳ = Dict([a => [B̄[a][k][2] for k = 1:p̄[a]] for a in A])
    x̂ = Dict([a => [B̂[a][k][1] for k = 1:p̂[a]] for a in A])
    ŷ = Dict([a => [B̂[a][k][2] for k = 1:p̂[a]] for a in A])

    return V, A, B̄, B̂, p̄, p̂, e, l, T̄, T̂, x̄, ȳ, x̂, ŷ
end
