"""Generate app icon for Dexcom Glucose Widget."""
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 1024
CX, CY = SIZE // 2, SIZE // 2


def rounded_rect_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def draw_drop(draw, cx, cy, scale=1.0, fill=(38, 180, 100)):
    """Draw a smooth teardrop/blood drop shape using circles and tangent lines."""
    # The drop is a circle at the bottom with a pointed top
    r = int(185 * scale)  # radius of the bulge
    bulge_cy = cy + int(60 * scale)  # center of the circle

    # Tip of the drop
    tip_y = cy - int(280 * scale)

    # Build smooth drop outline
    points = []

    # The drop tip connects to the circle via tangent lines
    # Calculate tangent points
    dx = cx - cx  # 0, drop is centered
    dy = tip_y - bulge_cy
    dist = abs(dy)
    if dist > r:
        tangent_angle = math.asin(r / dist)
    else:
        tangent_angle = math.pi / 4

    # Right tangent point on circle
    ta = math.pi / 2 - tangent_angle
    rt_x = cx + r * math.sin(ta)
    rt_y = bulge_cy - r * math.cos(ta)

    # Left tangent point on circle
    lt_x = cx - r * math.sin(ta)
    lt_y = rt_y

    # Build path: tip -> right tangent -> circle arc -> left tangent -> tip
    # Tip
    points.append((cx, tip_y))

    # Right side: straight line from tip to right tangent (with slight curve)
    steps = 30
    for i in range(1, steps + 1):
        t = i / steps
        # Quadratic bezier: tip -> control -> tangent point
        ctrl_x = cx + r * 0.3
        ctrl_y = tip_y + (rt_y - tip_y) * 0.5
        x = (1 - t) ** 2 * cx + 2 * (1 - t) * t * ctrl_x + t ** 2 * rt_x
        y = (1 - t) ** 2 * tip_y + 2 * (1 - t) * t * ctrl_y + t ** 2 * rt_y
        points.append((int(x), int(y)))

    # Circle arc from right tangent to left tangent (going around the bottom)
    start_angle = math.atan2(rt_y - bulge_cy, rt_x - cx)
    end_angle = math.atan2(lt_y - bulge_cy, lt_x - cx)
    if end_angle > start_angle:
        end_angle -= 2 * math.pi

    arc_steps = 60
    for i in range(arc_steps + 1):
        t = i / arc_steps
        angle = start_angle + t * (2 * math.pi + end_angle - start_angle)
        x = cx + r * math.cos(angle)
        y = bulge_cy + r * math.sin(angle)
        points.append((int(x), int(y)))

    # Left side: straight line from left tangent back to tip
    for i in range(1, steps):
        t = i / steps
        ctrl_x = cx - r * 0.3
        ctrl_y = tip_y + (lt_y - tip_y) * 0.5
        x = (1 - t) ** 2 * lt_x + 2 * (1 - t) * t * ctrl_x + t ** 2 * cx
        y = (1 - t) ** 2 * lt_y + 2 * (1 - t) * t * ctrl_y + t ** 2 * tip_y
        points.append((int(x), int(y)))

    draw.polygon(points, fill=fill)
    return points


