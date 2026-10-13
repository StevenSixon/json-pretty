#!/usr/bin/env python3 -I
"""生成约 10MB 的 JSON 测试文件：流式写入，字段类型多样（字符串/数字/布尔/null/嵌套/数组/Unicode）。"""
import json
import random
import sys

TARGET_BYTES = 10 * 1024 * 1024  # 10MB

WORDS = ("alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu "
         "nu xi omicron pi rho sigma tau upsilon phi chi psi omega").split()
CITIES = ["深圳", "北京", "上海", "广州", "杭州", "成都", "武汉", "西安"]
TAGS = ["json", "formatter", "macos", "swift", "parser", "unicode", "测试", "性能"]


def make_record(rng: random.Random, i: int) -> dict:
    return {
        "id": i,
        "uuid": f"{rng.getrandbits(128):032x}",
        "name": f"{rng.choice(WORDS)}-{rng.choice(WORDS)}-{i}",
        "active": rng.random() < 0.5,
        "score": round(rng.uniform(0, 100), 6),
        "balance": round(rng.uniform(-5000, 50000), 2),
        "nullable": None if rng.random() < 0.2 else rng.choice(WORDS),
        "address": {
            "city": rng.choice(CITIES),
            "zip": f"{rng.randrange(100000, 999999)}",
            "geo": {"lat": round(rng.uniform(-90, 90), 6), "lng": round(rng.uniform(-180, 180), 6)},
        },
        "tags": rng.sample(TAGS, k=rng.randrange(1, 4)),
        "history": [
            {"ts": 1720000000 + rng.randrange(0, 10_000_000), "delta": rng.randrange(-100, 100)}
            for _ in range(rng.randrange(1, 4))
        ],
        "bio": "这是一段中文描述文本，用于测试 Unicode 处理与转义行为 🚀 — " + "x" * rng.randrange(0, 40),
    }


def main(out_path: str) -> None:
    rng = random.Random(20261013)
    written = 0
    i = 0
    with open(out_path, "w", encoding="utf-8") as f:
        f.write('{"meta":{"generator":"json-pretty-test","version":1},"items":[')
        written += 60
        first = True
        while written < TARGET_BYTES:
            chunk = json.dumps(make_record(rng, i), ensure_ascii=False, separators=(",", ":"))
            if not first:
                chunk = "," + chunk
            first = False
            f.write(chunk)
            written += len(chunk.encode("utf-8"))
            i += 1
        f.write("]}")
    print(f"✅ {out_path}: {i} 条记录")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "testdata/large-10mb.json")
