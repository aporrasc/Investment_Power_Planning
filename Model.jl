using JuMP
using JSON
using HiGHS
using Gurobi

data = JSON.parsefile("input_data.json")

# Input Data
time_range = 1:100 # Horizon of Simulation
share = 0.5 # Share of Renewable Production

# Optimization Model
model = Model(HiGHS.Optimizer)
# model = Model(Gurobi.Optimizer)

# Define Variables
# Production
@variable(model,p[keys(data["load"]),["base","peak","wind","solar","hydro"],time_range] >= 0) # Dispatch
@variable(model,P[keys(data["load"]),["base","peak","wind","solar","hydro"]] >= 0) # Capacity
# Storage
@variable(model,s[keys(data["load"]),["intra","inter"],time_range] >= 0) # State
@variable(model,c[keys(data["load"]),["intra","inter"],time_range] >= 0) # Charging
@variable(model,d[keys(data["load"]),["intra","inter"],time_range] >= 0) # Discharging
@variable(model,S[keys(data["load"]),["intra","inter"]] >= 0) # Capacity
# Line
@variable(model,f[keys(data["line"]),time_range]) # flow
@variable(model,F[keys(data["line"])] >= 0) # capacity

# Define Objective Function
@objective(model, Min, sum(data["techno"][tech]["capex"]*P[n,tech]  for n in keys(data["load"]) for tech in ["base","peak","wind","solar"]) +
                       sum(data["techno"][tech]["opex"]*p[n,tech,t]   for n in keys(data["load"]) for tech in ["base","peak","wind","solar"] for t in time_range) +
                       sum(data["techno"][tech]["capex"]*S[n,tech]  for n in keys(data["load"]) for tech in ["intra","inter"]) +
                       sum(data["techno"]["line"]["capex"]*data["line"][l]["length"]*F[l] for l in keys(data["line"])))

# Define Constraints
# Balance
@constraint(model, balance[n=keys(data["load"]), t=time_range], sum(p[n,tech,t] for tech in ["base","peak","wind","solar","hydro"]) 
                                                              + sum(d[n,tech,t] - c[n,tech,t] for tech in ["intra","inter"]) 
                                                              + sum(f[string(m,"-",n),t] for m in data["line_map"][n]["in"])
                                                              == data["load"][n][t]
                                                              + sum(f[string(n,"-",m),t] for m in data["line_map"][n]["out"]))
# Potentials
@constraint(model, potential_p[n=keys(data["load"]), tech=["wind","solar","hydro"]], P[n,tech] <= data[tech][n]["potential"])
@constraint(model, potential_f[l=keys(data["line"])], F[l] <= data["line"][l]["potential"])

# Max Capacity
@constraint(model,max_p[n=keys(data["load"]),tech=["base","peak","hydro"],t=time_range], p[n,tech,t] <= P[n,tech])
@constraint(model,max_r[n=keys(data["load"]),tech=["solar","wind"],t=time_range], p[n,tech,t] <= data[tech][n]["cap_factor"][t]*P[n,tech])
@constraint(model,max_i[l=keys(data["line"]),t=time_range], f[l,t] <=  F[l])
@constraint(model,max_o[l=keys(data["line"]),t=time_range], f[l,t] >= -F[l])
@constraint(model,max_c[n=keys(data["load"]),tech=["intra","inter"],t=time_range], c[n,tech,t] <= S[n,tech])
@constraint(model,max_d[n=keys(data["load"]),tech=["intra","inter"],t=time_range], d[n,tech,t] <= S[n,tech])
@constraint(model,max_s[n=keys(data["load"]),tech=["intra","inter"],t=time_range], s[n,tech,t] <= data["techno"][tech]["cap"]*S[n,tech])

# Ramp
@constraint(model, ramp_d[n=keys(data["load"]),t=time_range[2:end]], p[n,"base",t] - p[n,"base",t-1] >= -data["techno"]["base"]["ramp"]*P[n,"base"])
@constraint(model, ramp_u[n=keys(data["load"]),t=time_range[2:end]], p[n,"base",t] - p[n,"base",t-1] <=  data["techno"]["base"]["ramp"]*P[n,"base"])

# State of Charge
@constraint(model, soc[n=keys(data["load"]),tech=["intra","inter"],t=time_range[2:end]], s[n,tech,t] == s[n,tech,t-1] + data["techno"][tech]["eff"]*c[n,tech,t] - d[n,tech,t])

# Cyclic Condition
# @constraint(model, cc[n=keys(data["load"]),tech=["intra","inter"]], s[n,tech,time_range[begin]] == s[n,tech,time_range[end]])

# Renewable Target
# As it should be done in real practice
# @constraint(model, rt, sum(p[n,tech,t] for n in keys(data["load"]) for tech in ["wind","solar","hydro"] for t in time_range) >= 0.5*sum(data["load"][n][t] for n in keys(data["load"]) for t in time_range))
# As in the paper
# @constraint(model, rt, sum(p[n,tech,t] for n in keys(data["load"]) for tech in ["wind","solar"] for t in time_range) >= 0.5*sum(p[n,tech,t] for n in keys(data["load"]) for tech in ["base","peak"] for t in time_range))

# Annual hydro factor
# @constraint(model, annual_hydro[n=keys(data["load"])], sum(p[n,"hydro",t] for t in time_range) <= data["hydro"][n]["annual_cap_factor"]*sum(P[n,"hydro"] for t in time_range))
# Spine Implementation
@constraint(model, annual_hydro[n=keys(data["load"]),t=time_range], p[n,"hydro",t] <= data["hydro"][n]["annual_cap_factor"]*P[n,"hydro"])

# Solve the optimization problem
optimize!(model)

println("Base Capacity: ",round(sum(value(P[n,"base"]) for n in keys(data["load"]))/1000;digits=3))
println("Peak Capacity: ",round(sum(value(P[n,"peak"]) for n in keys(data["load"]))/1000;digits=3))
println("Wind Capacity: ",round(sum(value(P[n,"wind"]) for n in keys(data["load"]))/1000;digits=3))
println("Solar Capacity: ",round(sum(value(P[n,"solar"]) for n in keys(data["load"]))/1000;digits=3))
println("Hydro Capacity: ",round(sum(value(P[n,"hydro"]) for n in keys(data["load"]))/1000;digits=3))
println("Intra Capacity: ",round(sum(value(S[n,"intra"]) for n in keys(data["load"]))/1000;digits=3))
println("Inter Capacity: ",round(sum(value(S[n,"inter"]) for n in keys(data["load"]))/1000;digits=3))
println("Line Capacity: ",round(sum(value(F[l]) for l in keys(data["line"]))/1000;digits=3))

println("Capital Cost: ", round((sum(data["techno"][tech]["capex"]*value(P[n,tech])  for n in keys(data["load"]) for tech in ["base","peak","wind","solar"]) +
                          sum(data["techno"][tech]["capex"]*value(S[n,tech])  for n in keys(data["load"]) for tech in ["intra","inter"]) +
                          sum(data["techno"]["line"]["capex"]*data["line"][l]["length"]*value(F[l]) for l in keys(data["line"])))/1e9; digits=3))