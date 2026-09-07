struct SolutionNode
    id::Int
    load::Int
    arrival::Float64
end

struct Solution
    obj::Float64
    routes::Vector{Vector{SolutionNode}}
    data::Data
end

function Solution(routes::Vector{Vector{Int}}, data::Data)
    V = data.V
    A = keys(data.A)
    n = data.n + 2
    o = data.o.id
    d = data.d.id
    e = [i.tw.e for i in V]
    s = [i.s for i in V]
    q = [i.q for i in V]
    c = Dict([a => data.A[a].c for a in A])
    nom_td_data = data.td_data
    deviation_rate = data.deviation_rate

    B̄ = Dict([a => data.A[a].B̄ for a in A])
    B̂ = Dict([a => data.A[a].B̂ for a in A])

    for a in A
        B̄[a] = travel_time_breakpoints(nom_td_data, a)
        B̂[a] = [(x, floor((y * deviation_rate) * 10e5) / 10e5) for (x, y) in B̄[a]]
    end

    nom_pwfs = Dict([a => build_segments(B̄[a]) for a in A])
    dev_pwfs = Dict([a => build_segments(B̂[a]) for a in A])

    obj = 0.0
    sol_routes = Vector{SolutionNode}[]
    for route in routes
        sol_route = [SolutionNode(o, q[o], e[o])]
        for idx = 2:(length(route)-1)
            i = route[idx]
            obj += c[(sol_route[end].id, i)]
            push!(
                sol_route,
                SolutionNode(
                    i,
                    sol_route[end].load + q[i],
                    max(
                        e[i],
                        sol_route[end].arrival +
                        s[sol_route[end].id] +
                        bs_piecewise_affine_t(
                            sol_route[end].arrival + s[sol_route[end].id],
                            nom_pwfs[(sol_route[end].id, i)],
                        ),
                    ),
                ),
            )
        end
        obj += c[(sol_route[end].id, d)]
        push!(
            sol_route,
            SolutionNode(
                d,
                sol_route[end].load + q[d],
                max(
                    e[d],
                    sol_route[end].arrival +
                    s[sol_route[end].id] +
                    bs_piecewise_affine_t(
                        sol_route[end].arrival + s[sol_route[end].id],
                        nom_pwfs[(sol_route[end].id, d)],
                    ),
                ),
            ),
        )
        push!(sol_routes, sol_route)
    end

    return Solution(obj, sol_routes, data)
end

function Solution(x, data::Data)
    obj = 0

    routes = Vector{SolutionNode}[]
    V = data.V
    A = keys(data.A)
    n = data.n + 2
    o = data.o.id
    d = data.d.id
    e = [i.tw.e for i in V]
    s = [i.s for i in V]
    q = [i.q for i in V]
    c = Dict([a => data.A[a].c for a in A])
    nom_td_data = data.td_data
    deviation_rate = data.deviation_rate

    B̄ = Dict([a => data.A[a].B̄ for a in A])
    B̂ = Dict([a => data.A[a].B̂ for a in A])

    for a in A
        B̄[a] = travel_time_breakpoints(nom_td_data, a)
        B̂[a] = [(x, floor((y * deviation_rate) * 10e5) / 10e5) for (x, y) in B̄[a]]
    end

    nom_pwfs = Dict([a => build_segments(B̄[a]) for a in A])
    dev_pwfs = Dict([a => build_segments(B̂[a]) for a in A])

    for i = 1:n
        if (o, i) in A && value(x[(o, i)]) > 0.1
            v = i
            obj += c[(o, i)]

            push!(routes, [SolutionNode(o, 0, e[o])])
            push!(
                routes[end],
                SolutionNode(
                    i,
                    routes[end][end].load + q[i],
                    max(
                        e[i],
                        routes[end][end].arrival +
                        s[o] +
                        bs_piecewise_affine_t(
                            routes[end][end].arrival + s[o],
                            nom_pwfs[(o, i)],
                        ),
                    ),
                ),
            )
            while v != d
                for j = 1:n
                    if (v, j) in A && value(x[(v, j)]) > 0.5
                        obj += c[(v, j)]

                        push!(
                            routes[end],
                            SolutionNode(
                                j,
                                routes[end][end].load + q[j],
                                max(
                                    e[j],
                                    routes[end][end].arrival +
                                    s[v] +
                                    bs_piecewise_affine_t(
                                        routes[end][end].arrival + s[v],
                                        nom_pwfs[(v, j)],
                                    ),
                                ),
                            ),
                        )
                        v = j
                        break
                    end
                end
            end
        end
    end
    return Solution(obj, routes, data)
