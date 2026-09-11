"""Generate a synthetic dashboard frame for visual smoke testing.

This is a software-only approximation of the procedural layout; it is not
part of the synthesizable RTL. Run from the repository root:
    python sim/vga_dashboard_ppm.py
"""
from pathlib import Path

W, H = 640, 480
img = [[(0, 0, 0) for _ in range(W)] for _ in range(H)]

def put(x, y, color):
    if 0 <= x < W and 0 <= y < H:
        img[y][x] = color

for x in range(64, 576):
    if (x - 64) % 64 == 0:
        for y in range(72, 281): put(x, y, (24, 48, 72))
for y in (72, 112, 152, 192, 232, 272):
    for x in range(64, 576): put(x, y, (24, 48, 72))

for x in range(64, 576):
    bin_no = x - 64
    height = 8 + (170 if bin_no == 100 else 70 if bin_no == 200 else 16)
    for y in range(max(72, 280 - height), 281): put(x, y, (0, 204, 255))

for i in range(13):
    value = (i - 5) * 4
    height = min(45, abs(value))
    for y in range(405 - height if value >= 0 else 406, 406 + height if value < 0 else 405):
        for x in range(60 + i * 20, 75 + i * 20): put(x, y, (255, 255, 0))

out = Path("simulation_output")
out.mkdir(exist_ok=True)
with (out / "dashboard_frame.ppm").open("w", encoding="ascii") as f:
    f.write(f"P3\n{W} {H}\n255\n")
    for row in img:
        f.write(" ".join(f"{r} {g} {b}" for r, g, b in row) + "\n")
print(out / "dashboard_frame.ppm")
