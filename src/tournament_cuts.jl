function TournamentCuts(
    x::AbstractArray{<:JuMP.VariableRef},
    xval::JuMP.Containers.DenseAxisArray,
    Γ::Int,
    data::Data,
)
    n = data.n + 2
    A = keys(data.A)
    o = data.o
    d = data.d

    cuts = Vector{JuMP.ScalarConstraint{JuMP.AffExpr,MOI.LessThan{Float64}}}()
    flow = zeros(n, n)  # initialize flow matrix

    for (i, j) in A
        flow[i, j] = xval[(i, j)]
    end

    flow_paths = decompose_flow_into_paths(flow, o.id, d.id)

    for (path, flow) in flow_paths
        if flow > 0.25
            path_ = build_path(path, data)
            cut = tournament_cut(x, path_, data, Γ)
            if !isnothing(cut)
                push!(cuts, cut)
            end
        end
    end
    return cuts
end

function find_path(residual::Matrix{Float64}, s::Int, t::Int)
    n = size(residual, 1)
    visited = falses(n)
    parent = fill(-1, n)
    stack = [s]

    while !isempty(stack)
        u = pop!(stack)
        if visited[u]
            continue
        end
        visited[u] = true

        if u == t
            return true, parent
        end

        for v = 1:n
            if residual[u, v] > 0 && !visited[v]
                push!(stack, v)
                parent[v] = u
            end
        end
    end
    return false, parent
end

function reconstruct_path(parent::Vector{Int}, s::Int, t::Int, residual::Matrix{Float64})
    path = []
    nodes = [t]
    v = t
    min_flow = Inf

    while v != s
        u = parent[v]
        pushfirst!(path, (u, v))
        pushfirst!(nodes, u)
        min_flow = min(min_flow, residual[u, v])
        v = u
    end

    return path, nodes, min_flow
end

function decompose_flow_into_paths(flow::Matrix{Float64}, s::Int, t::Int)
    n = size(flow, 1)
    residual = copy(flow)
    paths = []

    while true
        found, parent = find_path(residual, s, t)
        if !found
            break
        end

        edges, nodes, f = reconstruct_path(parent, s, t, residual)
        push!(paths, (nodes, f))

        for (u, v) in edges
            residual[u, v] -= f
        end
    end

    return paths
end

function tournament_cut(
    x::JuMP.Containers.DenseAxisArray,
    route::Vector{SolutionNode},
    data::Data,
    Γ::Int,
)
    n = length(route)
    V = data.V
    A = keys(data.A)
    l = [i.tw.l for i in V]

    α, _ = max_time_dependent_arrival(route, data, Γ)
    node_ids = [node.id for node in route]

    for k = 2:n
        if α[k, Γ] > l[node_ids[k]]
            if k == n
                inner_sum = sum(
                    x[(node_ids[i], node_ids[j])] for i = 2:(k-2) for
                    j = i+1:(k-1) if (node_ids[i], node_ids[j]) in A;
                    init = 0.0,
                )
                return @build_constraint(
                    inner_sum + x[(node_ids[k-1], node_ids[k])] <= (k - 3)
                )
            else
                inner_sum = sum(
                    x[(node_ids[i], node_ids[j])] for i = 2:(k-1) for
                    j = i+1:k if (node_ids[i], node_ids[j]) in A;
                    init = 0.0,
                )
                return @build_constraint(inner_sum <= (k - 3))
            end
        end
    end
    return nothing
end
