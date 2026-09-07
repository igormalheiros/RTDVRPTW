using JSON

mutable struct TimeWindow
    e::Float64 # Earliest time
    l::Float64 # Latest time
end

function Base.show(io::IO, tw::TimeWindow)
    print(io, "TimeWindow(e=", tw.e, ", l=", tw.l, ")")
end

mutable struct Vertex
    id::Int # Vertex ID
    x::Int # x-coordinate
    y::Int # y-coordinate
    tw::TimeWindow # Time window
    s::Float64 # Service time
    q::Int # Demand
end

function Base.show(io::IO, v::Vertex)
    print(
        io,
        "Vertex(id=",
        v.id,
        ", (",
        v.x,
        ", ",
        v.y,
        "), ",
        v.tw,
        ", q=",
        v.q,
        ", s=",
        v.s,
        ")",
    )
end

mutable struct ArcInfo
    c::Float64 # Cost
    k::Int # Cluster
    B̄::Vector{Tuple{Float64,Float64}} # Nominal breakpoints
    B̂::Vector{Tuple{Float64,Float64}} # Deviation breakpoints
end

function Base.show(io::IO, a::ArcInfo)
    print(io, "cost: ", a.c, ", cluster: ", a.k)
end

struct Digraph
    arc_count::Int
    arcs::Array{Array{Int,1},1}
    coordinates::Array{Array{Float64,1},1}
end

struct Data
    dataset_name::String
    n::Int # Number of vertices
    Q::Int # Vehicle capacity
    H::Float64 # Planning horizon
    o::Vertex # Origin vertex
    d::Vertex # Destination vertex
    V::Vector{Vertex} # Vertices
    A::Dict{Tuple{Int,Int},ArcInfo} # Arcs
    td_data::TimeDependentData
    deviation_rate::Float64
end

function extract_n_vertices(filename::String)
    m = match(r"_(\d+)\.json", filename)
    return m !== nothing ? parse(Int, m.captures[1]) : nothing
end

function read_json(filename::String, deviation_rate::Float64)
    instance_name = replace(split(filename, ("/"))[end], ".json" => "")

    json_data = JSON.parsefile(filename)
    digraph = Digraph(
        json_data["digraph"]["arc_count"],
        json_data["digraph"]["arcs"],
        json_data["digraph"]["coordinates"],
    )
    capacity = json_data["capacity"]
    cluster_count = json_data["cluster_count"]
    horizon = json_data["horizon"]
    number_of_zones = json_data["speed_zone_count"]

    cluster_speeds = json_data["cluster_speeds"]
    nom_cluster_speeds = Matrix{Float64}(transpose(hcat(cluster_speeds...)))

    speed_zones = json_data["speed_zones"]
    speed_zones = [speed_zones[i][1] for i = 1:number_of_zones]
    push!(speed_zones, horizon[2])

    time_windows = json_data["time_windows"]
    service_times = json_data["service_times"]
    demands = json_data["demands"]
    number_of_vertices = extract_n_vertices(filename)
    coordinates = digraph.coordinates
    vertices = Vertex[]

    o = Vertex(
        1,
        coordinates[1][1],
        coordinates[1][2],
        TimeWindow(time_windows[1][1], time_windows[1][2]),
        service_times[1],
        demands[1],
    )
    push!(vertices, o)

    for i = 1:number_of_vertices
        v = Vertex(
            i + 1,
            coordinates[i+1][1],
            coordinates[i+1][2],
            TimeWindow(time_windows[i+1][1], time_windows[i+1][2]),
            service_times[i+1],
            demands[i+1],
        )
        push!(vertices, v)
    end
    d = Vertex(
        number_of_vertices + 2,
        coordinates[number_of_vertices+2][1],
        coordinates[number_of_vertices+2][2],
        TimeWindow(
            time_windows[number_of_vertices+2][1],
            time_windows[number_of_vertices+2][2],
        ),
        service_times[number_of_vertices+2],
        demands[number_of_vertices+2],
    )
    push!(vertices, d)

    arcs = Dict{Tuple{Int,Int},ArcInfo}()
    distances_matrix =
        Matrix{Float64}(undef, number_of_vertices + 2, number_of_vertices + 2)
    κ = Dict{Tuple{Int,Int},Int}()

    for i = 1:number_of_vertices+2
        for j = 1:number_of_vertices+2
            κ[(i, j)] = json_data["clusters"][i][j] + 1
            distances_matrix[i, j] = json_data["distances"][i][j]
        end
    end

    nom_td_data = TimeDependentData(speed_zones, κ, nom_cluster_speeds, distances_matrix)

    for i = 1:number_of_vertices+2
        for j = 1:number_of_vertices+2
            c = distances_matrix[i, j]
            k = κ[(i, j)]

            B̄ = travel_time_breakpoints(nom_td_data, (i, j))
            B̂ = [
                (x - service_times[i], floor((y * deviation_rate) * 10e5) / 10e5) for
                (x, y) in B̄
            ]
            B̄ = [(x - service_times[i], y + service_times[i]) for (x, y) in B̄]
            @show length(B̄)
            @show length(B̂)
            arcs[(i, j)] = ArcInfo(c, k, B̄, B̂)
        end
    end

    return Data(
        instance_name,
        number_of_vertices,
        capacity,
        horizon[2],
        o,
        d,
        vertices,
        arcs,
        nom_td_data,
        deviation_rate,
    )
