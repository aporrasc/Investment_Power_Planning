using JuMP
using JSON
using HiGHS

# cap_data = XLSX.readdata("Capacity.xlsx","")
data = JSON.parsefile("input_data.json")

# Time period run
time_range = 1:500

# Optimization Model
model = Model(HiGHS.Optimizer)

# Define Variables
# Production
@variable(model,p[keys(data["load"]),["base","peak","wind","solar","hydro"],time_range]) # Dispatch
@variable(model,P[keys(data["load"]),["base","peak","wind","solar","hydro"]]) # Capacity
# Storage
@variable(model,s[keys(data["load"]),["intra","inter"],time_range]) # State
@variable(model,c[keys(data["load"]),["intra","inter"],time_range]) # Charging
@variable(model,d[keys(data["load"]),["intra","inter"],time_range]) # Discharging
@variable(model,S[keys(data["load"]),["intra","inter"]]) # Capacity
# Line
@variable(model,f[keys(data["line"]),time_range]) # flow
@variable(model,F[keys(data["line"])]) # capacity

# Define Objective Function
@objective(model, Min, sum(data["techno"][tech]["capex"]*P[n,tech]  for n in keys(data["load"]) for tech in ["base","peak","wind","solar"]) +
                       sum(data["techno"][tech]["opex"]*p[n,tech,t]   for n in keys(data["load"]) for tech in ["base","peak","wind","solar"] for t in time_range) +
                       sum(data["techno"][tech]["capex"]*S[n,tech]  for n in keys(data["load"]) for tech in ["intra","inter"]) +
                       sum(data["techno"]["line"]["capex"]*data["line"][l]["length"]*F[l] for l in keys(data["line"])))

# Define Constraints