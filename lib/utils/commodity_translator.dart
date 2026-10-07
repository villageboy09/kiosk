/// Commodity Multi-language Translator for CropSync Market Prices
class CommodityTranslator {
  static const Map<String, Map<String, String>> _translations = {
    // Cereals & Millets
    'paddy': {
      'te': 'వరి (ధాన్యం)',
      'hi': 'धान',
    },
    'paddy(dhan)(common)': {
      'te': 'వరి (సాధారణ ధాన్యం)',
      'hi': 'धान (सामान्य)',
    },
    'paddy(dhan)(basmati)': {
      'te': 'బాస్మతి వరి',
      'hi': 'बासमती धान',
    },
    'rice': {
      'te': 'బియ్యం',
      'hi': 'चावल',
    },
    'wheat': {
      'te': 'గోధుమలు',
      'hi': 'गेहूं',
    },
    'maize': {
      'te': 'మొక్కజొన్న',
      'hi': 'मक्का',
    },
    'jowar(sorghum)': {
      'te': 'జొన్నలు',
      'hi': 'ज्वार',
    },
    'jowar': {
      'te': 'జొన్నలు',
      'hi': 'ज्वार',
    },
    'bajra(pearl millet/cumbu)': {
      'te': 'సజ్జలు',
      'hi': 'बाजरा',
    },
    'bajra': {
      'te': 'సజ్జలు',
      'hi': 'बाजरा',
    },
    'ragi (finger millet)': {
      'te': 'రాగులు',
      'hi': 'रागी',
    },
    'ragi': {
      'te': 'రాగులు',
      'hi': 'रागी',
    },
    'barley (jau)': {
      'te': 'బార్లీ',
      'hi': 'जौ',
    },

    // Pulses & Legumes
    'bengal gram(gram)(whole)': {
      'te': 'శనగలు',
      'hi': 'चना (साबुत)',
    },
    'bengal gram': {
      'te': 'శనగలు',
      'hi': 'चना',
    },
    'gram': {
      'te': 'శనగలు',
      'hi': 'चना',
    },
    'red gram (tur/arhar)': {
      'te': 'కందులు',
      'hi': 'अरहर / तूर',
    },
    'red gram (arhar/tur)': {
      'te': 'కందులు',
      'hi': 'अरहर / तूर',
    },
    'red gram': {
      'te': 'కందులు',
      'hi': 'अरहर',
    },
    'arhar': {
      'te': 'కందులు',
      'hi': 'अरहर',
    },
    'black gram (urd beans)(whole)': {
      'te': 'మినుములు',
      'hi': 'उड़द',
    },
    'black gram': {
      'te': 'మినుములు',
      'hi': 'उड़द',
    },
    'green gram (moong)(whole)': {
      'te': 'పెసలు',
      'hi': 'मूंग',
    },
    'green gram (moong)': {
      'te': 'పెసలు',
      'hi': 'मूंग',
    },
    'green gram': {
      'te': 'పెసలు',
      'hi': 'मूंग',
    },
    'cowpea (lobia/karamani)': {
      'te': 'అలసందలు',
      'hi': 'लोबिया',
    },
    'horse gram': {
      'te': 'ఉలవలు',
      'hi': 'कुलथी',
    },

    // Oilseeds & Commercial
    'cotton': {
      'te': 'పత్తి',
      'hi': 'कपास',
    },
    'groundnut': {
      'te': 'వేరుశనగ',
      'hi': 'मूंगफली',
    },
    'soyabean': {
      'te': 'సోయాబీన్',
      'hi': 'सोयाबीन',
    },
    'soybean': {
      'te': 'సోయాబీన్',
      'hi': 'सोयाबीन',
    },
    'sunflower': {
      'te': 'పొద్దుతిరుగుడు',
      'hi': 'सूरजमुखी',
    },
    'sesamum(sesame,gingelly,til)': {
      'te': 'నువ్వులు',
      'hi': 'तिल',
    },
    'sesamum': {
      'te': 'నువ్వులు',
      'hi': 'तिल',
    },
    'sesame': {
      'te': 'నువ్వులు',
      'hi': 'तिल',
    },
    'mustard': {
      'te': 'ఆవాలు',
      'hi': 'सरसों',
    },
    'castor seed': {
      'te': 'ఆముదం విత్తనాలు',
      'hi': 'अरंडी के बीज',
    },
    'sugarcane': {
      'te': 'చెరకు',
      'hi': 'गन्ना',
    },
    'tobacco': {
      'te': 'పొగాకు',
      'hi': 'तंबाकू',
    },
    'jute': {
      'te': 'జనపనార',
      'hi': 'जूट',
    },

    // Spices
    'chilli red': {
      'te': 'ఎర్ర మిరప',
      'hi': 'लाल मिर्च',
    },
    'green chilli': {
      'te': 'పచ్చి మిర్చి',
      'hi': 'हरी मिर्च',
    },
    'chilli': {
      'te': 'మిర్చి',
      'hi': 'मिर्च',
    },
    'turmeric': {
      'te': 'పసుపు',
      'hi': 'हल्दी',
    },
    'ginger(green)': {
      'te': 'పచ్చి అల్లం',
      'hi': 'अदरक',
    },
    'ginger': {
      'te': 'అల్లం',
      'hi': 'अदरक',
    },
    'garlic': {
      'te': 'వెల్లుల్లి',
      'hi': 'लहसुन',
    },
    'coriander(leaves)': {
      'te': 'కొత్తిమీర',
      'hi': 'धनिया पत्ती',
    },
    'coriander seed': {
      'te': 'ధనియాలు',
      'hi': 'धनिया बीज',
    },
    'cumin seed(jeera)': {
      'te': 'జీలకర్ర',
      'hi': 'जीरा',
    },
    'black pepper': {
      'te': 'నల్ల మిరియాలు',
      'hi': 'काली मिर्च',
    },
    'cardamoms': {
      'te': 'యాలకులు',
      'hi': 'इलायची',
    },

    // Vegetables
    'tomato': {
      'te': 'టమోటా',
      'hi': 'टमाटर',
    },
    'onion': {
      'te': 'ఉల్లిపాయ',
      'hi': 'प्याज',
    },
    'potato': {
      'te': 'బంగాళాదుంప',
      'hi': 'आलू',
    },
    'brinjal': {
      'te': 'వంకాయ',
      'hi': 'बैंगन',
    },
    'cabbage': {
      'te': 'క్యాబేజీ',
      'hi': 'पत्तागोभी',
    },
    'cauliflower': {
      'te': 'కాలీఫ్లవర్',
      'hi': 'फूलगोभी',
    },
    'lady\'s finger': {
      'te': 'బెండకాయ',
      'hi': 'भिंडी',
    },
    'bhindi(ladies finger)': {
      'te': 'బెండకాయ',
      'hi': 'भिंडी',
    },
    'bitter gourd': {
      'te': 'కాకరకాయ',
      'hi': 'करेला',
    },
    'bottle gourd': {
      'te': 'సొరకాయ',
      'hi': 'लौकी',
    },
    'ridgeguard(tori)': {
      'te': 'బీరకాయ',
      'hi': 'तोरई',
    },
    'capsicum': {
      'te': 'క్యాప్సికమ్',
      'hi': 'शिमला मिर्च',
    },
    'carrot': {
      'te': 'క్యారెట్',
      'hi': 'गाजर',
    },
    'radish': {
      'te': 'ముల్లంగి',
      'hi': 'मूली',
    },
    'drumstick': {
      'te': 'మునగకాయ',
      'hi': 'सहजन',
    },
    'cucumber': {
      'te': 'దోసకాయ',
      'hi': 'खीरा',
    },

    // Fruits & Plantation
    'banana': {
      'te': 'అరటి',
      'hi': 'केला',
    },
    'mango': {
      'te': 'మామిడి',
      'hi': 'आम',
    },
    'papaya': {
      'te': 'బొప్పాయి',
      'hi': 'पपीता',
    },
    'lemon': {
      'te': 'నిమ్మకాయ',
      'hi': 'नींबू',
    },
    'sweet orange(mosambi)': {
      'te': 'బత్తాయి',
      'hi': 'मौसमी',
    },
    'pomegranate': {
      'te': 'దానిమ్మ',
      'hi': 'अनार',
    },
    'guava': {
      'te': 'జామకాయ',
      'hi': 'अमरूद',
    },
    'water melon': {
      'te': 'పుచ్చకాయ',
      'hi': 'तरबूज',
    },
    'apple': {
      'te': 'ఆపిల్',
      'hi': 'सेब',
    },
    'coconut': {
      'te': 'కొబ్బరికాయ',
      'hi': 'नारियल',
    },
    'cashewnuts': {
      'te': 'జీడిపప్పు',
      'hi': 'काजू',
    },
    'coffee': {
      'te': 'కాఫీ',
      'hi': 'कॉफ़ी',
    },
    'tea': {
      'te': 'టీ',
      'hi': 'चाय',
    },
    'rubber': {
      'te': 'రబ్బరు',
      'hi': 'रबर',
    },
    'avocado': {
      'te': 'వెన్నపండు (అవకాడో)',
      'hi': 'एवोकैडो',
    },
    'beetroot': {
      'te': 'బీట్‌రూట్',
      'hi': 'चुकंदर',
    },
    'orange': {
      'te': 'నారింజ',
      'hi': 'संतरा',
    },
    'grapes': {
      'te': 'ద్రాక్ష',
      'hi': 'अंगूर',
    },
    'watermelon': {
      'te': 'పుచ్చకాయ',
      'hi': 'तरबूज',
    },
  };

