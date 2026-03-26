#!/usr/bin/env python3
"""
Pick points from a Nav2 occupancy map and print map-frame coordinates.

No ROS runtime required.

Example:
  python3 ~/nav_ws/map_point_picker.py ~/Desktop/map/11_map.yaml
"""

from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import yaml
from PIL import Image


def load_map(map_yaml: Path):
    with map_yaml.open("r", encoding="utf-8") as f:
        meta = yaml.safe_load(f)

    image_rel = meta["image"]
    resolution = float(meta["resolution"])
    origin = meta["origin"]  # [x, y, yaw]

    image_path = (map_yaml.parent / image_rel).resolve()
    img = Image.open(image_path).convert("L")
    arr = np.array(img)
    height, width = arr.shape
    return arr, width, height, resolution, origin, image_path


def pixel_to_map(px: float, py: float, height: int, resolution: float, origin):
    # Map convention: image origin at top-left, map origin at bottom-left.
    # Use pixel center (+0.5) for better consistency.
    map_x = origin[0] + (px + 0.5) * resolution
    map_y = origin[1] + (height - py - 0.5) * resolution
    return map_x, map_y


def main():
    parser = argparse.ArgumentParser(description="Click map to get map-frame coordinates")
    parser.add_argument("map_yaml", type=Path, help="Path to Nav2 map yaml (e.g. 11_map.yaml)")
    args = parser.parse_args()

    arr, width, height, resolution, origin, image_path = load_map(args.map_yaml.resolve())

    fig, ax = plt.subplots(figsize=(10, 8))
    ax.imshow(arr, cmap="gray", origin="upper")
    ax.set_title(
        "Click points on map (close window to finish)\n"
        f"resolution={resolution} m/px, origin=({origin[0]}, {origin[1]}, yaw={origin[2]})\n"
        "Left click to mark points"
    )
    ax.set_xlabel("pixel x")
    ax.set_ylabel("pixel y")

    index = {"n": 0}

    def on_click(event):
        if event.inaxes != ax or event.xdata is None or event.ydata is None:
            return
        px = float(event.xdata)
        py = float(event.ydata)
        mx, my = pixel_to_map(px, py, height, resolution, origin)
        index["n"] += 1

        ax.plot(px, py, "ro", markersize=5)
        ax.text(px + 2, py + 2, str(index["n"]), color="red", fontsize=9)
        fig.canvas.draw_idle()

        print(
            f"[{index['n']}] pixel=({px:.1f}, {py:.1f}) -> "
            f"map=({mx:.3f}, {my:.3f}, 0.000)"
        )

    fig.canvas.mpl_connect("button_press_event", on_click)

    print(f"Loaded map yaml: {args.map_yaml.resolve()}")
    print(f"Loaded image:    {image_path}")
    print(f"Image size:      {width} x {height}")
    print(f"Resolution:      {resolution} m/pixel")
    print(f"Origin:          x={origin[0]}, y={origin[1]}, yaw={origin[2]}")
    print("Click on map; coordinates will be printed here.")

    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    main()