def create_icon():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    corner = 228

    # Dark background
    draw.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=corner, fill=(20, 20, 24))

    # Subtle top gradient
    mask = rounded_rect_mask(SIZE, corner)
    gradient = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(gradient)
    for y in range(SIZE // 2):
        a = int(18 * (1 - y / (SIZE // 2)))
        gdraw.line([(0, y), (SIZE, y)], fill=(255, 255, 255, a))
    gradient.putalpha(mask)
    img = Image.alpha_composite(img, gradient)

    # Glow behind the drop
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for r in range(250, 0, -1):
        alpha = int(35 * (1 - r / 250))
        gdraw.ellipse(
            [CX - r, CY + 20 - r, CX + r, CY + 20 + r],
            fill=(30, 180, 90, alpha),
        )
    glow.putalpha(mask)
    img = Image.alpha_composite(img, glow)

    # Draw the drop with gradient
    drop_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ddraw = ImageDraw.Draw(drop_layer)
    points = draw_drop(ddraw, CX, CY, scale=1.0, fill=(34, 160, 88))

    # Gradient over the drop
    drop_grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    dgdraw = ImageDraw.Draw(drop_grad)
    for y in range(SIZE):
        t = y / SIZE
        r = int(25 + 25 * t)
        g = int(190 - 70 * t)
        b = int(110 - 40 * t)
        dgdraw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))
    # Mask to drop shape
    drop_mask = Image.new("L", (SIZE, SIZE), 0)
    dmdraw = ImageDraw.Draw(drop_mask)
    dmdraw.polygon(points, fill=255)
    drop_grad.putalpha(drop_mask)
    img = Image.alpha_composite(img, drop_grad)

    # Subtle edge highlight on the drop (thin lighter border on left side)
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    # Slightly smaller drop, offset left, creates a crescent highlight
    inner_points = []
    for px, py in points:
        # Shift slightly toward center-right and shrink
        nx = CX + (px - CX) * 0.94 + 8
        ny = CY + (py - CY) * 0.94
        inner_points.append((int(nx), int(ny)))
    # Draw full drop in highlight color, then cut out inner
    hdraw.polygon(points, fill=(255, 255, 255, 22))
    hdraw.polygon(inner_points, fill=(0, 0, 0, 0))
    # Clip to drop
    clip_mask = Image.new("L", (SIZE, SIZE), 0)
    cmdraw = ImageDraw.Draw(clip_mask)
    cmdraw.polygon(points, fill=255)
    highlight.putalpha(clip_mask)
    img = Image.alpha_composite(img, highlight)

    draw = ImageDraw.Draw(img)

    # Text: "120"
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFCompact-Bold.otf", 200)
    except (OSError, IOError):
        try:
            font = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", 200)
        except (OSError, IOError):
            try:
                font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 200)
            except (OSError, IOError):
                font = ImageFont.load_default()

    text = "120"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = CX - tw // 2 - bbox[0]
    ty = CY + 30 - th // 2 - bbox[1]

    # Shadow
    draw.text((tx + 3, ty + 3), text, fill=(0, 0, 0, 100), font=font)
    draw.text((tx, ty), text, fill=(255, 255, 255, 250), font=font)

    # Small unit label
    try:
        small_font = ImageFont.truetype("/System/Library/Fonts/SFCompact-Medium.otf", 56)
    except (OSError, IOError):
        try:
            small_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 56)
        except (OSError, IOError):
            small_font = ImageFont.load_default()

    unit = "mg/dL"
    ubbox = draw.textbbox((0, 0), unit, font=small_font)
    uw = ubbox[2] - ubbox[0]
    ux = CX - uw // 2 - ubbox[0]
    uy = ty + th + 16
    draw.text((ux, uy), unit, fill=(255, 255, 255, 150), font=small_font)

    return img


def export_sizes(img, output_dir):
    sizes = [
        (16, 1), (16, 2), (32, 1), (32, 2),
        (128, 1), (128, 2), (256, 1), (256, 2),
        (512, 1), (512, 2),
    ]
    for size, scale in sizes:
        px = size * scale
        resized = img.resize((px, px), Image.LANCZOS)
        suffix = "@2x" if scale == 2 else ""
        filename = f"icon_{size}x{size}{suffix}.png"
        resized.save(f"{output_dir}/{filename}")
        print(f"  {filename} ({px}x{px})")


def update_contents_json(output_dir):
    import json
    sizes = [
        (16, 1), (16, 2), (32, 1), (32, 2),
        (128, 1), (128, 2), (256, 1), (256, 2),
        (512, 1), (512, 2),
    ]
    images = []
    for size, scale in sizes:
        suffix = "@2x" if scale == 2 else ""
        images.append({
            "filename": f"icon_{size}x{size}{suffix}.png",
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{size}x{size}",
        })
    with open(f"{output_dir}/Contents.json", "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)


if __name__ == "__main__":
    output = "DexcomWidget/Assets.xcassets/AppIcon.appiconset"
    print("Generating app icon...")
    icon = create_icon()
    print(f"Exporting to {output}/")
    export_sizes(icon, output)
    update_contents_json(output)
    print("Done!")
