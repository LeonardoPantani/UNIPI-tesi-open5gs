import pandas as pd
import argparse
import sys
import os

def main():
    parser = argparse.ArgumentParser(description="Calculate and rank Network Functions consumption.")
    parser.add_argument('files', nargs='+', help='List of files to process')
    args = parser.parse_args()

    global_totals = pd.Series(dtype=float)

    print(f"Processing {len(args.files)} files...")

    for file_path in args.files:
        try:
            if file_path.lower().endswith('.xlsx'):
                df = pd.read_excel(file_path)
            else:
                continue

            # DATA CLEANING
            if 'Time' in df.columns:
                valid_rows = pd.to_numeric(df['Time'], errors='coerce').notnull()
                df = df[valid_rows]
                
                consumption_data = df.drop(columns=['Time'])
            else:
                consumption_data = df

            file_sum = consumption_data.sum(numeric_only=True)
            global_totals = global_totals.add(file_sum, fill_value=0)

        except Exception as e:
            print(f"[!] Error processing {file_path}: {e}", file=sys.stderr)

    # SORTING
    ranking = global_totals.sort_values(ascending=False)

    # OUTPUT
    print("\n" + "="*45)
    print(f"{'Rank':<5} {'NF':<10} {'Total Consumption (Watts)'}")
    print("="*45)
    
    for rank, (nf_name, value) in enumerate(ranking.items(), 1):
        print(f"{rank:<5} {nf_name:<10} {value:.6f}")
    print("="*45 + "\n")

if __name__ == "__main__":
    main()