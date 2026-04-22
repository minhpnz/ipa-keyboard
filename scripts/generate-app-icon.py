#!/usr/bin/env python3
"""Generate IPA Keyboard app icon and menu bar tray icon.

App Icon: Modern dark gradient with bold "IPA" text, schwa accent,
clean indigo-to-amber gradient stripe.

Tray Icon: Clean monochrome "ə" (schwa) symbol for macOS menu bar.
Works as a template image (black on transparent).
"""

import math
import os
import shutil
from PIL import Image, ImageDraw, ImageFont, ImageFilter


# --- Palette ---
BG_TOP = (13, 17, 38)            # Very dark navy (top)
BG_BOT = (30, 41, 82)            # Deep indigo-navy (bottom)
INDIGO = (99, 102, 241)          # #6366f1 accent
INDIGO_LIGHT = (139, 142, 255)   # Lighter indigo
AMBER = (245, 158, 11)           # #f59e0b warm amber
AMBER_LIGHT = (251, 191, 36)     # #fbbf24
WHITE = (255, 255, 255)
NEAR_WHITE = (230, 235, 245)
SLATE = (120, 136, 162)


def get_font(size, bold=True):
    """Get a good system font."""
    font_paths = [
        "/System/Library/Fonts/SFCompact-Bold.otf" if bold else "/System/Library/Fonts/SFCompact-Regular.otf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
    ]
    for path in font_paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def create_rounded_rect_mask(size, margin, corner_r):
    """Create an alpha mask for the rounded rect shape."""
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    x0, y0, x1, y1 = margin, margin, size - margin, size - margin
    md.rounded_rectangle([x0, y0, x1, y1], radius=corner_r, fill=255)
    return mask


def generate_icon(size):
    """Generate the app icon at given size."""
    margin = int(size * 0.04)
    corner_r = int(size * 0.22)

    # Shape mask
    shape_mask = create_rounded_rect_mask(size, margin, corner_r)

    # --- Gradient background ---
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / size
        # Smooth eased gradient
        t_ease = t * t * (3 - 2 * t)
        r = int(BG_TOP[0] * (1 - t_ease) + BG_BOT[0] * t_ease)
        g = int(BG_TOP[1] * (1 - t_ease) + BG_BOT[1] * t_ease)
        b = int(BG_TOP[2] * (1 - t_ease) + BG_BOT[2] * t_ease)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # --- Subtle radial highlight (top-center, very soft) ---
    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    cx, cy = int(size * 0.5), int(size * 0.25)
    max_r = int(size * 0.45)
    for r_i in range(max_r, 0, -2):
        alpha = int(12 * (1 - (r_i / max_r)) ** 1.5)
        hd.ellipse(
            [cx - r_i, cy - r_i, cx + r_i, cy + r_i],
            fill=(INDIGO_LIGHT[0], INDIGO_LIGHT[1], INDIGO_LIGHT[2], alpha),
        )
    img = Image.alpha_composite(img, highlight)
    draw = ImageDraw.Draw(img)

    # --- Schwa watermark "ə" (large, very faint, offset right) ---
    wm_size = int(size * 0.55)
    wm_font = get_font(wm_size, bold=False)
    wm_text = "ə"
    wm_bbox = draw.textbbox((0, 0), wm_text, font=wm_font)
    wm_w = wm_bbox[2] - wm_bbox[0]
    wm_h = wm_bbox[3] - wm_bbox[1]
    wm_x = size - int(size * 0.18) - wm_w // 2
    wm_y = int(size * 0.08)

    wm_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wm_layer)
    wd.text((wm_x, wm_y), wm_text, font=wm_font, fill=(INDIGO_LIGHT[0], INDIGO_LIGHT[1], INDIGO_LIGHT[2], 22))
    img = Image.alpha_composite(img, wm_layer)
    draw = ImageDraw.Draw(img)

    # --- Main text: "IPA" ---
    main_size = int(size * 0.30)
    main_font = get_font(main_size, bold=True)
    text = "IPA"
    bbox = draw.textbbox((0, 0), text, font=main_font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (size - tw) // 2
    ty = int(size * 0.22)

    # Text shadow (subtle)
    shadow_offset = max(int(size * 0.005), 1)
    shadow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_layer)
    sd.text((tx + shadow_offset, ty + shadow_offset), text, font=main_font, fill=(0, 0, 0, 80))
    # Blur the shadow slightly
    if size >= 128:
        shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=max(size * 0.004, 1)))
    img = Image.alpha_composite(img, shadow_layer)
    draw = ImageDraw.Draw(img)

    # Main text in bright white
    draw.text((tx, ty), text, font=main_font, fill=WHITE)

    # --- Accent stripe: gradient bar (indigo → amber) ---
    stripe_y = int(size * 0.62)
    stripe_h = max(int(size * 0.018), 2)
    stripe_margin_l = int(size * 0.16)
    stripe_margin_r = int(size * 0.16)
    stripe_w = size - stripe_margin_l - stripe_margin_r

    stripe_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sld = ImageDraw.Draw(stripe_layer)
    for x in range(stripe_margin_l, size - stripe_margin_r):
        t = (x - stripe_margin_l) / stripe_w
        # Indigo → Amber gradient with a brighter midpoint
        if t < 0.5:
            t2 = t * 2
            r = int(INDIGO[0] * (1 - t2) + INDIGO_LIGHT[0] * t2)
            g = int(INDIGO[1] * (1 - t2) + INDIGO_LIGHT[1] * t2)
            b = int(INDIGO[2] * (1 - t2) + INDIGO_LIGHT[2] * t2)
        else:
            t2 = (t - 0.5) * 2
            r = int(INDIGO_LIGHT[0] * (1 - t2) + AMBER[0] * t2)
            g = int(INDIGO_LIGHT[1] * (1 - t2) + AMBER[1] * t2)
            b = int(INDIGO_LIGHT[2] * (1 - t2) + AMBER[2] * t2)
        for dy in range(stripe_h):
            sld.point((x, stripe_y + dy), fill=(r, g, b, 200))
    img = Image.alpha_composite(img, stripe_layer)
    draw = ImageDraw.Draw(img)

    # --- Subtitle: "KEYBOARD" below stripe ---
    sub_size = int(size * 0.075)
    if sub_size >= 6:
        sub_font = get_font(sub_size, bold=False)
        sub_text = "KEYBOARD"
        sub_bbox = draw.textbbox((0, 0), sub_text, font=sub_font)
        sub_w = sub_bbox[2] - sub_bbox[0]
        sub_x = (size - sub_w) // 2
        sub_y = stripe_y + stripe_h + int(size * 0.04)
        draw.text((sub_x, sub_y), sub_text, font=sub_font, fill=(*SLATE, 180))

    # --- Small decorative dots (top-left and bottom-right corners) ---
    dot_r = max(int(size * 0.012), 1)

    # Top-left indigo dot
    d1x, d1y = int(size * 0.14), int(size * 0.13)
    draw.ellipse([d1x - dot_r, d1y - dot_r, d1x + dot_r, d1y + dot_r],
                 fill=(*INDIGO_LIGHT, 100))

    # Bottom-right amber dot
    d2x, d2y = int(size * 0.86), int(size * 0.87)
    draw.ellipse([d2x - dot_r, d2y - dot_r, d2x + dot_r, d2y + dot_r],
                 fill=(*AMBER, 100))

    # --- Apply rounded rect mask ---
    result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    result.paste(img, (0, 0), shape_mask)

    return result


