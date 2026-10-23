#!/usr/bin/env python3
"""Render only paired asynchronous formal256 campaign data."""
import argparse
import csv
from pathlib import Path


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--summary", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    with a.summary.open() as f:
        rows = list(csv.DictReader(f))
    if not rows:
        raise RuntimeError("empty campaign summary")
    a.output.mkdir(parents=True, exist_ok=True)
    designs = (("Mesh256", "Mesh", "#2878B5", "o"),
               ("M16_256", "M16", "#D95319", "s"))
    benches = (("TOPO-UR", "Uniform random"), ("MULTICAST10-AABB", "Multicast10"),
               ("ALL-MULTICAST-AABB", "All-Multicast"))
    plt.rcParams.update({"font.size": 10, "pdf.fonttype": 42, "ps.fonttype": 42})
    fig, axes = plt.subplots(3, 2, figsize=(10, 9), constrained_layout=True)
    for row_index, (b, title) in enumerate(benches):
        for design, label, color, marker in designs:
            selected = sorted((r for r in rows if r["design"] == design and
                               r["benchmark"] == b and r["mode"] == "native"),
                              key=lambda r: float(r["load"]))
            for col, field in enumerate(("mean_last_destination_ns", "delivered_mflit_port_s")):
                ax = axes[row_index, col]
                xs, ys = [], []
                for r in selected:
                    eligible = r["latency_curve_eligible"].lower() == "true"
                    complete = int(r["valid_seeds"]) == 3 and int(r["seeds"]) == 3
                    val = r.get(field + "_mean", "")
                    if not val or not complete:
                        xs.append(float(r["load"]))
                        ys.append(np.nan)
                        continue
                    x, y = float(r["load"]), float(val)
                    xs.append(x)
                    ys.append(y)
                    ax.plot(x, y, marker=marker, linestyle="none", color=color,
                            markerfacecolor=color if eligible else "white", markersize=4)
                ax.plot(xs, ys, color=color, linewidth=1.1, label=label)
                ax.grid(alpha=.25)
                ax.set_title(title)
                ax.set_xlabel("Offered original-flit load (Mflit/s/port)")
                ax.set_ylabel("Last-destination latency (ns)" if col == 0 else
                              "Delivered copies (Mflit/s/port)")
                ax.legend(frameon=False)
    fig.suptitle("256 nodes, 5-flit packets, TT/0.8 V/25 C\nFilled: window delivery >=99%; hollow: drained pressure points", fontsize=11)
    for suffix in ("png", "pdf"):
        fig.savefig(a.output / f"formal256_curves.{suffix}", dpi=300)
    plt.close(fig)
    # Repeated comparisons retain invalid/undrained outcomes as annotations.
    fig, axes = plt.subplots(2, 2, figsize=(10, 6), constrained_layout=True)
    for i, (b, title) in enumerate(benches[1:]):
        for j, field in enumerate(("mean_last_destination_ns", "delivered_mflit_port_s")):
            ax = axes[i, j]
            repeat = [r for r in rows if r["benchmark"] == b and r["mode"] == "repeated"]
            for k, (design, label, color, _) in enumerate(designs):
                match = [r for r in repeat if r["design"] == design]
                if len(match) != 1:
                    raise RuntimeError(f"missing or ambiguous repeated point: {b} {design}")
                load = match[0]["load"]
                for mi, mode in enumerate(("native", "repeated")):
                    candidates = [r for r in rows if r["benchmark"] == b and
                                  r["design"] == design and r["mode"] == mode and r["load"] == load]
                    if len(candidates) != 1:
                        raise RuntimeError("paired comparison coverage mismatch")
                    r = candidates[0]
                    x = k + (mi - .5) * .32
                    val = r.get(field + "_mean", "")
                    if int(r["valid_seeds"]) != 3 or not val:
                        ax.text(x, 0, "Not drained/invalid", rotation=90, ha="center", va="bottom", fontsize=7)
                        continue
                    err = float(r.get(field + "_std") or 0)
                    bars = ax.bar(x, float(val), .3, color=color if mi == 0 else "white", edgecolor=color,
                           hatch=None if mi == 0 else "//", yerr=err,
                           label=mode.title() if k == 0 else None)
                    ax.bar_label(bars, labels=[f'{float(val):.1f}'], padding=4, fontsize=8)
            ax.set_xticks([0, 1], ["Mesh", "M16"])
            ax.set_title(title + (" (load 40; 20% Mesh saturation)" if i == 0 else
                                  " (load 20; 25% Mesh saturation)"))
            ax.set_ylabel("Last-destination latency (ns)" if j == 0 else "Delivered copies (Mflit/s/port)")
            ax.margins(y=.15)
            ax.grid(axis="y", alpha=.2)
    from matplotlib.patches import Patch
    fig.legend(handles=[Patch(facecolor='gray',label='Native'),Patch(facecolor='white',edgecolor='gray',hatch='//',label='Repeated')],
               loc='outside upper center',ncol=2,frameon=False)
    for suffix in ("png", "pdf"):
        fig.savefig(a.output / f"formal256_native_repeated.{suffix}", dpi=300)
    plt.close(fig)

    # Separate latency and throughput figures for paper placement.
    from matplotlib.lines import Line2D
    for field, name, ylabel in (("mean_last_destination_ns", "latency", "Last-destination latency (ns)"),
                                ("delivered_mflit_port_s", "throughput", "Delivered copies (Mflit/s/port)")):
        fig, axes = plt.subplots(1, 3, figsize=(12, 3.5), constrained_layout=True)
        for ax, (b, title) in zip(axes, benches):
            for design, label, color, marker in designs:
                points = sorted((r for r in rows if r['design']==design and r['benchmark']==b and r['mode']=='native'), key=lambda r:float(r['load']))
                assert len(points)==30 and all(int(r['valid_seeds'])==3 for r in points)
                x=[float(r['load']) for r in points];y=[float(r[field+'_mean']) for r in points]
                ax.plot(x,y,color=color,lw=1,label=label)
                for r,xx,yy in zip(points,x,y):
                    ax.plot(xx,yy,marker=marker,color=color,mfc=color if r['latency_curve_eligible'].lower()=='true' else 'white',ms=4,ls='none')
            ax.set(title=title,xlabel='Offered original-flit load (Mflit/s/port)',ylabel=ylabel)
            ax.grid(alpha=.2)
        handles,labels=axes[0].get_legend_handles_labels()
        handles += [Line2D([],[],color='gray',marker='o',ls='none'),Line2D([],[],color='gray',marker='o',mfc='white',ls='none')]
        labels += ['Window delivery >=99%','Drained pressure point']
        fig.legend(handles,labels,loc='outside upper center',ncol=4,frameon=False)
        for suffix in ('png','pdf'):fig.savefig(a.output/f'formal256_{name}.{suffix}',dpi=300)
        plt.close(fig)


if __name__ == "__main__":
    main()
