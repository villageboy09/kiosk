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
  };

  /// Returns the localized name of a commodity for the given [locale] (e.g. 'te', 'hi', 'en').
  /// If no specific translation exists, falls back to the original English name.
  static String getLocalizedName(String englishName, String locale) {
    if (locale == 'en' || englishName.trim().isEmpty) {
      return englishName;
    }

    final normalized = englishName.trim().toLowerCase();

    // 1. Direct key lookup
    if (_translations.containsKey(normalized)) {
      final locMap = _translations[normalized]!;
      if (locMap.containsKey(locale)) {
        return locMap[locale]!;
      }
    }

    // 2. Partial/fuzzy substring match
    for (final entry in _translations.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        final locMap = entry.value;
        if (locMap.containsKey(locale)) {
          return locMap[locale]!;
        }
      }
    }

    return englishName;
  }
}