end

function build_path(sequence::Vector{Int}, data::Data)
    V = data.V
    A = keys(data.A)
    nom_td_data = data.td_data
    deviation_rate = data.deviation_rate

    B̄ = Dict([a => data.A[a].B̄ for a in A])
    B̂ = Dict([a => data.A[a].B̂ for a in A])

    for a in A
        B̄[a] = travel_time_breakpoints(nom_td_data, a)
        B̂[a] = [(x, floor((y * deviation_rate) * 10e5) / 10e5) for (x, y) in B̄[a]]
    end

    nom_pwfs = Dict([a => build_segments(B̄[a]) for a in A])


    path = Vector{SolutionNode}()
    seq_n = length(sequence)
    u = sequence[1]
    load = V[u].q
    arrival = V[u].tw.e
    node = SolutionNode(u, load, arrival)
    push!(path, node)
    for i = 2:seq_n
        v = sequence[i]

        load += V[v].q
        arrival = max(
            V[v].tw.e,
            arrival + V[u].s + bs_piecewise_affine_t(arrival + V[u].s, nom_pwfs[(u, v)]),
        )
        node = SolutionNode(v, load, arrival)
        push!(path, node)
        u = v
    end
    return path
end

function vertex_status(solution::Solution, v::Int, data::Data)
    real_id = v - 1
    w = @sprintf("%.2f", solution.w[v])
    y = @sprintf("%.2f", solution.y[v])
    tw_e = @sprintf("%.2f", data.V[v].tw.e)
    tw_l = @sprintf("%.2f", data.V[v].tw.l)

    # return "$v: ($(solution.w[v]), $(solution.y[v])/$(data.V[v].tw.l))"
    return "$real_id: ($w, $y/[$tw_e, $tw_l])"
    # return "$real_id: ($(solution.y[v])/$(data.V[v].tw.l))"
end

function Base.show(io::IO, solution::Solution)
    println(io, "Objective Value: ", solution.obj)
    routes = solution.routes
    n_routes = length(solution.routes)
    println(io, "Total Routes: ", n_routes)

    data = solution.data
    A = keys(data.A)
    nom_td_data = data.td_data
    deviation_rate = data.deviation_rate
    Q = data.Q
    V = data.V

    e = [i.tw.e for i in V]
    l = [i.tw.l for i in V]

    B̄ = Dict([a => data.A[a].B̄ for a in A])
    B̂ = Dict([a => data.A[a].B̂ for a in A])

    # for a in A
    #     B̄[a] = travel_time_breakpoints(nom_td_data, a)
    #     B̂[a] = [(x, floor((y * deviation_rate) * 10e5) / 10e5) for (x, y) in B̄[a]]
    # end

    nom_pwfs = Dict([a => build_segments(B̄[a]) for a in A])
    dev_pwfs = Dict([a => build_segments(B̂[a]) for a in A])

    for r = 1:n_routes
        route = routes[r]
        print(io, "Route ", r, " (", Q, "): ")
        for i = 1:length(route)
            node = route[i]
            load_str = @sprintf("%.2f", node.load)
            arrival_str = @sprintf("%.2f", node.arrival)
            e_str = @sprintf("%.2f", e[node.id])
            l_str = @sprintf("%.2f", l[node.id])
            print(
                io,
                node.id,
                ", ",
            )
        end
        println(io, "")
    end
end

function visit_constraints(solution::Solution, data::Data)
    n = data.n + 2
    o = data.o.id
    d = data.d.id
    visits = falses(n)
    visits[o] = visits[d] = true
    routes = solution.routes
    for route in routes
        if route[1].id != o
            error("Route does not start at origin: $(route[1].id) != $o")
            return false
        end
        if route[end].id != d
            error("Route does not end at destination: $(route[end].id) != $d")
            return false
        end
        for node in route
            visits[node.id] = true
        end
    end
    return all(visits)