  /// Returns the localized name of a commodity for the given [locale] (e.g. 'te', 'hi', 'en').
  /// If no specific translation exists, falls back to the original English name.
  static String getLocalizedName(String englishName, String locale) {
    if (englishName.trim().isEmpty) {
      return englishName;
    }

    final normalized = englishName.trim().toLowerCase();

    // 1. Direct key lookup
    if (_translations.containsKey(normalized)) {
      if (locale == 'en') {
        return englishName;
      }
      final locMap = _translations[normalized]!;
      if (locMap.containsKey(locale)) {
        return locMap[locale]!;
      }
    }

    // 2. Partial/fuzzy substring match on English keys
    for (final entry in _translations.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        if (locale == 'en') {
          return englishName;
        }
        final locMap = entry.value;
        if (locMap.containsKey(locale)) {
          return locMap[locale]!;
        }
      }
    }

    // 3. Reverse lookup: if name is already in Telugu or Hindi, translate to requested locale
    for (final entry in _translations.entries) {
      final locMap = entry.value;
      for (final lKey in locMap.keys) {
        final val = locMap[lKey]!.trim().toLowerCase();
        if (normalized == val || normalized.contains(val) || val.contains(normalized)) {
          if (locale == 'en') {
            final words = entry.key.split(' ');
            return words.map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
          }
          if (locMap.containsKey(locale)) {
            return locMap[locale]!;
          }
        }
      }
    }

