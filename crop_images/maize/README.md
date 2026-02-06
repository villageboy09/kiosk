# Maize/Corn Crop Problem Image Dataset

## Overview

This dataset contains AI-generated photorealistic images of common maize (corn) crop problems, organized by category, problem type, and severity stage. The dataset is designed for training machine learning models for automated crop problem identification and early detection.

**Total Images:** 60  
**Crop:** Maize / Corn (*Zea mays*)  
**Stages per Problem:** Early, Mid, Late  
**Image Format:** PNG  
**Generated:** February 2026  

---

## Dataset Structure

```
maize/
├── README.md
├── {problem_name}/
│   ├── early/
│   │   └── 001.png
│   ├── mid/
│   │   └── 001.png
│   └── late/
│       └── 001.png
```

---

## Categories

### 1. Pests (7 types × 3 stages = 21 images)

| Folder Name | Common Name | Scientific Name |
|---|---|---|
| `shoot_fly` | Shoot Fly | *Atherigona orientalis* |
| `fall_armyworm` | Fall Armyworm | *Spodoptera frugiperda* |
| `stem_borer` | Stem Borer | *Chilo partellus* |
| `ear_head_bug` | Ear Head Bug | *Calocoris angustatus* |
| `pink_stem_borer` | Pink Stem Borer | *Sesamia inferens* |
| `aphid` | Aphid / Plant Lice | *Rhopalosiphum maidis* |
| `corn_worm` | Corn Worm | *Helicoverpa armigera* |

### 2. Diseases (5 types × 3 stages = 15 images)

| Folder Name | Common Name | Causal Agent |
|---|---|---|
| `downy_mildew_crazy_top` | Downy Mildew / Crazy Top | *Peronosclerospora spp.* |
| `turcicum_leaf_blight` | Turcicum Leaf Blight (TLB) | *Exserohilum turcicum* |
| `charcoal_rot` | Charcoal Rot | *Macrophomina phaseolina* |
| `common_rust` | Common Rust | *Puccinia sorghi* |
| `aspergillus_rot` | Aspergillus Rot | *Aspergillus flavus* |

### 3. Nutrient Deficiencies (8 types × 3 stages = 24 images)

| Folder Name | Nutrient | Key Visual Symptom |
|---|---|---|
| `nitrogen_deficiency` | Nitrogen (N) | V-shaped yellowing on lower leaves |
| `phosphorus_deficiency` | Phosphorus (P) | Purple/reddish discoloration on leaves |
| `potassium_deficiency` | Potassium (K) | Marginal leaf scorch and browning |
| `magnesium_deficiency` | Magnesium (Mg) | Interveinal chlorosis with striping |
| `iron_deficiency` | Iron (Fe) | Interveinal chlorosis on young leaves |
| `sulphur_deficiency` | Sulphur (S) | Uniform yellowing of young leaves |
| `zinc_deficiency` | Zinc (Zn) | White banding (white bud) on leaves |
| `boron_deficiency` | Boron (B) | White spots, distorted leaves |

---

## Stage Descriptions

- **Early:** Initial symptoms barely visible; plant mostly healthy. Useful for training early detection models.
- **Mid:** Moderate symptoms clearly visible; plant showing stress. Represents the typical identification stage.
- **Late:** Severe damage; plant significantly affected. Represents advanced/neglected cases.

---

## Usage Notes

- These are **AI-generated** images intended for dataset augmentation and model pre-training.
- For production ML models, supplement with real field photographs.
- Images are high-resolution PNG files suitable for resizing to standard ML input dimensions.
- The dataset follows a consistent directory structure compatible with common image classification frameworks (e.g., PyTorch ImageFolder, TensorFlow image_dataset_from_directory).

---

## License

This dataset is generated for research and educational purposes.
