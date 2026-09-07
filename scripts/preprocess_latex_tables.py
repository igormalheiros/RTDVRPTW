import pandas as pd

def classify(instance_name):
    for prefix in ['C1', 'C2', 'R1', 'R2', 'RC1', 'RC2']:
        if str(instance_name).startswith(prefix):
            return prefix
    return 'Other'

def read_data(file_path):
    df = pd.read_csv(file_path, header=None, names=['instance', 'customers', 'deviation_id', 'deviation', 'total', 'reduced'])
    df['class'] = df['instance'].apply(classify)
    return df

def process_data(df):
    df['reduction_rate'] = (df['total'] - df['reduced']) / df['total']
    pivot = df.groupby(['class', 'customers'])['reduction_rate'].mean().reset_index()
    pivot = pivot.pivot(index='class', columns='customers', values='reduction_rate')
    return pivot

def generate_combined_latex_table(arcs_pivot, bps_pivot):
    customer_groups = [25, 50, 100]
    classes = sorted(set(arcs_pivot.index) | set(bps_pivot.index))

    lines = []
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{Arc and breakpoint reduction rates by instance class and number of customers}")
    lines.append(r"\label{Table:preproc}")
    lines.append(r"\setlength{\tabcolsep}{10pt}")
    lines.append(r"\begin{tabular}{ccccccccc}")
    lines.append(r"\hline")
    lines.append(r"& & \multicolumn{3}{c}{Arc reduction} & & \multicolumn{3}{c}{Breakpoint reduction} \\")
    lines.append(r" \cline{3-5} \cline{7-9}")
    lines.append(r"Class & & 25  & 50  & 100 & & 25  & 50  & 100 \\")
    lines.append(r"\cline{1-1} \cline{3-5} \cline{7-9}")

    for cls in classes:
        row = [cls, ""]
        for cust in customer_groups:
            val = arcs_pivot.loc[cls, cust] if cust in arcs_pivot.columns else None
            row.append(f"{val:.2f}" if pd.notna(val) else "--")
        row.append("")
        for cust in customer_groups:
            val = bps_pivot.loc[cls, cust] if cust in bps_pivot.columns else None
            row.append(f"{val:.2f}" if pd.notna(val) else "--")
        lines.append(" & ".join(row) + r" \\")

    # Compute averages
    avg_row = ["Avg.", ""]
    for pivot in [arcs_pivot, bps_pivot]:
        for cust in customer_groups:
            avg = pivot[cust].mean() if cust in pivot.columns else None
            avg_row.append(f"{avg:.2f}" if pd.notna(avg) else "--")
        avg_row.append("")
    lines.append(r"\hline")
    lines.append(" & ".join(avg_row[:-1]) + r" \\")
    lines.append(r"\hline")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table}")

    return "\n".join(lines)

def main():
    arcs_file = "data/results/raw/arcs_shrink.csv"
    bps_file = "data/results/raw/breakpoints_shrink.csv"
    output_file = "data/results/tables/preprocess_table.tex"

    arcs_df = read_data(arcs_file)
    bps_df = read_data(bps_file)

    arcs_pivot = process_data(arcs_df)
    bps_pivot = process_data(bps_df)

    combined_table = generate_combined_latex_table(arcs_pivot, bps_pivot)

    with open(output_file, "w") as f:
        f.write(combined_table)

if __name__ == "__main__":
    main()
