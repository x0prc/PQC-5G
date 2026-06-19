#!/usr/bin/env python3
"""
PQC-5G Results Analysis Script
Analyzes experiment results and generates plots similar to the paper

Based on: "Post-Quantum Cryptography in the 5G Core" (arXiv:2512.20243)
"""

import csv
import os
import sys
import argparse
from pathlib import Path
from datetime import datetime

# Optional: matplotlib for plotting
try:
    import matplotlib.pyplot as plt
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False
    print("Warning: matplotlib not found. Install with: pip install matplotlib")
    print("Continuing with text output only...")

import statistics
from collections import defaultdict
from typing import Dict, List, Tuple


# Algorithm color mapping for consistent plots
ALGO_COLORS = {
    # Signature algorithms
    "secp256r1": "#1f77b4",      # Blue (baseline)
    "rsa2048": "#ff7f0e",        # Orange (baseline)
    "p256_falcon513": "#2ca02c", # Green
    "p384_mldsa66": "#d62728",   # Red
    "sphincssha2129ssimple": "#9467bd",  # Purple
    # KEM algorithms
    "p256_bikel1": "#17becf",    # Cyan
    "p384_bikel3": "#e377c2",    # Pink
    "p521_frodo1344shake": "#bcbd22",  # Yellow-green
}

ALGO_LABELS = {
    "secp256r1": "secp256r1 (ECDSA)",
    "rsa2048": "RSA-2048",
    "p256_falcon513": "p256_falcon513",
    "p384_mldsa66": "p384_mldsa66",
    "sphincssha2129ssimple": "SPHINCS+ SHA2-128s",
    "p256_bikel1": "p256_bikel1",
    "p384_bikel3": "p384_bikel3",
    "p521_frodo1344shake": "p521_frodo1344shake",
}


def load_results(results_file: str) -> List[Dict]:
    """Load experiment results from CSV file"""
    results = []
    with open(results_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Convert numeric fields
            for field in ['median_latency_ms', 'p95_latency_ms', 'p99_latency_ms', 
                         'p100_latency_ms', 'sbi_data_rate_kbps', 'ue_count']:
                if field in row:
                    try:
                        row[field] = float(row[field])
                    except (ValueError, TypeError):
                        row[field] = 0.0
            results.append(row)
    return results


def compute_statistics(results: List[Dict]) -> Dict:
    """Compute per-algorithm statistics"""
    stats = defaultdict(lambda: defaultdict(list))
    
    for row in results:
        algo = row.get('algorithm', 'unknown')
        algo_type = row.get('algorithm_type', 'unknown')
        ue_count = int(row.get('ue_count', 0))
        
        key = (algo_type, algo)
        stats[key][ue_count].append({
            'median': row.get('median_latency_ms', 0),
            'p95': row.get('p95_latency_ms', 0),
            'p99': row.get('p99_latency_ms', 0),
            'p100': row.get('p100_latency_ms', 0),
            'bandwidth': row.get('sbi_data_rate_kbps', 0),
        })
    
    # Compute averages
    avg_stats = {}
    for key, ue_data in stats.items():
        avg_stats[key] = {}
        for ue_count, measurements in ue_data.items():
            if measurements:
                avg_stats[key][ue_count] = {
                    'median': statistics.mean([m['median'] for m in measurements]),
                    'p95': statistics.mean([m['p95'] for m in measurements]),
                    'p99': statistics.mean([m['p99'] for m in measurements]),
                    'p100': statistics.mean([m['p100'] for m in measurements]),
                    'bandwidth': statistics.mean([m['bandwidth'] for m in measurements]),
                    'count': len(measurements),
                }
    
    return avg_stats


def plot_ecdf_latencies(results: List[Dict], output_dir: str):
    """Plot ECDF of latencies for different algorithms (similar to Figures 4 & 5)"""
    if not HAS_MATPLOTLIB:
        return
    
    # Group by algorithm type
    sig_algos = defaultdict(list)
    kem_algos = defaultdict(list)
    
    for row in results:
        algo = row.get('algorithm', '')
        algo_type = row.get('algorithm_type', '')
        
        if algo_type == 'signature':
            sig_algos[algo].append(row)
        elif algo_type == 'kem':
            kem_algos[algo].append(row)
    
    # Plot signature algorithms (like Figure 5)
    if sig_algos:
        fig, ax = plt.subplots(figsize=(10, 6))
        for algo, data in sig_algos.items():
            latencies = sorted([d.get('p100_latency_ms', 0) for d in data if d.get('p100_latency_ms', 0) > 0])
            if latencies:
                y = [i / len(latencies) for i in range(1, len(latencies) + 1)]
                ax.plot(latencies, y, label=ALGO_LABELS.get(algo, algo), 
                       color=ALGO_COLORS.get(algo, None), linewidth=2)
        
        ax.set_xlabel('Setup Duration (ms)')
        ax.set_ylabel('CDF')
        ax.set_title('ECDF of PDU Session Setup Duration - Signature Algorithms')
        ax.legend()
        ax.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, 'ecdf_pdusetup_sig.png'), dpi=150)
        plt.close()
        print(f"Saved: {output_dir}/ecdf_pdusetup_sig.png")
    
    # Plot KEM algorithms (like Figure 4)
    if kem_algos:
        fig, ax = plt.subplots(figsize=(10, 6))
        for algo, data in kem_algos.items():
            latencies = sorted([d.get('p100_latency_ms', 0) for d in data if d.get('p100_latency_ms', 0) > 0])
            if latencies:
                y = [i / len(latencies) for i in range(1, len(latencies) + 1)]
                ax.plot(latencies, y, label=ALGO_LABELS.get(algo, algo),
                       color=ALGO_COLORS.get(algo, None), linewidth=2)
        
        ax.set_xlabel('Setup Duration (ms)')
        ax.set_ylabel('CDF')
        ax.set_title('ECDF of PDU Session Setup Duration - KEM Algorithms')
        ax.legend()
        ax.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, 'ecdf_pdusetup_kem.png'), dpi=150)
        plt.close()
        print(f"Saved: {output_dir}/ecdf_pdusetup_kem.png")


