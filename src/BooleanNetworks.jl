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
    bn
    n
    x
    c
end
new_fasync_simulation(bn) = FAsyncSimulationContext(bn, length(bn.f),
        Vector{Bool}(undef, length(bn.f)),
        Vector{Int64}(undef, length(bn.f))
    )

function fasync_step!(ctx)
    c = 0
    for i in 1:ctx.n
        if ctx.bn.f[i](ctx.x) ⊻ ctx.x[i]
            c += 1
            ctx.c[c] = i
        end
    end
    if c == 0
        0
    else
        if c == 1
            i = ctx.c[1]
        else
            i = ctx.c[rand(1:c)]
        end
        ctx.x[i] = !ctx.x[i]
        i
    end
end

_fasync_unroll!(ctx, maxsteps) =
    for _ in 1:maxsteps
        if fasync_step!(ctx) == 0
            break
        end
    end

function _fasync_simulation!(ctx, x, maxsteps, outputs)
    ctx.x[1:ctx.n] = x
    _fasync_unroll!(ctx, maxsteps)
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
    res = Array{Int64}(undef, nb_sims)
    ctx = new_fasync_simulation(bn)
    for i in 1:nb_sims
        res[i] = make_number(_fasync_simulation!(ctx, x, maxsteps, outputs))
    end
    res
end
function fasync_simulations(bn, outputs, nb_sims, maxsteps, x, free_nodes)
    x = copy(x)
    res = Array{Int64}(undef, nb_sims)
    ctx = new_fasync_simulation(bn)
    for i in 1:nb_sims
        x[free_nodes] = rand(Bool, length(free_nodes))
        res[i] = make_number(_fasync_simulation!(ctx, x, maxsteps, outputs))
    end
    res
end

end
