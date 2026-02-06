# Chilli Crop Problem Image Dataset

A comprehensive AI-generated image dataset covering **29 chilli crop problems** across **3 severity stages** (early, mid, late), plus **3 healthy reference images**, totaling **87 photorealistic images**.

## Dataset Overview

| Category | Count | Problems | Images |
|----------|-------|----------|--------|
| Pests | 5 | Fruit Borer, Mite, Aphid, Whitefly, Thrips | 15 |
| Diseases | 12 | Powdery Mildew, Phytophthora Blight, Die Back & Fruit Rot, Wilt & Damping Off, Anthracnose, Yellow Mosaic Virus, Bacterial Leaf Spot, Mosaic Virus, Leaf Curl Virus, Root Knot Nematodes, Wet Rot, Fruit Rot | 36 |
| Nutrient Deficiencies | 11 | N, P, K, Mg, Ca, Fe, Zn, Mn, Mo, B, S | 33 |
| Healthy Reference | 3 | Healthy Plant, Healthy Leaf, Healthy Fruit | 3 |
| **Total** | **31** | | **87** |

## Directory Structure

```
chilli/
├── pest/
│   ├── fruit_borer/          # Helicoverpa armigera, Spodoptera litura
│   │   ├── early/001.png
│   │   ├── mid/001.png
│   │   └── late/001.png
│   ├── mite/                  # Yellow mite / Spider mite
│   ├── aphid/
│   ├── whitefly/
│   └── thrips/
├── disease/
│   ├── powdery_mildew/
│   ├── phytophthora_blight/   # Phytophthora capsici
│   ├── dieback_fruit_rot/
│   ├── wilt_damping_off/
│   ├── anthracnose/           # Colletotrichum piperatum, C. capsici
│   ├── yellow_mosaic_virus/
│   ├── bacterial_leaf_spot/
│   ├── mosaic_virus/          # Chilli mosaic, aphid-transmitted
│   ├── leaf_curl_virus/
│   ├── root_knot_nematode/
│   ├── wet_rot/
│   └── fruit_rot/
├── deficiency/
│   ├── nitrogen_deficiency/
│   ├── phosphorus_deficiency/
│   ├── potassium_deficiency/
│   ├── magnesium_deficiency/
│   ├── calcium_deficiency/    # Blossom-end rot
│   ├── iron_deficiency/
│   ├── zinc_deficiency/
│   ├── manganese_deficiency/
│   ├── molybdenum_deficiency/
│   ├── boron_deficiency/
│   └── sulphur_deficiency/
├── healthy/
│   ├── healthy_plant/
│   ├── healthy_leaf/
│   └── healthy_fruit/
└── README.md
```

## Stage Descriptions

Each problem is documented across three severity stages:

| Stage | Description | Visual Characteristics |
|-------|-------------|----------------------|
| **Early** | Initial onset; subtle symptoms | Faint discoloration, minor spots, slight curling, few pests visible |
| **Mid** | Moderate progression | Distinct lesions, noticeable defoliation, visible colonies, clear chlorosis patterns |
| **Late** | Severe/advanced damage | Extensive necrosis, plant collapse, heavy infestation, severe stunting |

## Detailed Problem Descriptions

### Pests

| Problem | Scientific Name | Key Symptoms |
|---------|----------------|--------------|
| Fruit Borer | *Helicoverpa armigera*, *Spodoptera litura* | Bore holes in fruits, frass, caterpillar larvae, fruit rot |
| Mite | Yellow mite / Spider mite | Stippling, bronzing, webbing, leaf curl, defoliation |
| Aphid | Various species | Colonies on growing tips, leaf curling, honeydew, sooty mold |
| Whitefly | *Bemisia tabaci* | White-winged adults, yellowing, honeydew, sooty mold, virus transmission |
| Thrips | Various species | Silvery streaks, scarring, leaf curl, bronzing, fruit deformation |

### Diseases

| Problem | Causal Agent | Key Symptoms |
|---------|-------------|--------------|
| Powdery Mildew | Fungal | White powdery patches on leaves, yellowing, defoliation |
| Phytophthora Blight | *Phytophthora capsici* | Water-soaked stem lesions, wilting, fruit rot with white mold |
| Die Back & Fruit Rot | Fungal | Branch tip drying, progressive dieback, sunken fruit lesions |
| Wilt & Damping Off | Soil-borne pathogens | Seedling collapse, stem constriction, progressive wilting |
| Anthracnose | *Colletotrichum piperatum*, *C. capsici* | Sunken fruit lesions, salmon-pink spore masses, fruit mummification |
| Yellow Mosaic Virus | Viral | Yellow-green mosaic mottling, leaf distortion, stunting |
| Bacterial Leaf Spot | Bacterial | Angular dark spots with yellow halos, defoliation, fruit scabs |
| Mosaic Virus | Viral (aphid-transmitted) | Light/dark green mosaic, leaf blistering, fruit mottling |
| Leaf Curl Virus | Viral (whitefly-transmitted) | Upward leaf curling, thickening, stunting, bushy appearance |
| Root Knot Nematodes | *Meloidogyne* spp. | Root galls, wilting, yellowing, stunted growth |
| Wet Rot | Fungal/Bacterial | Soft, watery fruit lesions, fungal growth, fruit collapse |
| Fruit Rot | Fungal | Sunken fruit spots, concentric rings, shriveling, mummification |

### Nutrient Deficiencies

| Nutrient | Affected Leaves | Key Visual Symptoms |
|----------|----------------|---------------------|
| Nitrogen (N) | Older/lower | Uniform pale green to yellow chlorosis including veins; stunted growth |
| Phosphorus (P) | Older/lower | Reddish-purple coloration (especially undersides); dark green leaves |
| Potassium (K) | Older/mature | Marginal chlorosis/necrosis (leaf edge scorching); browning |
| Magnesium (Mg) | Older/lower | Interveinal chlorosis (veins stay green); yellow spots/blotches |
| Calcium (Ca) | Fruits primarily | Blossom-end rot (dark, sunken, leathery spots at fruit base) |
| Iron (Fe) | Younger/upper | Interveinal chlorosis on new leaves; yellow to white young leaves |
| Zinc (Zn) | Both old & young | Small, narrow, twisted, deformed leaves; stunted growth |
| Manganese (Mn) | Young leaves | Speckled interveinal chlorosis; necrotic spots |
| Molybdenum (Mo) | Older leaves | Leaf curling, marginal yellowing/necrosis, poor flowering |
| Boron (B) | Growing points | Distorted young leaves, tip necrosis, poor fruit development |
| Sulphur (S) | Youngest/upper | Uniform pale yellow-green starting at shoot tips (top-down) |

## Usage

This dataset is designed for:

- **Machine Learning Training**: Train image classification models for automated crop problem detection
- **Educational Reference**: Visual guide for farmers and agricultural extension workers
- **Research**: Baseline dataset for computer vision research in precision agriculture
- **Mobile App Development**: Reference images for crop diagnostic applications

## Generation Method

All images were generated using AI image generation tools with carefully crafted photorealistic prompts. Each prompt was designed to accurately represent the specific visual symptoms documented in agricultural pathology literature.

## Citation

If using this dataset, please cite:
> CropSync Chilli Problem Dataset, 2026. AI-generated photorealistic images of chilli crop pests, diseases, and nutrient deficiencies.

## License

This dataset is provided for research and educational purposes.