end

function capacity_constraints(solution::Solution, data::Data)
    n = data.n + 2
    Q = data.Q
    routes = solution.routes
    for route in routes
        load = 0
        for node in route
            if node.load > Q
                error("Capacity violation on route: load $load exceeds capacity $Q")
                return false
            end
        end
    end
    return true
end

function time_window_constraints(solution::Solution, data::Data)
    n = data.n + 2
    o = data.o
    routes = solution.routes
    for route in routes
        for node in route
            node_id = node.id
            if !(
                data.V[node_id].tw.e <= node.arrival &&
                node.arrival <= data.V[node_id].tw.l
            )
                error(
                    "Time window violation at node $node_id: arrival $(node.arrival), expected [$(data.V[node_id].tw.e), $(data.V[node_id].tw.l)]",
                )
                return false
            end
        end
    end
    return true
end

function max_time_dependent_arrival(route::Vector{SolutionNode}, data::Data, Γ::Int)
    V = data.V
    A = keys(data.A)
    e = [i.tw.e for i in V]
    s = [i.s for i in V]
    o = data.o
    d = data.d
    B̄ = Dict([a => data.A[a].B̄ for a in A])
    B̂ = Dict([a => data.A[a].B̂ for a in A])
    nom_pwfs = Dict([a => build_segments(B̄[a]) for a in A])
    dev_pwfs = Dict([a => build_segments(B̂[a]) for a in A])

    n = length(route)
    α = OffsetArray(zeros(n, Γ + 1), 1:n, 0:Γ)
    mask = OffsetArray(falses(n, Γ + 1), 1:n, 0:Γ)

    # Base case for origin
    for γ = 0:Γ
        α[1, γ] = e[o.id]
        mask[1, γ] = false
    end

    for i = 2:length(route)
        v_prev = route[i-1]
        v_curr = route[i]

        # Deterministic case
        α[i, 0] = max(
            e[v_curr.id],
            α[i-1, 0] + bs_piecewise_affine_t(α[i-1, 0], nom_pwfs[(v_prev.id, v_curr.id)]),
        )
        mask[i, 0] = false

        # Robust case
        for γ = 1:Γ
            nom_arrival =
                α[i-1, γ] +
                bs_piecewise_affine_t(α[i-1, γ], nom_pwfs[(v_prev.id, v_curr.id)])

            dev_arrival =
                α[i-1, γ-1] +
                bs_piecewise_affine_t(α[i-1, γ-1], nom_pwfs[(v_prev.id, v_curr.id)]) +
                bs_piecewise_affine_t(α[i-1, γ-1], dev_pwfs[(v_prev.id, v_curr.id)])

            if dev_arrival > nom_arrival && dev_arrival > e[v_curr.id]
                α[i, γ] = dev_arrival
                mask[i, γ] = true
            else
                α[i, γ] = max(e[v_curr.id], nom_arrival)
                mask[i, γ] = false
            end
        end
    end
    return α, mask
end

function robust_constraints(solution::Solution, data::Data, Γ::Int)
    nom_td_data = data.td_data
    deviation_rate = data.deviation_rate
    o = data.o
    d = data.d
    A = keys(data.A)
    V = data.V
    e = [i.tw.e for i in data.V]
    l = [i.tw.l for i in data.V]
    s = [i.s for i in data.V]

    routes = solution.routes
    for route in routes
        α, _ = max_time_dependent_arrival(route, data, Γ)
        # println(α[:, Γ])
        if any([α[i, Γ] > l[v.id] for (i, v) in enumerate(route)])
            return false
        end
    end
    return true
end

function objective(solution::Solution, data::Data)
    obj = 0.0
    for route in solution.routes
        prev_node = route[1]
        for node in route
            if node.id != data.o.id
                obj += data.A[(prev_node.id, node.id)].c
                prev_node = node
            end
        end
    end
    return obj
end
