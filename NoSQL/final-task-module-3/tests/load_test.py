import os
import random
import statistics
import sys
import threading
import time
import uuid
from datetime import datetime, timezone

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from db import get_db

N_BULK = 10_000
N_READS = 5_000
N_MIXED = 5_000
N_THREADS = 8
N_AGG = 500
BATCH_SIZE = 500

RESULTS_DIR = os.path.join(os.path.dirname(__file__), "..", "report")
os.makedirs(RESULTS_DIR, exist_ok=True)


def make_student_doc():
    return {
        "student_id": str(uuid.uuid4()),
        "first_name": random.choice(["Иван", "Мария", "Анна", "Пётр"]),
        "last_name": random.choice(["Иванов", "Смирнов", "Кузнецов"]),
        "faculty_id": str(uuid.uuid4()),
        "group_name": f"GRP-{random.randint(100, 999)}",
        "enrollment_year": random.randint(2018, 2024),
        "created_at": datetime.now(timezone.utc),
    }


# Test 1: Bulk Insert

def test_bulk_insert(db):
    print(f"\n[1] Bulk insert: {N_BULK} docs")
    inserted_ids = []
    latencies = []
    throughputs = []

    batches = N_BULK // BATCH_SIZE
    for i in range(batches):
        docs = [make_student_doc() for _ in range(BATCH_SIZE)]
        t0 = time.perf_counter()
        db.load_test_students.insert_many(docs)
        elapsed = time.perf_counter() - t0
        latencies.append(elapsed * 1000)
        throughputs.append(BATCH_SIZE / elapsed)
        inserted_ids.extend(d["student_id"] for d in docs)

        if (i + 1) % 5 == 0:
            print(f"  {(i + 1) / batches * 100:.0f}%  batch {i + 1}/{batches}  {elapsed * 1000:.1f}ms")

    total = sum(latencies) / 1000
    print(f"  done: {N_BULK} docs in {total:.2f}s  "
          f"avg={statistics.mean(latencies):.1f}ms/batch  "
          f"tput={N_BULK / total:.0f} ops/s")
    return inserted_ids, latencies, throughputs


# Test 2: Parallel Reads

