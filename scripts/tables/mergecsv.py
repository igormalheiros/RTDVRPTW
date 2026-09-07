import pandas as pd
import numpy as np

# Read the CSVs
RAW_DIR = "data/results/raw"
df_cf = pd.read_csv(f"{RAW_DIR}/benchmark_results_CF.csv", sep=",")
df_tif = pd.read_csv(f"{RAW_DIR}/benchmark_results_TIF.csv", sep=",")
df_crg = pd.read_csv(f"{RAW_DIR}/benchmark_results_CRG.csv", sep=",")
df_ils = pd.read_csv(f"{RAW_DIR}/benchmark_results_ILS.csv", sep=";")

# Merge CF, TIF, CRG
key_cols = ["Instance", "Size", "Budget", "Dev"]

df_crg = df_crg.rename(lambda x: f"{x}_CRG" if x not in key_cols else x, axis=1)
df_ils = df_ils.rename(lambda x: f"{x}_ILS" if x not in key_cols else x, axis=1)

df_merge = df_cf.merge(
    df_tif,
    on=key_cols,
    suffixes=('_CF', '_TIF'),
    how="outer"
).merge(
    df_crg,
    on=key_cols,
    suffixes=('', '_CRG'),
    how="outer"
)

# Merge with ILS
df_all = df_merge.merge(
    df_ils,
    on=key_cols,
    how="outer",
    suffixes=('', '_ILS')
)

# Extract UB columns
df_all["UB_CF"] = df_all["UB_CF"]
df_all["UB_TIF"] = df_all["UB_TIF"]
df_all["UB_CRG"] = df_all["UB_CRG"]
df_all["UB_ILS"] = df_all["Best_ILS"]

df_all["UB_CRG_valid"] = df_all.apply(
    lambda row: row["UB_CRG"] if row["UB_CRG"] == row["LB_CRG"] else np.nan,
    axis=1
)

# Compute BKS
df_all["BKS"] = df_all[["UB_CF", "UB_TIF", "UB_ILS", "UB_CRG_valid"]].min(axis=1)

# Prepare lower bounds
df_all["LB_CF"] = df_all["LB_CF"]
df_all["LB_TIF"] = df_all["LB_TIF"]
df_all["LB_CRG"] = df_all["LB_CRG"]

# Compute gaps using: (BKS - LB) / BKS * 100
df_all["gap_CF"] = ((df_all["BKS"] - df_all["LB_CF"]) / df_all["BKS"] * 100).round(2)
df_all["Opt_CF"] = (df_all["LB_CF"] == df_all["BKS"]).astype(int)

df_all["gap_TIF"] = ((df_all["BKS"] - df_all["LB_TIF"]) / df_all["BKS"] * 100).round(2)
df_all["Opt_TIF"] = (df_all["LB_TIF"] == df_all["BKS"]).astype(int)

df_all["gap_CRG"] = ((df_all["BKS"] - df_all["LB_CRG"]) / df_all["BKS"] * 100).round(2)
df_all["Opt_CRG"] = (df_all["LB_CRG"] == df_all["BKS"]).astype(int)

# Compute ILS gaps
df_all["gap_ILS_best"] = ((df_all["Best_ILS"] - df_all["BKS"]) / df_all["BKS"] * 100).round(2)
df_all["gap_ILS_avg"] = ((df_all["Avg_ILS"] - df_all["BKS"]) / df_all["BKS"] * 100).round(2)
df_all["Opt_ILS"] = (df_all["Best_ILS"] == df_all["BKS"]).astype(int)

# Columns order for final CSV
cols = [
    "Instance", "Size", "Budget", "Dev",
    "UB_CF", "UB_TIF", "UB_CRG", "UB_ILS", "BKS",
    "LB_CF", "gap_CF", "Opt_CF", "gap_root_CF", "Tree_CF", "Runtime_CF",
    "LB_TIF", "gap_TIF", "Opt_TIF", "gap_root_TIF", "Tree_TIF", "TIF_cuts", "Runtime_TIF",
    "LB_CRG", "gap_CRG", "Opt_CRG", "gap_root_CRG", "Tree_CRG", "Scenarios_CRG", "Runtime_CRG",
    "Best_ILS", "gap_ILS_best", "Avg_ILS", "gap_ILS_avg", "Opt_ILS", "Runtime_ILS"
]

# Ajusta nomes para bater com suas especificações finais
df_all = df_all.rename(columns={
    'GapRoot_CF': 'gap_root_CF',
    'Tree_CF': 'Tree_CF',
    'Runtime_CF': 'Runtime_CF',
    'GapRoot_TIF': 'gap_root_TIF',
    'Tree_TIF': 'Tree_TIF',
    'TCuts_TIF': 'TIF_cuts',
    'Runtime_TIF': 'Runtime_TIF',
    'GapRoot_CRG': 'gap_root_CRG',
    'Tree_CRG': 'Tree_CRG',
    'Scenarios_CRG': 'Scenarios_CRG',
    'Runtime_CRG': 'Runtime_CRG'
})

# # print(df_all.keys())

df_all[cols].to_csv("data/results/derived/benchmark_results_all.csv", index=False, sep=",")

print("✅ benchmark_results_all.csv generated successfully!")
