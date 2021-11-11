module BooleanNetworks
export zerocfg, load_bnet, fasync_simulations

struct BooleanNetwork
    nodes::Vector{String}
    index::Dict{String,Int64}
    f::Vector{Function}
    out_influences::Vector{Vector{Int64}} # out-going influences
end

zerocfg(bn) = zeros(Bool, length(bn.f))

BNET_SYMBOL_RE = r"[\w\.:]+"

function load_bnet(filename, sep=",", impl_binary=false)
    data = [split(line, sep) for line in eachline(filename)]
    n = length(data)
    nodes = [strip(d[1]) for d in data]
    index = Dict(((n,i) for (i,n) in enumerate(nodes)))

    impl_expr_bool(expr) = "x -> " * replace(replace(expr,
            "!" => "~"),
             BNET_SYMBOL_RE => x -> "x[$(index[x])]")
    impl_expr_bin(expr) = "x -> " * replace(replace(replace(expr,
            "|" => "||"),
            "&" => "&&"),
             BNET_SYMBOL_RE => x -> "x[$(index[x])]")
    impl_expr = impl_binary ? impl_expr_bin : impl_expr_bool
    make_expr = eval ∘ Meta.parse ∘ impl_expr
    f = [make_expr(d[2]) for d in data]

    make_influences(expr) = [index[m.match] for m in eachmatch(BNET_SYMBOL_RE, expr)]
    influences = [make_influences(d[2]) for d in data]

    BooleanNetwork(nodes, index, f, influences)
end

struct FAsyncSimulationContext
    x::Vector{Bool}
    c::Vector{Int64}
end
new_fasync_simulation(n) = FAsyncSimulationContext(Vector{Bool}(undef, n), Vector{Int64}(undef, n))

function _fasync_step!(x, c, f, n)
    nc = 0
    for i in 1:n
        if f[i](x) ⊻ x[i]
            nc += 1
            c[nc] = i
        end
    end
    if nc == 0
        0
    else
        if nc == 1
            i = c[1]
        else
            i = c[rand(1:nc)]
        end
        x[i] = !x[i]
        i
    end
end

_fasync_unroll!(ctx, f, n, maxsteps) =
    for _ in 1:maxsteps
        if _fasync_step!(ctx.x, ctx.c, f, n) == 0
            break
        end
    end

function _fasync_simulation!(ctx, f, n, x, maxsteps, outputs)
    ctx.x[1:n] = x
    _fasync_unroll!(ctx, f, n, maxsteps)
    @view ctx.x[outputs]
end

function make_number(binarray)
    x::Int64 = 0
    for i in 1:length(binarray)
        x |= binarray[i] << (i-1)
    end
    x
end
function fasync_simulations(bn, outputs, nb_sims, maxsteps, x)
    f = bn.f
    n = length(f)
    res = Array{Int64}(undef, nb_sims)
    ctx = new_fasync_simulation(n)
    for i in 1:nb_sims
        res[i] = make_number(_fasync_simulation!(ctx, f, n, x, maxsteps, outputs))
    end
    res
end
function fasync_simulations(bn, outputs, nb_sims, maxsteps, x, free_nodes)
    f = bn.f
    n = length(f)
    x = copy(x)
    res = Array{Int64}(undef, nb_sims)
    ctx = new_fasync_simulation(n)
    for i in 1:nb_sims
        x[free_nodes] = rand(Bool, length(free_nodes))
        res[i] = make_number(_fasync_simulation!(ctx, f, n, x, maxsteps, outputs))
    end
    res
end

end