def test_parallel_reads(db, student_ids):
    print(f"\n[2] Parallel reads: {N_READS} requests, {N_THREADS} threads")
    ids_snapshot = list(student_ids)
    latencies = []
    lock = threading.Lock()
    per_thread = N_READS // N_THREADS

    def worker():
        local_lat = []
        for _ in range(per_thread):
            sid = random.choice(ids_snapshot)
            t0 = time.perf_counter()
            db.load_test_students.find_one({"student_id": sid})
            local_lat.append((time.perf_counter() - t0) * 1000)
        with lock:
            latencies.extend(local_lat)

    t_start = time.perf_counter()
    threads = [threading.Thread(target=worker) for _ in range(N_THREADS)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    total = time.perf_counter() - t_start

    print(f"  done: {N_READS} reads in {total:.2f}s  "
          f"avg={statistics.mean(latencies):.2f}ms  "
          f"p99={np.percentile(latencies, 99):.2f}ms  "
          f"tput={N_READS / total:.0f} rps")
    return latencies, N_READS / total


# Test 3: Mixed Load

def test_mixed(db, student_ids):
    print(f"\n[3] Mixed load 70/30: {N_MIXED} ops")
    ids_snapshot = list(student_ids)
    read_lat, write_lat = [], []
    new_ids = []

    t_start = time.perf_counter()
    for _ in range(N_MIXED):
        if random.random() < 0.7:
            sid = random.choice(ids_snapshot)
            t0 = time.perf_counter()
            db.load_test_students.find_one({"student_id": sid})
            read_lat.append((time.perf_counter() - t0) * 1000)
        else:
            doc = make_student_doc()
            t0 = time.perf_counter()
            db.load_test_students.insert_one(doc)
            new_ids.append(doc["student_id"])
            write_lat.append((time.perf_counter() - t0) * 1000)
    total = time.perf_counter() - t_start

    student_ids.extend(new_ids)
    print(f"  done: {N_MIXED} ops in {total:.2f}s  "
          f"read_avg={statistics.mean(read_lat):.2f}ms  "
          f"write_avg={statistics.mean(write_lat):.2f}ms")
    return read_lat, write_lat


# Test 4: Aggregation

def test_aggregation(db, student_ids):
    print(f"\n[4] Aggregation ($lookup): {N_AGG} requests")
    latencies = []

    for _ in range(N_AGG):
        sid = random.choice(student_ids)
        pipeline = [
            {"$match": {"student_id": sid}},
            {"$lookup": {
                "from": "load_test_students",
                "localField": "faculty_id",
                "foreignField": "faculty_id",
                "as": "peers",
            }},
            {"$project": {"_id": 0, "student_id": 1, "peers_count": {"$size": "$peers"}}},
        ]
        t0 = time.perf_counter()
        list(db.load_test_students.aggregate(pipeline))
        latencies.append((time.perf_counter() - t0) * 1000)

    print(f"  done: avg={statistics.mean(latencies):.2f}ms  "
          f"p95={np.percentile(latencies, 95):.2f}ms  "
          f"p99={np.percentile(latencies, 99):.2f}ms")
    return latencies


# Test 5: Shard Distribution

def test_shard_distribution(db):
    print(f"\n[5] Shard distribution check")
    results = {}

    collections = {
        "lt_students": "load_test_students",
        "students": "students",
        "grades": "grades",
    }

    for label, coll_name in collections.items():
        try:
            # $collStats with storageStats gives per-shard breakdown in MongoDB 7
            pipeline = [{"$collStats": {"storageStats": {}}}]
            cursor = list(db[coll_name].aggregate(pipeline))

            if not cursor:
                print(f"  {label}: no data returned")
                continue

            shard_counts = {}
            for doc in cursor:
                shard = doc.get("shard", "unknown")
                count = doc.get("storageStats", {}).get("count", 0)
                shard_counts[shard] = shard_counts.get(shard, 0) + count

            total = sum(shard_counts.values())
            if total == 0:
                print(f"  {label}: 0 documents — run 'make seed' first")
                continue

            results[label] = {"total": total, "shards": shard_counts}
            print(f"  {label} ({total} docs):")
            for shard_name, count in shard_counts.items():
                pct = count / total * 100
                print(f"    {shard_name}: {count} docs  ({pct:.1f}%)")

            if len(shard_counts) > 1:
                counts = list(shard_counts.values())
                imbalance = (max(counts) - min(counts)) / total * 100
                print(f"    imbalance: {imbalance:.1f}%")
                results[label]["imbalance"] = imbalance

        except Exception as e:
            print(f"  {label}: error — {e}")

    return results


# Test 6: Targeted vs Scatter-Gather

def test_routing(db, student_ids):
    """
    Compare latency of:
      - targeted query     (filter by shard key student_id → routed to 1 shard)
      - scatter-gather     (filter by non-shard field enrollment_year → all shards)

    Both queries fully materialise their result sets so the comparison is fair.
    """
    print(f"\n[6] Routing: targeted vs scatter-gather (200 queries each)")
    N = 200
    targeted_lat = []
    scatter_lat = []

    for _ in range(N):
        sid = random.choice(student_ids)
        t0 = time.perf_counter()
        # find_one hits exactly 1 shard because student_id is the shard key
        db.load_test_students.find_one({"student_id": sid})
        targeted_lat.append((time.perf_counter() - t0) * 1000)

    for _ in range(N):
        year = random.randint(2018, 2024)
        t0 = time.perf_counter()
        # count_documents with a non-shard filter forces mongos to ask every shard
        db.load_test_students.count_documents({"enrollment_year": year})
        scatter_lat.append((time.perf_counter() - t0) * 1000)

    print(f"  targeted  avg={statistics.mean(targeted_lat):.2f}ms  "
          f"p99={np.percentile(targeted_lat, 99):.2f}ms")
    print(f"  scatter   avg={statistics.mean(scatter_lat):.2f}ms  "
          f"p99={np.percentile(scatter_lat, 99):.2f}ms")
    ratio = statistics.mean(scatter_lat) / statistics.mean(targeted_lat)
    print(f"  scatter overhead: x{ratio:.1f}")

    return targeted_lat, scatter_lat


# Charts

def build_charts(bulk_lat, bulk_tput,
                 read_lat, read_tput,
                 mix_read, mix_write,
                 agg_lat,
                 shard_dist,
                 targeted_lat, scatter_lat):
    fig = plt.figure(figsize=(22, 16))
    fig.suptitle("Load Test Results — University DB (MongoDB Sharded Cluster)",
                 fontsize=16, fontweight="bold", y=0.99)
    gs = gridspec.GridSpec(3, 3, figure=fig, hspace=0.55, wspace=0.38)

    # 1. Bulk Insert throughput
    ax1 = fig.add_subplot(gs[0, 0])
    ax1.plot(bulk_tput, color="#2196F3", linewidth=1.5)
    ax1.axhline(y=statistics.mean(bulk_tput), color="red",
                linestyle="--", label=f"avg {statistics.mean(bulk_tput):.0f}")
    ax1.set_title("Bulk Insert — throughput")
    ax1.set_xlabel("Batch #")
    ax1.set_ylabel("ops/s")
    ax1.legend(fontsize=8)
    ax1.grid(True, alpha=0.3)

    # 2. Bulk Insert latency histogram
    ax2 = fig.add_subplot(gs[0, 1])
    ax2.hist(bulk_lat, bins=20, color="#4CAF50", edgecolor="white")
    ax2.axvline(x=statistics.mean(bulk_lat), color="red",
                linestyle="--", label=f"avg {statistics.mean(bulk_lat):.1f}ms")
    ax2.set_title("Bulk Insert — batch latency")
    ax2.set_xlabel("Latency (ms)")
    ax2.set_ylabel("Batches")
    ax2.legend(fontsize=8)
    ax2.grid(True, alpha=0.3)

    # 3. Parallel reads percentile
    ax3 = fig.add_subplot(gs[0, 2])
    pct = [50, 75, 90, 95, 99, 99.9]
    vals = [np.percentile(read_lat, p) for p in pct]
    bars = ax3.bar([str(p) for p in pct], vals, color="#FF9800")
    for bar, v in zip(bars, vals):
        ax3.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.02,
                 f"{v:.1f}", ha="center", va="bottom", fontsize=8)
    ax3.set_title(f"Parallel Reads ({N_THREADS} threads)\nPercentile latency")
    ax3.set_xlabel("Percentile")
    ax3.set_ylabel("Latency (ms)")
    ax3.grid(True, alpha=0.3, axis="y")

    # 4. Mixed load box plot
    ax4 = fig.add_subplot(gs[1, 0])
    bp = ax4.boxplot([mix_read, mix_write], tick_labels=["Read", "Write"],
                     patch_artist=True, notch=False)
    bp["boxes"][0].set_facecolor("#64B5F6")
    bp["boxes"][1].set_facecolor("#EF9A9A")
    ax4.set_title("Mixed Load (70% read / 30% write)\nLatency box plot")
    ax4.set_ylabel("Latency (ms)")
    ax4.grid(True, alpha=0.3, axis="y")

    # 5. Aggregation latency histogram
    ax5 = fig.add_subplot(gs[1, 1])
    ax5.hist(agg_lat, bins=30, color="#9C27B0", edgecolor="white", alpha=0.8)
    ax5.axvline(x=np.percentile(agg_lat, 95), color="red",
                linestyle="--", label=f"p95={np.percentile(agg_lat, 95):.1f}ms")
    ax5.set_title("Aggregation ($lookup)\nLatency distribution")
    ax5.set_xlabel("Latency (ms)")
    ax5.set_ylabel("Requests")
    ax5.legend(fontsize=8)
    ax5.grid(True, alpha=0.3)

    # 6. Targeted vs scatter-gather
    ax6 = fig.add_subplot(gs[1, 2])
    bp2 = ax6.boxplot([targeted_lat, scatter_lat],
                      tick_labels=["Targeted\n(shard key)", "Scatter\n(non-key)"],
                      patch_artist=True, notch=False)
    bp2["boxes"][0].set_facecolor("#A5D6A7")
    bp2["boxes"][1].set_facecolor("#FFCC80")
    ax6.set_title("Routing: targeted vs scatter-gather\nLatency box plot")
    ax6.set_ylabel("Latency (ms)")
    ax6.grid(True, alpha=0.3, axis="y")

    # 7. Shard distribution bar chart
    ax7 = fig.add_subplot(gs[2, 0])
    coll_labels = []
    shard_names = []
    for coll, data in shard_dist.items():
        for sname in data["shards"]:
            if sname not in shard_names:
                shard_names.append(sname)
        coll_labels.append(coll)

    x = np.arange(len(coll_labels))
    width = 0.35
    colors = ["#42A5F5", "#EF5350"]
    for i, sname in enumerate(shard_names):
        counts = []
        for coll in coll_labels:
            counts.append(shard_dist.get(coll, {}).get("shards", {}).get(sname, 0))
        short_name = sname.split("/")[0] if "/" in sname else sname
        ax7.bar(x + i * width - width / 2, counts, width,
                label=short_name, color=colors[i % len(colors)], alpha=0.85)
    ax7.set_title("Shard distribution\nDocs per shard per collection")
    ax7.set_xticks(x)
    ax7.set_xticklabels(coll_labels, fontsize=8, rotation=15)
    ax7.set_ylabel("Documents")
    ax7.legend(fontsize=8)
    ax7.grid(True, alpha=0.3, axis="y")

    # 8. Shard balance (imbalance %)
    ax8 = fig.add_subplot(gs[2, 1])
    imbalances = [(c, d.get("imbalance", 0)) for c, d in shard_dist.items()
                  if "imbalance" in d]
    if imbalances:
        labels_ib = [c for c, _ in imbalances]
        values_ib = [v for _, v in imbalances]
        bar_colors = ["#EF5350" if v > 10 else "#66BB6A" for v in values_ib]
        bars_ib = ax8.bar(labels_ib, values_ib, color=bar_colors, alpha=0.85)
        for bar, v in zip(bars_ib, values_ib):
            ax8.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.1,
                     f"{v:.1f}%", ha="center", va="bottom", fontsize=9)
        ax8.axhline(y=10, color="red", linestyle="--", linewidth=1, label="10% threshold")
        ax8.set_title("Shard balance\nImbalance % per collection")
        ax8.set_ylabel("Imbalance (%)")
        ax8.legend(fontsize=8)
        ax8.grid(True, alpha=0.3, axis="y")
    else:
        ax8.text(0.5, 0.5, "No imbalance data", ha="center", va="center",
                 transform=ax8.transAxes)
        ax8.axis("off")

    # 9. Summary table
    ax9 = fig.add_subplot(gs[2, 2])
    ax9.axis("off")
    summary = [
        ["Test", "Avg (ms)", "p99 (ms)", "Ops/s"],
        [f"Bulk Insert\n(batch {BATCH_SIZE})",
         f"{statistics.mean(bulk_lat):.1f}",
         f"{np.percentile(bulk_lat, 99):.1f}",
         f"{statistics.mean(bulk_tput):.0f}"],
        [f"Reads\n({N_THREADS} threads)",
         f"{statistics.mean(read_lat):.2f}",
         f"{np.percentile(read_lat, 99):.2f}",
         f"{read_tput:.0f}"],
        ["Mixed Read",
         f"{statistics.mean(mix_read):.2f}",
         f"{np.percentile(mix_read, 99):.2f}", "-"],
        ["Mixed Write",
         f"{statistics.mean(mix_write):.2f}",
         f"{np.percentile(mix_write, 99):.2f}", "-"],
        ["Aggregation",
         f"{statistics.mean(agg_lat):.2f}",
         f"{np.percentile(agg_lat, 99):.2f}", "-"],
        ["Targeted read",
         f"{statistics.mean(targeted_lat):.2f}",
         f"{np.percentile(targeted_lat, 99):.2f}", "-"],
        ["Scatter-gather",
         f"{statistics.mean(scatter_lat):.2f}",
         f"{np.percentile(scatter_lat, 99):.2f}", "-"],
    ]
    tbl = ax9.table(cellText=summary[1:], colLabels=summary[0],
                    loc="center", cellLoc="center")
    tbl.auto_set_font_size(False)
    tbl.set_fontsize(8)
    tbl.scale(1, 1.7)
    for (r, c), cell in tbl.get_celld().items():
        if r == 0:
            cell.set_facecolor("#455A64")
            cell.set_text_props(color="white", fontweight="bold")
        elif r % 2 == 0:
            cell.set_facecolor("#ECEFF1")
    ax9.set_title("Summary", fontweight="bold")

    out_path = os.path.join(RESULTS_DIR, "load_test_results.png")
    plt.savefig(out_path, dpi=200, bbox_inches="tight")
    plt.close()
    print(f"\nChart saved: {out_path}")
    return out_path


# Main

def main():
    db = get_db()
    db.load_test_students.drop()

    print("=" * 50)
    print("  Load Test — University DB")
    print("=" * 50)

    t_total = time.perf_counter()
    student_ids, bulk_lat, bulk_tput = test_bulk_insert(db)
    read_lat, read_tput = test_parallel_reads(db, student_ids)
    mix_read, mix_write = test_mixed(db, student_ids)
    agg_lat = test_aggregation(db, student_ids)
    shard_dist = test_shard_distribution(db)
    targeted_lat, scatter_lat = test_routing(db, student_ids)

    print(f"\nTotal time: {time.perf_counter() - t_total:.1f}s")
    build_charts(bulk_lat, bulk_tput, read_lat, read_tput,
                 mix_read, mix_write, agg_lat,
                 shard_dist, targeted_lat, scatter_lat)
    db.load_test_students.drop()


if __name__ == "__main__":
    main()