    return englishName;
  }

  /// Resolves an optimized, high-fidelity transparent image URL for a given commodity name.
  static String resolveImageUrl(String commodity, {String? explicitUrl}) {
    if (explicitUrl != null && explicitUrl.trim().isNotEmpty) {
      return explicitUrl.trim();
    }
    if (commodity.trim().isEmpty) return '';

    String normalized = commodity.trim().toLowerCase();

    // 1. If commodity name is in Telugu or Hindi, reverse-lookup to English key
    for (final entry in _translations.entries) {
      final locMap = entry.value;
      for (final lKey in locMap.keys) {
        final val = locMap[lKey]!.trim().toLowerCase();
        if (normalized == val || normalized.contains(val)) {
          normalized = entry.key.toLowerCase();
          break;
        }
      }
    }

    // 2. Strip parenthetical qualifiers: e.g. "Bhindi(Ladies Finger)" -> "Bhindi"
    final stripped = normalized.replaceAll(RegExp(r'\(.*?\)'), ' ').trim();
    final lower = '$normalized $stripped';

    // 3. Priority Exact & Substring Matching for confirmed server image assets

    // Paddy, Dhan, Rice
    if (lower.contains('paddy') || lower.contains('rice') || lower.contains('dhan')) {
      return 'https://kiosk.cropsync.in/api/commodity/Rice.png';
    }

    // Bhindi, Ladies Finger, Okra
    if (lower.contains('bhindi') ||
        lower.contains('ladies finger') ||
        lower.contains("lady's finger") ||
        lower.contains('lady finger') ||
        lower.contains('lady') ||
        lower.contains('okra') ||
        lower.contains('bhendi') ||
        lower.contains('bendakaya')) {
      return 'https://kiosk.cropsync.in/crops/okra.jpg';
    }

    // Chilli, Chili, Mirchi
    if (lower.contains('chilli') ||
        lower.contains('chili') ||
        lower.contains('mirchi')) {
      return 'https://kiosk.cropsync.in/crops/chilli.jpg';
    }

    // Bitter Gourd, Karela
    if (lower.contains('bitter gourd') || lower.contains('karela') || lower.contains('kakarakaya')) {
      return 'https://kiosk.cropsync.in/crops/bitter_gourd.jpg';
    }

    // Other Gourds (Ridge Gourd, Bottle Gourd, Little Gourd / Kundru / Tori)
    if (lower.contains('ridgeguard') ||
        lower.contains('ridge gourd') ||
        lower.contains('tori') ||
        lower.contains('bottle gourd') ||
        lower.contains('lauki') ||
        lower.contains('little gourd') ||
        lower.contains('kundru') ||
        lower.contains('gourd')) {
      return 'https://kiosk.cropsync.in/crops/bitter_gourd.jpg';
    }

    // Cotton, Kapas
    if (lower.contains('cotton') || lower.contains('kapas') || lower.contains('patti')) {
      return 'https://kiosk.cropsync.in/api/commodity/Cotton.png';
    }

    // Tomato
    if (lower.contains('tomato') || lower.contains('tamata')) {
      return 'https://kiosk.cropsync.in/api/commodity/Tomato.png';
    }

    // Onion
    if (lower.contains('onion') || lower.contains('pyaj') || lower.contains('ullipaya')) {
      return 'https://kiosk.cropsync.in/api/commodity/Onion.png';
    }

    // Potato
    if (lower.contains('potato') || lower.contains('aloo') || lower.contains('bangaladumpa')) {
      return 'https://kiosk.cropsync.in/api/commodity/Potato.png';
    }

    // Maize, Corn, Sorghum, Jowar
    if (lower.contains('maize') ||
        lower.contains('corn') ||
        lower.contains('jowar') ||
        lower.contains('sorghum') ||
        lower.contains('makka')) {
      return 'https://kiosk.cropsync.in/api/commodity/Maize.png';
    }

    // Wheat, Bajra, Ragi, Barley
    if (lower.contains('wheat') ||
        lower.contains('gehun') ||
        lower.contains('bajra') ||
        lower.contains('ragi') ||
        lower.contains('barley') ||
        lower.contains('millet')) {
      return 'https://kiosk.cropsync.in/api/commodity/Wheat.png';
    }

    // Groundnut, Peanut
    if (lower.contains('groundnut') || lower.contains('peanut') || lower.contains('verusanaga')) {
      return 'https://kiosk.cropsync.in/api/commodity/Groundnut.png';
    }

    // Turmeric, Haldi (checked before 'tur' pulse to prevent substring collision)
    if (lower.contains('turmeric') || lower.contains('haldi') || lower.contains('pasupu')) {
      return 'https://kiosk.cropsync.in/api/commodity/Turmeric.png';
    }

    // Pulses & Legumes: Bengal Gram, Red Gram (Arhar/Tur), Green Gram (Moong), Black Gram (Urd), Soyabean, Cowpea
    if (lower.contains('soya') ||
        lower.contains('soybean') ||
        lower.contains('gram') ||
        lower.contains('chana') ||
        lower.contains('arhar') ||
        RegExp(r'\btur\b').hasMatch(lower) ||
        lower.contains('moong') ||
        lower.contains('urd') ||
        lower.contains('bean') ||
        lower.contains('pulse') ||
        lower.contains('lobia') ||
        lower.contains('horse gram')) {
      return 'https://kiosk.cropsync.in/api/commodity/Soyabean.png';
    }

    // Brinjal, Eggplant
    if (lower.contains('brinjal') || lower.contains('eggplant') || lower.contains('baingan') || lower.contains('vankaya')) {
      return 'https://kiosk.cropsync.in/api/commodity/Brinjal.png';
    }

    // Cabbage
    if (lower.contains('cabbage')) {
      return 'https://kiosk.cropsync.in/api/commodity/Cabbage.png';
    }

    // Cauliflower
    if (lower.contains('cauliflower')) {
      return 'https://kiosk.cropsync.in/api/commodity/Cauliflower.png';
    }

    // Carrot
    if (lower.contains('carrot') || lower.contains('gajar')) {
      return 'https://kiosk.cropsync.in/api/commodity/Carrot.png';
    }

    // Capsicum
    if (lower.contains('capsicum') || lower.contains('bell pepper')) {
      return 'https://kiosk.cropsync.in/api/commodity/Capsicum.png';
    }

    // Banana
    if (lower.contains('banana') || lower.contains('kela') || lower.contains('arati')) {
      return 'https://kiosk.cropsync.in/api/commodity/Banana.png';
    }

    // Mango
    if (lower.contains('mango') || lower.contains('aam') || lower.contains('mamidi')) {
      return 'https://kiosk.cropsync.in/api/commodity/Mango.png';
    }

    // Apple
    if (lower.contains('apple') || lower.contains('seb')) {
      return 'https://kiosk.cropsync.in/api/commodity/Apple.png';
    }

    // Orange
    if (lower.contains('orange') || lower.contains('santra')) {
      return 'https://kiosk.cropsync.in/api/commodity/Orange.png';
    }

    // Lime, Lemon, Mousambi, Sweet Lime
    if (lower.contains('mousambi') ||
        lower.contains('sweet lime') ||
        lower.contains('mosambi') ||
        lower.contains('lime') ||
        lower.contains('battayi')) {
      return 'https://kiosk.cropsync.in/api/commodity/Lime.png';
    }
    if (lower.contains('lemon') || lower.contains('nimbu') || lower.contains('nimmakaya')) {
      return 'https://kiosk.cropsync.in/api/commodity/Lemon.png';
    }

    // Papaya
    if (lower.contains('papaya') || lower.contains('papita') || lower.contains('boppayi')) {
      return 'https://kiosk.cropsync.in/api/commodity/Papaya.png';
    }

    // Pomegranate
    if (lower.contains('pomegranate') || lower.contains('anar') || lower.contains('danimma')) {
      return 'https://kiosk.cropsync.in/api/commodity/Pomegranate.png';
    }

    // Guava
    if (lower.contains('guava') || lower.contains('amrud') || lower.contains('jamakaya')) {
      return 'https://kiosk.cropsync.in/api/commodity/Guava.png';
    }

    // Grapes
    if (lower.contains('grapes') || lower.contains('grape') || lower.contains('angoor') || lower.contains('draksha')) {
      return 'https://kiosk.cropsync.in/api/commodity/Grapes.png';
    }

    // Pineapple
    if (lower.contains('pineapple') || lower.contains('ananas')) {
      return 'https://kiosk.cropsync.in/api/commodity/Pineapple.png';
    }

    // Drumstick
    if (lower.contains('drumstick') || lower.contains('sahjan') || lower.contains('moringa') || lower.contains('munagakaya')) {
      return 'https://kiosk.cropsync.in/api/commodity/Drumstick.png';
    }

    // Garlic, Ginger
    if (lower.contains('garlic') ||
        lower.contains('ginger') ||
        lower.contains('adrak') ||
        lower.contains('lahsun') ||
        lower.contains('allam') ||
        lower.contains('vellulli')) {
      return 'https://kiosk.cropsync.in/api/commodity/Garlic.png';
    }

    // Beetroot
    if (lower.contains('beetroot') || lower.contains('chukandar')) {
      return 'https://kiosk.cropsync.in/api/commodity/Beetroot.png';
    }

    // Avocado
    if (lower.contains('avocado')) {
      return 'https://kiosk.cropsync.in/api/commodity/Avocado.png';
    }

    // Pumpkin, Melons
    if (lower.contains('pumpkin') ||
        lower.contains('watermelon') ||
        lower.contains('water melon') ||
        lower.contains('tarbooj') ||
        lower.contains('melon') ||
        lower.contains('kaddu') ||
        lower.contains('gummadikaya')) {
      return 'https://kiosk.cropsync.in/api/commodity/Pumpkin.png';
    }

    // Spinach, Coriander, Greens
    if (lower.contains('spinach') ||
        lower.contains('coriander') ||
        lower.contains('dhaniya') ||
        lower.contains('kothimeera') ||
        lower.contains('palak') ||
        lower.contains('leaves')) {
      return 'https://kiosk.cropsync.in/api/commodity/Spinach.png';
    }

    // Mustard, Sarson
    if (lower.contains('mustard') || lower.contains('sarson') || lower.contains('aavalu')) {
      return 'https://kiosk.cropsync.in/api/commodity/Mustard.png';
    }

    // Linseed, Sesamum, Sesame, Til
    if (lower.contains('linseed') ||
        lower.contains('sesamum') ||
        lower.contains('sesame') ||
        lower.contains('til') ||
        lower.contains('nuvvulu') ||
        lower.contains('alsi')) {
      return 'https://kiosk.cropsync.in/api/commodity/Linseed.png';
    }

    // Safflower
    if (lower.contains('safflower') || lower.contains('kusuma') || lower.contains('kusum')) {
      return 'https://kiosk.cropsync.in/api/commodity/Safflower.png';
    }

    // Tobacco
    if (lower.contains('tobacco') || lower.contains('tambaku') || lower.contains('pogaku')) {
      return 'https://kiosk.cropsync.in/api/commodity/Tobacco.png';
    }

    // Sugarcane, Gur, Jaggery
    if (lower.contains('sugarcane') ||
        lower.contains('jaggery') ||
        lower.contains('gur') ||
        lower.contains('ganna') ||
        lower.contains('cheraku') ||
        lower.contains('bellam')) {
      return 'https://kiosk.cropsync.in/crops/sugarcane.jpg';
    }

    // Sunflower
    if (lower.contains('sunflower') || lower.contains('surajmukhi')) {
      return 'https://kiosk.cropsync.in/crops/sunflower.jpg';
    }

    // Cumin, Jeera
    if (lower.contains('cumin') || lower.contains('jeera') || lower.contains('jeelakarra')) {
      return 'https://kiosk.cropsync.in/crops/cumin.jpg';
    }

    // Tea
    if (lower.contains('tea') || lower.contains('chai')) {
      return 'https://kiosk.cropsync.in/crops/tea.jpg';
    }

    // Wood
    if (lower.contains('wood') || lower.contains('timber')) {
      return 'https://kiosk.cropsync.in/api/commodity/Wood.png';
    }

    // Fish
    if (lower.contains('fish') || lower.contains('chepa')) {
      return 'https://kiosk.cropsync.in/api/commodity/Fish.png';
    }

    // Litchi, Peach, Plum
    if (lower.contains('litchi') || lower.contains('lychee')) return 'https://kiosk.cropsync.in/api/commodity/Litchi.png';
    if (lower.contains('peach')) return 'https://kiosk.cropsync.in/api/commodity/Peach.png';
    if (lower.contains('plum')) return 'https://kiosk.cropsync.in/api/commodity/Plum.png';

    // 4. Fallback to clean PascalCase directly in server's api/commodity/ folder
    final clean = stripped.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    final words = clean.split(RegExp(r'\s+'));
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join('');

    if (capitalized.isNotEmpty) {
      return 'https://kiosk.cropsync.in/api/commodity/$capitalized.png';
    }

    return 'https://kiosk.cropsync.in/assets/images/logo.png';
  }

  /// Classifies a commodity into category keys: 'all', 'fruits', 'vegetables', 'cereals', 'cash_crops'
  static String getCategory(String commodity) {
    final lower = commodity.toLowerCase();

    if (lower.contains('apple') ||
        lower.contains('avocado') ||
        lower.contains('banana') ||
        lower.contains('mango') ||
        lower.contains('orange') ||
        lower.contains('guava') ||
        lower.contains('papaya') ||
        lower.contains('watermelon') ||
        lower.contains('grapes') ||
        lower.contains('pomegranate') ||
        lower.contains('lemon') ||
        lower.contains('sweet lime') ||
        lower.contains('sapota') ||
        lower.contains('custard apple')) {
      return 'fruits';
    }

    if (lower.contains('tomato') ||
        lower.contains('onion') ||
        lower.contains('potato') ||
        lower.contains('beetroot') ||
        lower.contains('carrot') ||
        lower.contains('brinjal') ||
        lower.contains('cabbage') ||
        lower.contains('cauliflower') ||
        lower.contains('ladies finger') ||
        lower.contains('bhindi') ||
        lower.contains('garlic') ||
        lower.contains('ginger') ||
        lower.contains('capsicum') ||
        lower.contains('cucumber') ||
        lower.contains('radish')) {
      return 'vegetables';
    }

    if (lower.contains('paddy') ||
        lower.contains('rice') ||
        lower.contains('wheat') ||
        lower.contains('maize') ||
        lower.contains('jowar') ||
        lower.contains('bajra') ||
        lower.contains('ragi') ||
        lower.contains('gram') ||
        lower.contains('moong') ||
        lower.contains('tur') ||
        lower.contains('arhar') ||
        lower.contains('urd') ||
        lower.contains('soyabean') ||
        lower.contains('barley')) {
      return 'cereals';
    }

    return 'cash_crops';
  }
}

