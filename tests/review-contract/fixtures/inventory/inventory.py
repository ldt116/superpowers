import json
import pathlib

DB = pathlib.Path(__file__).parent / "stock.json"


def load():
    return json.loads(DB.read_text())


def deduct(sku, qty):
    """Write path: mutates persistent stock state."""
    stock = load()
    remaining = stock.get(sku, 0) - qty
    if remaining < 0:
        raise ValueError(f"insufficient stock for {sku}")
    stock[sku] = remaining
    DB.write_text(json.dumps(stock))
    return remaining