end

function preprocess(data::Data, budget::Int)
    n = data.n + 2
    A = data.A
    o = data.o
    d = data.d
    V = data.V
    td_data = data.td_data

    C = [v for v in V if v.id != o.id && v.id != d.id]

    B̄ = Dict([a => A[a].B̄ for a in keys(A)])
    B̂ = Dict([a => A[a].B̂ for a in keys(A)])

    nom_pwfs = Dict([a => build_segments(B̄[a]) for a in keys(A)])
    dev_pwfs = Dict([a => build_segments(B̂[a]) for a in keys(A)])

    e = [i.tw.e for i in V]
    l = [i.tw.l for i in V]

    init_arcs = length(keys(A))

    # Time-window tighning
    for k in C
        k_id = k.id
        o_e = o.tw.e
        o_s = o.s
        d_l = d.tw.l
        k_e = k.tw.e
        k_l = k.tw.l

        min_k_e = Inf
        for (i_id, j_id) in keys(A)
            i = V[i_id]
            i_e = i.tw.e

            if j_id == k_id
                min_k_e = min(min_k_e, Φ(td_data, i_e, (i_id, j_id)))
            end
        end
        k.tw.e = max(k_e, min_k_e) #(1)

        min_k_e = k_l
        for (i_id, j_id) in keys(A)
            j = V[j_id]
            j_e = j.tw.e

            if j_id == k_id
                min_k_e = min(min_k_e, Φ_inv(td_data, j_e, (i_id, j_id)))
            end
        end
        k.tw.e = max(k_e, min_k_e) #(2)

        max_k_l = k.tw.e
        for (i_id, j_id) in keys(A)
            i = V[i_id]
            i_l = i.tw.l

            if j_id == k_id
                max_k_l = max(max_k_l, Φ(td_data, i_l, (i_id, j_id)))
            end
        end
        k.tw.l = min(k.tw.l, max_k_l) #(3)

        max_k_l = k.tw.l
        for (i_id, j_id) in keys(A)
            j = V[j_id]
            j_l = j.tw.l

            if i_id == k_id
                max_k_l = max(max_k_l, Φ_inv(td_data, j_l, (i_id, j_id)))
            end
        end
        k.tw.l = min(k.tw.l, max_k_l) #(4)
    end

    e = [i.tw.e for i in V]
    l = [i.tw.l for i in V]

    for i = 1:n
        for j = 1:n
            if i == j || # self-loop
               i == d.id || # arcs coming from destination depot
               j == o.id || # arcs going to origin depot
               (i == o.id && j == d.id) || # arcs from origin depot to destination depot
               e[i] + bs_piecewise_affine_t(e[i], nom_pwfs[(i, j)]) > l[j] || # infeasible tw arcs
               (
                   budget > 0 &&
                   e[i] +
                   bs_piecewise_affine_t(e[i], nom_pwfs[(i, j)]) +
                   bs_piecewise_affine_t(e[i], dev_pwfs[(i, j)]) > l[j] # infeasible tw arcs with deviation
               )
                delete!(A, (i, j))
            end
        end
    end
    init_bps = sum(length(B̄[a]) for a in keys(A))
    init_dev_bps = sum(length(B̂[a]) for a in keys(A))
    for i = 1:n
        for j = 1:n
            if (i, j) in keys(A)
                B̄_ij = B̄[(i, j)]
                B̂_ij = B̂[(i, j)]

                xs = [x′ for (x′, _) in B̄_ij if x′ <= e[i]]
                if !isempty(xs)
                    x′ = maximum(xs)
                    filter!(pair -> !(pair[1] < x′), B̄_ij) # lower bound doimain of B̄_ij
                end

                xs = [x′ for (x′, _) in B̄_ij if x′ >= l[i]]
                if !isempty(xs)
                    x′ = minimum(xs)
                    filter!(pair -> !(pair[1] > x′), B̄_ij) # upper bound domain of B̄_ij
                end

                xs = [x′ for (x′, _) in B̂_ij if x′ <= e[i]]
                if !isempty(xs)
                    x′ = maximum(xs)
                    filter!(pair -> !(pair[1] < x′), B̂_ij) # lower bound domain of B̂_ij
                end

                xs = [x′ for (x′, _) in B̂_ij if x′ >= l[i]]
                if !isempty(xs)
                    x′ = minimum(xs)
                    filter!(pair -> !(pair[1] > x′), B̂_ij) # upper bound domain of B̂_ij
                end
            end
        end
    end
end

function Base.show(io::IO, data::Data)
    println("****************************************")
    println(io, "\nInstance: ", data.dataset_name)
    println(io, "Number of Vertices (n): ", data.n)
    println(io, "Vehicle Capacity (Q): ", data.Q)
    println(io, "Planning Horizon (H): ", data.H)
    println(io, "Origin Vertex (o): ", data.o)
    println(io, "Destination Vertex (d): ", data.d)
    println(io, "Vertices:")
    for v in data.V
        println(io, v)
    end
end