def generate_tray_icon(size):
    """Generate a monochrome tray icon with the schwa "ə" symbol.

    macOS template images: black content on transparent background.
    The OS automatically adapts for light/dark menu bar.
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Use ~80% of the icon size for the schwa character
    font_size = int(size * 0.78)
    font = get_font(font_size, bold=True)

    text = "ə"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]

    # Center the character
    tx = (size - tw) // 2 - bbox[0]
    ty = (size - th) // 2 - bbox[1]

    # Draw in solid black (macOS will template it)
    draw.text((tx, ty), text, font=font, fill=(0, 0, 0, 255))

    return img


def main():
    icon_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "companion-app", "src-tauri", "icons",
    )
    os.makedirs(icon_dir, exist_ok=True)

    # --- App icons ---
    sizes = {
        "icon.png": 1024,
        "32x32.png": 32,
        "128x128.png": 128,
        "128x128@2x.png": 256,
        "Square30x30Logo.png": 30,
        "Square44x44Logo.png": 44,
        "Square71x71Logo.png": 71,
        "Square89x89Logo.png": 89,
        "Square107x107Logo.png": 107,
        "Square142x142Logo.png": 142,
        "Square150x150Logo.png": 150,
        "Square284x284Logo.png": 284,
        "Square310x310Logo.png": 310,
        "StoreLogo.png": 50,
    }

    print("Generating app icons...")
    master = generate_icon(1024)

    for name, sz in sizes.items():
        if sz == 1024:
            img = master.copy()
        else:
            img = master.resize((sz, sz), Image.LANCZOS)
        path = os.path.join(icon_dir, name)
        img.save(path, "PNG")
        print(f"  {name} ({sz}x{sz})")

    # --- ICO (Windows) ---
    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    ico_images = [master.resize((s, s), Image.LANCZOS) for s in ico_sizes]
    ico_path = os.path.join(icon_dir, "icon.ico")
    ico_images[0].save(ico_path, format="ICO",
                       sizes=[(s, s) for s in ico_sizes],
                       append_images=ico_images[1:])
    print(f"  icon.ico ({', '.join(str(s) for s in ico_sizes)})")

    # --- ICNS (macOS) ---
    icns_path = os.path.join(icon_dir, "icon.icns")
    iconset_dir = os.path.join(icon_dir, "icon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    icns_sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, sz in icns_sizes.items():
        img = master.resize((sz, sz), Image.LANCZOS) if sz != 1024 else master.copy()
        img.save(os.path.join(iconset_dir, name), "PNG")

    ret = os.system(f"iconutil -c icns '{iconset_dir}' -o '{icns_path}' 2>/dev/null")
    if ret == 0:
        print(f"  icon.icns (via iconutil)")
    else:
        master.resize((256, 256), Image.LANCZOS).save(icns_path, "PNG")
        print(f"  icon.icns (fallback PNG)")

    shutil.rmtree(iconset_dir, ignore_errors=True)

    # --- Tray icons (menu bar) ---
    print("\nGenerating tray icons (ə symbol)...")
    tray_22 = generate_tray_icon(22)
    tray_22.save(os.path.join(icon_dir, "tray-icon.png"), "PNG")
    print("  tray-icon.png (22x22)")

    tray_44 = generate_tray_icon(44)
    tray_44.save(os.path.join(icon_dir, "tray-icon@2x.png"), "PNG")
    print("  tray-icon@2x.png (44x44)")

    print(f"\nAll icons saved to {icon_dir}")


if __name__ == "__main__":
    main()