def plot_scaling_analysis(stats: Dict, output_dir: str):
    """Plot UE scaling analysis (similar to Figures 6 & 7)"""
    if not HAS_MATPLOTLIB:
        return
    
    # Plot 95th percentile scaling (like Figure 6)
    fig, ax = plt.subplots(figsize=(10, 6))
    
    for (algo_type, algo), ue_stats in stats.items():
        ue_counts = sorted(ue_stats.keys())
        p95_values = [ue_stats[ue]['p95'] for ue in ue_counts]
        
        ax.plot(ue_counts, p95_values, 
               label=ALGO_LABELS.get(algo, algo),
               color=ALGO_COLORS.get(algo, None), 
               linewidth=2, marker='o', markersize=4)
    
    ax.set_xlabel('Number of UEs')
    ax.set_ylabel('95th Percentile Latency (ms)')
    ax.set_title('Registration Latency Scaling - 95th Percentile')
    ax.legend()
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'numUEscaling_95.png'), dpi=150)
    plt.close()
    print(f"Saved: {output_dir}/numUEscaling_95.png")
    
    # Plot 100th percentile scaling (like Figure 7)
    fig, ax = plt.subplots(figsize=(10, 6))
    
    for (algo_type, algo), ue_stats in stats.items():
        ue_counts = sorted(ue_stats.keys())
        p100_values = [ue_stats[ue]['p100'] for ue in ue_counts]
        
        ax.plot(ue_counts, p100_values, 
               label=ALGO_LABELS.get(algo, algo),
               color=ALGO_COLORS.get(algo, None),
               linewidth=2, marker='s', markersize=4)
    
    ax.set_xlabel('Number of UEs')
    ax.set_ylabel('100th Percentile Latency (ms)')
    ax.set_title('Registration Latency Scaling - 100th Percentile')
    ax.legend()
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'numUEscaling_100.png'), dpi=150)
    plt.close()
    print(f"Saved: {output_dir}/numUEscaling_100.png")


def plot_bandwidth_analysis(stats: Dict, output_dir: str):
    """Plot bandwidth comparison (similar to Table II)"""
    if not HAS_MATPLOTLIB:
        return
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    algo_labels = []
    bandwidth_values = []
    colors = []
    
    for (algo_type, algo), ue_stats in sorted(stats.items()):
        # Get bandwidth at 100 UEs (or closest)
        target_ue = min(ue_stats.keys(), key=lambda x: abs(x - 100))
        bandwidth = ue_stats[target_ue]['bandwidth']
        
        algo_labels.append(ALGO_LABELS.get(algo, algo))
        bandwidth_values.append(bandwidth)
        colors.append(ALGO_COLORS.get(algo, '#333333'))
    
    bars = ax.bar(algo_labels, bandwidth_values, color=colors)
    ax.set_ylabel('SBI Data Rate (KB/s)')
    ax.set_title('Service-Based Interface Data Rate Comparison')
    ax.set_xticklabels(algo_labels, rotation=45, ha='right')
    ax.grid(True, alpha=0.3, axis='y')
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'bandwidth_comparison.png'), dpi=150)
    plt.close()
    print(f"Saved: {output_dir}/bandwidth_comparison.png")


