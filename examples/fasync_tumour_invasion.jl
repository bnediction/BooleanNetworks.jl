using BooleanNetworks

import Random
Random.seed!(1234)

model = "models/Tumour_invasion.bnet"
outputs = ["Apoptosis"; "CellCycleArrest"; "Invasion"; "Metastasis"; "Migration"]
free_nodes = ["DNAdamage", "ECMicroenv"]

bn = load_bnet("models/Tumour_invasion.bnet")

outputs = [bn.index[node] for node in outputs]
free_nodes = [bn.index[node] for node in free_nodes]

x0 = zerocfg(bn)
for i in free_nodes
    x0[i] = true
end

# warm-up
fasync_simulations(bn, outputs, 1, 1, x0)
fasync_simulations(bn, outputs, 1, 1, x0, free_nodes)

#using BenchmarkTools

nb_sims = 10000
maxsteps = 500
for _ in 1:4
    println("Performing $nb_sims simulations of at most $maxsteps from fixed initial configuration")
    @time fasync_simulations(bn, outputs, nb_sims, maxsteps, x0);
end

using Profile
@profile fasync_simulations(bn, outputs, nb_sims, maxsteps, x0);
Profile.print()
