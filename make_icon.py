#!/usr/bin/env python3
"""
Generate DSA Malawi app icon — green background, white document + MWK symbol.
Outputs all Android mipmap sizes and the base 1024x1024.
"""
from PIL import Image, ImageDraw, ImageFont
import os

SIZES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

BASE = 1024
BG_COLOR   = (26, 107, 60)    # Malawi green
DOC_COLOR  = (255, 255, 255)  # white
FOLD_COLOR = (180, 230, 200)  # light green for fold
TEXT_COLOR = (26, 107, 60)


def draw_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size

    # Rounded square background
    r = s // 5
    draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill=BG_COLOR)

    # Document body
    pad  = s * 0.18
    fold = s * 0.18
    doc_l = pad
    doc_t = pad
    doc_r = s - pad
    doc_b = s - pad * 0.9

    # Main doc shape (polygon with folded corner)
    doc_pts = [
        (doc_l, doc_t),
        (doc_r - fold, doc_t),
        (doc_r, doc_t + fold),
        (doc_r, doc_b),
        (doc_l, doc_b),
    ]
    draw.polygon(doc_pts, fill=DOC_COLOR)

    # Fold triangle
    fold_pts = [
        (doc_r - fold, doc_t),
        (doc_r, doc_t + fold),
        (doc_r - fold, doc_t + fold),
    ]
    draw.polygon(fold_pts, fill=FOLD_COLOR)

    # Lines representing text on the document
    line_color = (180, 210, 190)
    lx1 = doc_l + s * 0.12
    lx2 = doc_r - s * 0.12
    line_y_start = doc_t + fold + s * 0.07
    line_gap = s * 0.09
    for i in range(4):
        y = line_y_start + i * line_gap
        # shorten last line
        x2 = lx2 if i < 3 else lx1 + (lx2 - lx1) * 0.55
        draw.rounded_rectangle([lx1, y, x2, y + s * 0.04], radius=2, fill=line_color)

    # MWK label at bottom of doc
    label_area_top = doc_b - s * 0.22
    draw.rounded_rectangle(
        [lx1, label_area_top, lx1 + (lx2 - lx1) * 0.6, label_area_top + s * 0.1],
        radius=s * 0.02,
        fill=BG_COLOR,
    )

    # "MK" text inside the badge
    font_size = max(8, int(s * 0.085))
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
    except Exception:
        font = ImageFont.load_default()

    badge_cx = lx1 + (lx2 - lx1) * 0.3
    badge_cy = label_area_top + s * 0.05
    draw.text((badge_cx, badge_cy), "MK", fill=DOC_COLOR, font=font, anchor="mm")

    return img


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    android_res = os.path.join(script_dir, "android", "app", "src", "main", "res")

    # Save base 1024px icon
    base_img = draw_icon(BASE)
    base_img.save(os.path.join(script_dir, "app_icon_1024.png"))
    print("Saved app_icon_1024.png")

    # Save each mipmap size
    for folder, size in SIZES.items():
        out_dir = os.path.join(android_res, folder)
        os.makedirs(out_dir, exist_ok=True)
        icon = draw_icon(size)
        path = os.path.join(out_dir, "ic_launcher.png")
        icon.save(path)
        print(f"Saved {folder}/ic_launcher.png ({size}x{size})")


if __name__ == "__main__":
    main()
