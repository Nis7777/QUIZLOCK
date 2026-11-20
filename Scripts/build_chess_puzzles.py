#!/usr/bin/env python3
"""
Builds Resources/chess_puzzles.json from the Lichess puzzle database (CC0).

Usage:
    python3 -m venv .venv && .venv/bin/pip install zstandard chess
    .venv/bin/python Scripts/build_chess_puzzles.py

The raw download (Scripts/lichess_db_puzzle.csv.zst) is git-ignored.

CSV columns:
    PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags,DailyDate

FEN is the position BEFORE the opponent's move. The first UCI move in Moves is
the opponent's move; the rest alternate player move / opponent reply.
"""
import csv
import io
import json
import os
import random
import sys
import urllib.request

import chess          # pip install chess
import zstandard      # pip install zstandard

URL = "https://database.lichess.org/lichess_db_puzzle.csv.zst"
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "lichess_db_puzzle.csv.zst")
OUT = os.path.join(HERE, "..", "Resources", "chess_puzzles.json")
PER_BUCKET = 300
SEED = 20261120


def download():
    if os.path.exists(RAW) and os.path.getsize(RAW) > 10_000_000:
        print(f"Using cached {RAW}")
        return
    print(f"Downloading {URL} …")
    tmp = RAW + ".part"
    with urllib.request.urlopen(URL) as r, open(tmp, "wb") as f:
        total = 0
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            total += len(chunk)
            if total % (50 << 20) < (1 << 20):
                print(f"  {total >> 20} MB")
    os.replace(tmp, RAW)


def bucket_for(mate_in, rating):
    if mate_in == 1 and rating < 1300:
        return "easy"
    if (mate_in == 1 and 1300 <= rating <= 1800) or (mate_in == 2 and rating < 1500):
        return "medium"
    if mate_in == 2 and rating >= 1500:
        return "hard"
    return None


def validate(fen, moves, mate_in):
    """Returns True if the puzzle is consistent: all moves legal and the last one mates."""
    board = chess.Board(fen)
    for uci in moves:
        mv = chess.Move.from_uci(uci)
        if mv not in board.legal_moves:
            return False
        board.push(mv)
    if not board.is_checkmate():
        return False
    # opponent move + (2*mate_in - 1) puzzle moves
    return len(moves) == 2 * mate_in


def main():
    download()
    buckets = {"easy": [], "medium": [], "hard": []}
    dctx = zstandard.ZstdDecompressor()
    rows = 0
    with open(RAW, "rb") as fh, dctx.stream_reader(fh) as reader:
        text = io.TextIOWrapper(reader, encoding="utf-8", newline="")
        for row in csv.DictReader(text):
            rows += 1
            themes = row["Themes"].split()
            if "mateIn1" in themes:
                mate_in = 1
            elif "mateIn2" in themes:
                mate_in = 2
            else:
                continue
            try:
                popularity = int(row["Popularity"])
                plays = int(row["NbPlays"])
                rating = int(row["Rating"])
            except ValueError:
                continue
            if popularity < 85 or plays < 500:
                continue
            b = bucket_for(mate_in, rating)
            if b is None:
                continue
            buckets[b].append((row["PuzzleId"], row["FEN"], row["Moves"].split(), rating, mate_in))
    print(f"Scanned {rows} rows: " + ", ".join(f"{k}={len(v)}" for k, v in buckets.items()))

    rng = random.Random(SEED)
    out = []
    for name in ("easy", "medium", "hard"):
        pool = buckets[name]
        rng.shuffle(pool)
        picked = 0
        for pid, fen, moves, rating, mate_in in pool:
            if picked >= PER_BUCKET:
                break
            if not validate(fen, moves, mate_in):
                continue
            out.append({
                "id": pid,
                "fen": fen,
                "opponentFirstMove": moves[0],
                "solution": moves[1:],
                "rating": rating,
                "mateIn": mate_in,
                "difficulty": name,
            })
            picked += 1
        print(f"{name}: {picked}")
    # Easy puzzles sorted so the very first one is the lowest rated (used by onboarding).
    easy = sorted([p for p in out if p["difficulty"] == "easy"], key=lambda p: p["rating"])
    rest = [p for p in out if p["difficulty"] != "easy"]
    with open(OUT, "w") as f:
        json.dump(easy + rest, f, separators=(",", ":"))
    print(f"Wrote {len(out)} puzzles to {os.path.normpath(OUT)}")


if __name__ == "__main__":
    sys.exit(main())
