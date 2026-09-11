import os
import numpy as np
from PIL import Image, ImageEnhance

def recolor_frame(img, hue_deg=0, sat_mult=1.0, val_mult=1.0, gradient_hue=None):
    r, g, b, a = img.split()
    rgb_img = Image.merge("RGB", (r, g, b))

    hsv_img = rgb_img.convert("HSV")
    _, s, v = hsv_img.split()
    width, height = img.size
    if gradient_hue:
        start_deg, end_deg = gradient_hue
        x = np.linspace(0, 1, width)
        y = np.linspace(0, 1, height)
        xx, yy = np.meshgrid(x, y)
        
        diag = (xx + yy) / 2.0
        h_array = (start_deg + (end_deg - start_deg) * diag) % 360.0
        new_h = Image.fromarray((h_array / 360.0 * 255).astype(np.uint8), mode="L")
    else:
        target_h = int((hue_deg % 360) / 360.0 * 255)
        new_h = Image.new("L", (width, height), target_h)

    new_s = s.point(lambda p: min(255, int(p * sat_mult)))
    new_v = ImageEnhance.Brightness(v).enhance(val_mult)
    
    new_hsv = Image.merge("HSV", (new_h, new_s, new_v))
    new_rgb = new_hsv.convert("RGB")
    r2, g2, b2 = new_rgb.split()
    
    return Image.merge("RGBA", (r2, g2, b2, a))

def generate_rarity_icons(image_path="Icon.png", output_dir="Rarity"):
    if not os.path.exists(image_path):
        print(f"File '{image_path}' not found.")
        return

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    base_img = Image.open(image_path).convert("RGBA")

    rarities = {
        "common": {
            "sat_mult": 0.0,
            "val_mult": 0.85
        },
        "uncommon": {
            "hue_deg": 125,
            "sat_mult": 1.1,
            "val_mult": 1.0
        },
        "rare": {
            "hue_deg": 215,
            "sat_mult": 1.15,
            "val_mult": 1.0
        },
        "epic": {
            "hue_deg": 285,
            "sat_mult": 1.2,
            "val_mult": 0.98
        },
        "legendary": {
            "hue_deg": 38,
            "sat_mult": 1.0,
            "val_mult": 1.0
        },
        "mythic": {
            "gradient_hue": (295, 175),
            "sat_mult": 1.3,
            "val_mult": 1.12
        }
    }

    for rarity, settings in rarities.items():
        recolored_img = recolor_frame(
            base_img,
            hue_deg=settings.get("hue_deg", 0),
            sat_mult=settings.get("sat_mult", 1.0),
            val_mult=settings.get("val_mult", 1.0),
            gradient_hue=settings.get("gradient_hue", None)
        )
        
        output_path = os.path.join(output_dir, f"{rarity}.png")
        recolored_img.save(output_path, "PNG")

if __name__ == "__main__":
    generate_rarity_icons("Icon.png")