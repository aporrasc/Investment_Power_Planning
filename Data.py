import pandas as pd
import json

wind_av = pd.read_excel("Profiles.xlsx","w_fac",index_col=0)
solar_av = pd.read_excel("Profiles.xlsx","x_fac",index_col=0)
load = pd.read_excel("Profiles.xlsx","d_lev",index_col=0)

line = pd.read_excel("Capacity.xlsx","line")
inve = pd.read_excel("Capacity.xlsx","investment",index_col=0)
stor = pd.read_excel("Capacity.xlsx","storage",index_col=0)
unit = pd.read_excel("Capacity.xlsx","unit",index_col=0)

data = {}
data["load"] = {}
data["hydro"] = {}
data["wind"] = {}
data["solar"] = {}
data["line"] = {}
data["line_map"] = {}
data["techno"] = {}

for country in load.columns:
    data["load"][country] = {}
    data["wind"][country] = {}
    data["solar"][country] = {}
    data["hydro"][country] = {}
    data["line_map"][country] = {}

    data["load"][country] = load[country].astype(float).to_list()
    data["hydro"][country]["annual_cap_factor"] = unit.at[country,"av_hydro"].astype(float)
    data["wind"][country]["cap_factor"]  = wind_av["wind-"+country].astype(float).to_list()
    data["solar"][country]["cap_factor"] = solar_av["solar-"+country].astype(float).to_list()
    data["hydro"][country]["potential"] = unit.at[country,"hydro"]*1000
    data["wind"][country]["potential"] = unit.at[country,"wind"]*1000
    data["solar"][country]["potential"] = unit.at[country,"solar"]*1000
    data["line_map"][country]["out"] = line[line["From"] == country]["To"].to_list()
    data["line_map"][country]["in"]  = line[line["To"] == country]["From"].to_list()

for i in line.index:
    index = line.at[i,"From"]+'-'+line.at[i,"To"]
    data["line"][index] = {}
    data["line"][index]["potential"] = line.at[i,"Max_Cap"]*1000
    data["line"][index]["length"] = float(line.at[i,"Length"])

data["techno"]["peak"] = {}
data["techno"]["base"] = {}
data["techno"]["wind"] = {}
data["techno"]["solar"] = {}
data["techno"]["intra"] = {}
data["techno"]["inter"] = {}
data["techno"]["line"] = {}

data["techno"]["base"]["capex"] = inve.at["base","inv_eur"]/inve.at["base","life_time"]
data["techno"]["peak"]["capex"] = inve.at["peak","inv_eur"]/inve.at["peak","life_time"]
data["techno"]["wind"]["capex"] = inve.at["wind","inv_eur"]/inve.at["wind","life_time"]
data["techno"]["solar"]["capex"] = inve.at["solar","inv_eur"]/inve.at["solar","life_time"]
data["techno"]["intra"]["capex"] = stor.at["intraday","inv_eur"]/stor.at["intraday","life_time"]
data["techno"]["inter"]["capex"] = stor.at["interday","inv_eur"]/stor.at["interday","life_time"]
data["techno"]["line"]["capex"] = line.at[0,"inv_eur"]/line.at[0,"life_time"]

data["techno"]["base"]["opex"] = float(inve.at["base","vom"])
data["techno"]["peak"]["opex"] = float(inve.at["peak","vom"])
data["techno"]["wind"]["opex"] = float(inve.at["wind","vom"])
data["techno"]["solar"]["opex"] = float(inve.at["solar","vom"])

data["techno"]["base"]["ramp"] = float(inve.at["base","ramp"])
data["techno"]["peak"]["ramp"] = float(inve.at["peak","ramp"])
data["techno"]["wind"]["ramp"] = float(inve.at["wind","ramp"])
data["techno"]["solar"]["ramp"] = float(inve.at["solar","ramp"])

data["techno"]["intra"]["cap"] = stor.at["intraday","cap"].astype(float)
data["techno"]["inter"]["cap"] = stor.at["interday","cap"].astype(float)
data["techno"]["intra"]["eff"] = stor.at["intraday","eff"]
data["techno"]["inter"]["eff"] = stor.at["interday","eff"]

with open("input_data.json", "w") as outfile:
    json.dump(data, outfile)

breakpoint()
