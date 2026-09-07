import csv
from collections import defaultdict
import pandas as pd

# File paths (change if needed)
heuristic_file = 'benchmark_ils.csv'
cf_file = 'benchmark_CF.csv'
output_file = 'gaps_ils_25_x.csv'

# Helper to determine instance class from instance name
def get_instance_class(name):
    if name.startswith("C1"):
        return "C1"
    elif name.startswith("C2"):
        return "C2"
    elif name.startswith("R1"):
        return "R1"
    elif name.startswith("R2"):
        return "R2"
    elif name.startswith("RC1"):
        return "RC1"
    elif name.startswith("RC2"):
        return "RC2"
    else:
        return "Unknown"

DERIVED_DIR = 'data/results/derived'

def summarize_tables():
    input_file = f'{DERIVED_DIR}/benchmark_results_all.csv'
    output_file = f'{DERIVED_DIR}/benchmark_exact_aggragate.csv'

    grouped_data = defaultdict(list)

    with open(input_file, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['gap_ILS_best'] == 'inf':
                print(row['Instance'])
                continue  # Skip infeasible rows

            instance_type = get_instance_class(row['Instance'])
            budget = int(row['Budget'])
            gap_cf = float(row['gap_CF'])
            opt_cf = int(row['Opt_CF'])
            gap_root_cf = float(row['gap_root_CF'])
            tree_cf = float(row['Tree_CF'])
            runtime_cf = float(row['Runtime_CF'])
            gap_tif = float(row['gap_TIF'])
            opt_tif = int(row['Opt_TIF'])
            gap_root_tif = float(row['gap_root_TIF'])
            tree_tif = float(row['Tree_TIF'])
            tif_cuts = float(row['TIF_cuts'])
            runtime_tif = float(row['Runtime_TIF'])
            gap_crg = float(row['gap_CRG'])
            opt_crg = int(row['Opt_CRG'])
            gap_root_crg = float(row['gap_root_CRG'])
            tree_crg = float(row['Tree_CRG'])
            scenarios_crg = float(row['Scenarios_CRG'])
            runtime_crg = float(row['Runtime_CRG'])

            key = (instance_type, budget)
                        # Store everything as a tuple
            grouped_data[(instance_type, budget)].append((
                gap_cf,            # 0
                opt_cf,           # 1
                gap_root_cf,      # 2
                tree_cf,          # 3
                runtime_cf,       # 4
                gap_tif,          # 5
                opt_tif,          # 6
                gap_root_tif,     # 7
                tree_tif,         # 8
                tif_cuts,         # 9
                runtime_tif,      #10
                gap_crg,          #11
                opt_crg,          #12
                gap_root_crg,     #13
                tree_crg,         #14
                scenarios_crg,    #15
                runtime_crg       #16
            ))

    summary_rows = []

    for key, values in sorted(grouped_data.items()):
        instance_type, budget = key
        total = len(values)
         # CF
        cf_gaps = [v[0] for v in values if v[1] == 0]
        avg_gap_cf = sum(cf_gaps)/len(cf_gaps) if cf_gaps else 0
        sum_opt_cf = sum(v[1] for v in values)
        cf_runtimes = [v[4] for v in values if v[1] == 1]
        avg_runtime_cf = sum(cf_runtimes)/len(cf_runtimes) if cf_runtimes else 0
        avg_gap_root_cf = sum(v[2] for v in values) / len(values)

        # TIF
        tif_gaps = [v[5] for v in values if v[6] == 0]
        avg_gap_tif = sum(tif_gaps)/len(tif_gaps) if tif_gaps else 0
        sum_opt_tif = sum(v[6] for v in values)
        tif_runtimes = [v[10] for v in values if v[6] == 1]
        avg_runtime_tif = sum(tif_runtimes)/len(tif_runtimes) if tif_runtimes else 0
        avg_gap_root_tif = sum(v[7] for v in values) / len(values)
        avg_tif_cuts = sum(v[9] for v in values) / len(values)

        # CRG
        crg_gaps = [v[11] for v in values if v[12] == 0]
        avg_gap_crg = sum(crg_gaps)/len(crg_gaps) if crg_gaps else 0
        sum_opt_crg = sum(v[12] for v in values)
        crg_runtimes = [v[16] for v in values if v[12] == 1]
        avg_runtime_crg = sum(crg_runtimes)/len(crg_runtimes) if crg_runtimes else 0
        avg_scenarios_crg = sum(v[15] for v in values) / len(values)
        
        summary_rows.append([
            instance_type, budget,
            round(avg_gap_cf, 1), round(sum_opt_cf/total*100), round(avg_gap_root_cf, 1), round(avg_runtime_cf, 0),
            round(avg_gap_tif, 1), round(sum_opt_tif/total*100), round(avg_gap_root_tif, 1), round(avg_tif_cuts, 1), round(avg_runtime_tif, 0),
            round(avg_gap_crg, 1), round(sum_opt_crg/total *100), round(avg_scenarios_crg, 1), round(avg_runtime_crg, 0)
        ])

    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Group', 'Budget', 'Gap CF', 'Opt CF', 'Gap root CF', 'Runtime CF',
                         'Gap TIF', 'Opt TIF', 'Gap root TIF', 'TIF Cuts', 'Runtime TIF',
                         'Gap CRG', 'Opt CRG', 'Scenarios CRG', 'Runtime CRG'])
        writer.writerows(summary_rows)

    print(f"Grouped summary written to {output_file}")


def summarize_ils_table():
    input_file = f'{DERIVED_DIR}/benchmark_results_all.csv'
    output_file = f'{DERIVED_DIR}/benchmark_heur_aggragate.csv'

    grouped_data = defaultdict(list)

    with open(input_file, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['gap_ILS_best'] == 'inf':
                print(row['Instance'])
                continue  # Skip infeasible rows

            instance_type = get_instance_class(row['Instance'])
            budget = int(row['Budget'])
            gap_ils_best = float(row['gap_ILS_best'])
            gap_ils_avg = float(row['gap_ILS_avg'])
            runtime_ils = float(row['Runtime_ILS'])
            best_ils = float(row['Best_ILS'])
            bks = float(row['BKS'])

            key = (instance_type, budget)
            grouped_data[key].append((gap_ils_best, gap_ils_avg, runtime_ils, best_ils, bks))

    summary_rows = []

    for key, values in sorted(grouped_data.items()):
        instance_type, budget = key
        avg_gap_best = sum(v[0] for v in values) / len(values)
        avg_gap_avg = sum(v[1] for v in values) / len(values)
        avg_runtime = sum(v[2] for v in values) / len(values)
        sum_bks = sum(v[3] == v[4] for v in values)
        
        summary_rows.append([
            instance_type, budget, 
            sum_bks, round(avg_gap_best, 1), round(avg_gap_avg, 1), round(avg_runtime, 1),
        ])

    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Group', 'Budget', "BKS", 'Gap best', 'Gap Avg.', 'Runtime'])
        writer.writerows(summary_rows)

    print(f"Grouped summary written to {output_file}")

summarize_tables()
# summarize_ils_table()