def print_summary_table(stats: Dict):
    """Print summary table similar to Table II in the paper"""
    print("\n" + "=" * 80)
    print("Summary Results (similar to Table II)")
    print("=" * 80)
    print(f"{'Algorithm':<30} {'Median (ms)':<15} {'99th %ile (ms)':<15} {'SBI Rate (KB/s)':<15}")
    print("-" * 80)
    
    for (algo_type, algo), ue_stats in sorted(stats.items()):
        # Get stats at 100 UEs (or closest)
        target_ue = min(ue_stats.keys(), key=lambda x: abs(x - 100))
        data = ue_stats[target_ue]
        
        algo_label = ALGO_LABELS.get(algo, algo)
        print(f"{algo_label:<30} {data['median']:<15.1f} {data['p99']:<15.1f} {data['bandwidth']:<15.1f}")
    
    print("=" * 80)


def generate_text_report(results: List[Dict], output_dir: str):
    """Generate detailed text report"""
    report_file = os.path.join(output_dir, 'experiment_report.txt')
    
    with open(report_file, 'w') as f:
        f.write("PQC-5G Experiment Report\n")
        f.write("=" * 80 + "\n")
        f.write(f"Generated: {datetime.now().isoformat()}\n")
        f.write(f"Paper: Post-Quantum Cryptography in the 5G Core (arXiv:2512.20243)\n\n")
        
        f.write("Experiment Parameters:\n")
        f.write("-" * 40 + "\n")
        
        # Extract unique UE counts
        ue_counts = sorted(set(int(r.get('ue_count', 0)) for r in results))
        f.write(f"UE Counts Tested: {ue_counts}\n")
        
        # Extract unique algorithms
        algorithms = set(r.get('algorithm', '') for r in results)
        f.write(f"Algorithms Tested: {algorithms}\n\n")
        
        f.write("Results Summary:\n")
        f.write("-" * 40 + "\n")
        
        # Group results by algorithm
        by_algo = defaultdict(list)
        for row in results:
            algo = row.get('algorithm', 'unknown')
            by_algo[algo].append(row)
        
        for algo, rows in sorted(by_algo.items()):
            f.write(f"\n{algo}:\n")
            for row in sorted(rows, key=lambda x: int(x.get('ue_count', 0))):
                ue = row.get('ue_count', 0)
                median = row.get('median_latency_ms', 0)
                p95 = row.get('p95_latency_ms', 0)
                p99 = row.get('p99_latency_ms', 0)
                p100 = row.get('p100_latency_ms', 0)
                bw = row.get('sbi_data_rate_kbps', 0)
                f.write(f"  UEs={ue:>4}: median={median:>8.1f}ms, "
                       f"p95={p95:>8.1f}ms, p99={p99:>8.1f}ms, "
                       f"p100={p100:>8.1f}ms, BW={bw:>8.1f}KB/s\n")
    
    print(f"Report saved to: {report_file}")


def main():
    parser = argparse.ArgumentParser(description='Analyze PQC-5G experiment results')
    parser.add_argument('--results', '-r', 
                       default='results/experiment_results.csv',
                       help='Path to results CSV file')
    parser.add_argument('--output', '-o',
                       default='results/plots',
                       help='Output directory for plots')
    parser.add_argument('--no-plots', action='store_true',
                       help='Skip generating plots')
    
    args = parser.parse_args()
    
    # Check if results file exists
    if not os.path.exists(args.results):
        print(f"Error: Results file not found: {args.results}")
        print("Run the experiment first:")
        print("  ./scripts/experiment/run_experiments.sh")
        sys.exit(1)
    
    # Create output directory
    os.makedirs(args.output, exist_ok=True)
    
    # Load and analyze results
    print(f"Loading results from: {args.results}")
    results = load_results(args.results)
    
    if not results:
        print("Error: No results found in file")
        sys.exit(1)
    
    print(f"Loaded {len(results)} result entries")
    
    # Compute statistics
    stats = compute_statistics(results)
    
    # Print summary table
    print_summary_table(stats)
    
    # Generate plots
    if not args.no_plots and HAS_MATPLOTLIB:
        print("\nGenerating plots...")
        plot_ecdf_latencies(results, args.output)
        plot_scaling_analysis(stats, args.output)
        plot_bandwidth_analysis(stats, args.output)
    
    # Generate text report
    generate_text_report(results, args.output)
    
    print("\nAnalysis complete!")


if __name__ == '__main__':
    main()
