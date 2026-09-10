import os
from PIL import Image, ImageEnhance

def recolor_frame(img, hue_deg, sat_mult=1.0, val_mult=1.0, is_grey=False):
    r, g, b, a = img.split()
    rgb_img = Image.merge("RGB", (r, g, b))

    hsv_img = rgb_img.convert("HSV")
    h, s, v = hsv_img.split()

    if is_grey:
        new_s = Image.new("L", s.size, 0)
        v_enhanced = ImageEnhance.Brightness(v).enhance(val_mult)
        new_hsv = Image.merge("HSV", (h, new_s, v_enhanced))
    else:
        target_h = int((hue_deg % 360) / 360.0 * 255)
        new_h = Image.new("L", h.size, target_h)
        
        s_enhanced = ImageEnhance.Color(Image.merge("RGB", (s, s, s))).enhance(sat_mult).split()[0]
        v_enhanced = ImageEnhance.Brightness(v).enhance(val_mult)
        
        new_hsv = Image.merge("HSV", (new_h, s_enhanced, v_enhanced))

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
            "is_grey": True,
            "val_mult": 0.85,
            "hue_deg": 0
        },
        "uncommon": {
            "hue_deg": 125,
            "sat_mult": 1.1,
            "val_mult": 1.0,
            "is_grey": False
        },
        "rare": {
            "hue_deg": 215,
            "sat_mult": 1.15,
            "val_mult": 1.0,
            "is_grey": False
        },
        "epic": {
            "hue_deg": 285,
            "sat_mult": 1.2,
            "val_mult": 0.98,
            "is_grey": False
        },
        "legendary": {
            "hue_deg": 38,
            "sat_mult": 1.0,
            "val_mult": 1.0,
            "is_grey": False
        }
    }

    for rarity, settings in rarities.items():
        recolored_img = recolor_frame(
            base_img,
            hue_deg=settings.get("hue_deg", 0),
            sat_mult=settings.get("sat_mult", 1.0),
            val_mult=settings.get("val_mult", 1.0),
            is_grey=settings.get("is_grey", False)
        )
        
        output_path = os.path.join(output_dir, f"{rarity}.png")
        recolored_img.save(output_path, "PNG")

if __name__ == "__main__":
    generate_rarity_icons("Icon.png")