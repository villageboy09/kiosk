// Client-side normalisation of Indian state / district names, mirroring the
// server so that GPS, profile and market-data spellings can be compared.

const Map<String, String> _stateAliases = {
  'orissa': 'Odisha',
  'odisha': 'Odisha',
  'telangana': 'Telangana',
  'telengana': 'Telangana',
  'telangan': 'Telangana',
  'telagana': 'Telangana',
  'andhra pradesh': 'Andhra Pradesh',
  'andhrapradesh': 'Andhra Pradesh',
  'andhra': 'Andhra Pradesh',
  'nct of delhi': 'Delhi',
  'national capital territory of delhi': 'Delhi',
  'delhi': 'Delhi',
  'new delhi': 'Delhi',
  'uttaranchal': 'Uttarakhand',
  'uttarakhand': 'Uttarakhand',
  'pondicherry': 'Puducherry',
  'puducherry': 'Puducherry',
  'karnataka': 'Karnataka',
  'tamil nadu': 'Tamil Nadu',
  'tamilnadu': 'Tamil Nadu',
  'kerala': 'Kerala',
  'maharashtra': 'Maharashtra',
  'madhya pradesh': 'Madhya Pradesh',
  'uttar pradesh': 'Uttar Pradesh',
  'chhattisgarh': 'Chhattisgarh',
  'chattisgarh': 'Chhattisgarh',
  'gujarat': 'Gujarat',
  'rajasthan': 'Rajasthan',
  'punjab': 'Punjab',
  'haryana': 'Haryana',
  'bihar': 'Bihar',
  'jharkhand': 'Jharkhand',
  'west bengal': 'West Bengal',
  'assam': 'Assam',
  'himachal pradesh': 'Himachal Pradesh',
  'jammu and kashmir': 'Jammu and Kashmir',
  'jammu & kashmir': 'Jammu and Kashmir',
  'goa': 'Goa',
  // Telugu script
  'తెలంగాణ': 'Telangana',
  'ఆంధ్ర ప్రదేశ్': 'Andhra Pradesh',
  'ఆంధ్రప్రదేశ్': 'Andhra Pradesh',
  'కర్ణాటక': 'Karnataka',
  'తమిళనాడు': 'Tamil Nadu',
  'మహారాష్ట్ర': 'Maharashtra',
  'ఒడిశా': 'Odisha',
  // Hindi script
  'तेलंगाना': 'Telangana',
  'आंध्र प्रदेश': 'Andhra Pradesh',
  'आन्ध्र प्रदेश': 'Andhra Pradesh',
  'कर्नाटक': 'Karnataka',
  'तमिलनाडु': 'Tamil Nadu',
  'महाराष्ट्र': 'Maharashtra',
  'मध्य प्रदेश': 'Madhya Pradesh',
  'उत्तर प्रदेश': 'Uttar Pradesh',
  'राजस्थान': 'Rajasthan',
  'गुजरात': 'Gujarat',
  'पंजाब': 'Punjab',
  'हरियाणा': 'Haryana',
  'बिहार': 'Bihar',
  'ओडिशा': 'Odisha',
  'उड़ीसा': 'Odisha',
  'केरल': 'Kerala',
  'दिल्ली': 'Delhi',
  'छत्तीसगढ़': 'Chhattisgarh',
};

String _squash(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Canonical English state / UT name -> alternate spellings (Telugu, Hindi and
/// extra English). Every one of the 36 states / UTs appears here so a Telugu
/// or Hindi geocoder answer still maps to the canonical English name.
const Map<String, List<String>> _stateTable = {
  'Andhra Pradesh': ['ఆంధ్రప్రదేశ్', 'ఆంధ్ర ప్రదేశ్', 'आंध्र प्रदेश'],
  'Arunachal Pradesh': ['arunachal', 'అరుణాచల్ ప్రదేశ్', 'अरुणाचल प्रदेश'],
  'Assam': ['అస్సాం', 'असम'],
  'Bihar': ['బీహార్', 'बिहार'],
  'Chhattisgarh': ['ఛత్తీస్‌గఢ్', 'ఛత్తీస్గఢ్', 'छत्तीसगढ़', 'छत्तीसगढ'],
  'Goa': ['గోవా', 'गोवा'],
  'Gujarat': ['గుజరాత్', 'गुजरात'],
  'Haryana': ['హర్యానా', 'हरियाणा'],
  'Himachal Pradesh': ['హిమాచల్ ప్రదేశ్', 'हिमाचल प्रदेश'],
  'Jharkhand': ['జార్ఖండ్', 'झारखंड', 'झारखण्ड'],
  'Karnataka': ['కర్ణాటక', 'कर्नाटक'],
  'Kerala': ['కేరళ', 'केरल'],
  'Madhya Pradesh': ['మధ్య ప్రదేశ్', 'మధ్యప్రదేశ్', 'मध्य प्रदेश'],
  'Maharashtra': ['మహారాష్ట్ర', 'महाराष्ट्र'],
  'Manipur': ['మణిపూర్', 'मणिपुर'],
  'Meghalaya': ['మేఘాలయ', 'मेघालय'],
  'Mizoram': ['మిజోరాం', 'मिजोरम'],
  'Nagaland': ['నాగాలాండ్', 'नागालैंड'],
  'Odisha': ['ఒడిశా', 'ఒడిషా', 'ओडिशा', 'उड़ीसा'],
  'Punjab': ['పంజాబ్', 'पंजाब'],
  'Rajasthan': ['రాజస్థాన్', 'राजस्थान'],
  'Sikkim': ['సిక్కిం', 'सिक्किम'],
  'Tamil Nadu': ['తమిళనాడు', 'तमिलनाडु'],
  'Telangana': ['తెలంగాణ', 'తెలంగాణా', 'तेलंगाना'],
  'Tripura': ['త్రిపుర', 'त्रिपुरा'],
  'Uttar Pradesh': ['ఉత్తర ప్రదేశ్', 'ఉత్తరప్రదేశ్', 'उत्तर प्रदेश'],
  'Uttarakhand': ['ఉత్తరాఖండ్', 'उत्तराखंड', 'उत्तराखण्ड'],
  'West Bengal': ['పశ్చిమ బెంగాల్', 'पश्चिम बंगाल'],
  'Andaman and Nicobar Islands': [
    'andaman & nicobar islands',
    'andaman and nicobar',
    'అండమాన్ మరియు నికోబార్ దీవులు',
    'अंडमान और निकोबार द्वीप समूह',
  ],
  'Chandigarh': ['చండీగఢ్', 'चंडीगढ़', 'चण्डीगढ़'],
  'Dadra and Nagar Haveli and Daman and Diu': [
    'dadra and nagar haveli',
    'daman and diu',
    'దాద్రా నగర్ హవేలీ మరియు డామన్ డయ్యూ',
    'दादरा और नगर हवेली और दमन और दीव',
  ],
  'Delhi': ['ఢిల్లీ', 'दिल्ली'],
  'Jammu and Kashmir': ['జమ్మూ కాశ్మీర్', 'जम्मू और कश्मीर', 'जम्मू कश्मीर'],
  'Ladakh': ['లడఖ్', 'लद्दाख'],
  'Lakshadweep': ['లక్షద్వీప్', 'लक्षद्वीप'],
  'Puducherry': ['పుదుచ్చేరి', 'पुदुच्चेरी', 'पांडिचेरी'],
};

String _stateKey(String raw) => _squash(raw
    .toLowerCase()
    .replaceAll(RegExp(r'[‌‍]'), '')
    .replaceAll(RegExp(r'[.,()]'), '')
    .replaceAll('&', 'and')
    .replaceAll(RegExp(r'[‐-―]'), '-'));

final Map<String, String> _allStateAliases = () {
  final m = <String, String>{};
  _stateAliases.forEach((k, v) => m[_stateKey(k)] = v);
  _stateTable.forEach((canon, alts) {
    m[_stateKey(canon)] = canon;
    for (final a in alts) {
      m[_stateKey(a)] = canon;
    }
  });
  return m;
}();

/// The 36 canonical state / UT names (plus anything in the legacy table).
final Set<String> _knownStates = {
  ..._allStateAliases.values,
};

/// Returns the canonical English state name, or the trimmed (title-cased)
/// input if it is not a known alias. Empty input returns ''.
String canonicalState(String raw) {
  final t = _squash(raw);
  if (t.isEmpty) return '';
  final hit = _allStateAliases[_stateKey(t)] ??
      _allStateAliases[_stateKey(
          t.replaceAll(RegExp(r'\s+state$', caseSensitive: false), ''))];
  if (hit != null) return hit;
  // Unknown: title-case Latin words, leave other scripts alone.
  return t
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : (RegExp(r'^[A-Za-z]').hasMatch(w)
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : w))
      .join(' ');
}

/// Canonical district spellings: every alias maps to one key.
const Map<String, String> _districtAliases = {
  'chittor': 'chittoor',
  'chitoor': 'chittoor',
  'rangareddy': 'rangareddy',
  'ranga reddy': 'rangareddy',
  'rangareddi': 'rangareddy',
  'ranga reddi': 'rangareddy',
  'r r district': 'rangareddy',
  'medchal malkajgiri': 'medchalmalkajgiri',
  'medchal': 'medchalmalkajgiri',
  'medchalmalkajgiri': 'medchalmalkajgiri',
  'warangal urban': 'hanumakonda',
  'hanamkonda': 'hanumakonda',
  'hanumakonda': 'hanumakonda',
  'warangal rural': 'warangal',
  'tirupathi': 'tirupati',
  'tirupati': 'tirupati',
  'visakhapatnam': 'visakhapatnam',
  'vizag': 'visakhapatnam',
  'vishakhapatnam': 'visakhapatnam',
  'visakhapattanam': 'visakhapatnam',
  'mahabubnagar': 'mahabubnagar',
  'mahbubnagar': 'mahabubnagar',
  'mahaboobnagar': 'mahabubnagar',
  'mahabub nagar': 'mahabubnagar',
  'mehaboobnagar': 'mahabubnagar',
  'karim nagar': 'karimnagar',
  'nizambad': 'nizamabad',
  'adilabad': 'adilabad',
  'ananthapur': 'anantapur',
  'ananthapuramu': 'anantapur',
  'anantapuramu': 'anantapur',
  'anantapur': 'anantapur',
  'kadapa': 'kadapa',
  'cuddapah': 'kadapa',
  'ysr kadapa': 'kadapa',
  'ysr': 'kadapa',
  'east godavari': 'eastgodavari',
  'west godavari': 'westgodavari',
  'sri potti sriramulu nellore': 'nellore',
  'spsr nellore': 'nellore',
  'nellore': 'nellore',
  'prakasam': 'prakasam',
  'bhadradri kothagudem': 'bhadradrikothagudem',
  'kothagudem': 'bhadradrikothagudem',
  'jayashankar bhupalpally': 'jayashankarbhupalpally',
  'jogulamba gadwal': 'jogulambagadwal',
  'gadwal': 'jogulambagadwal',
  'yadadri bhuvanagiri': 'yadadribhuvanagiri',
  'yadadri': 'yadadribhuvanagiri',
  'bhongir': 'yadadribhuvanagiri',
  'hyderabad': 'hyderabad',
  'secunderabad': 'hyderabad',
  'greater hyderabad': 'hyderabad',
  'bengaluru': 'bengaluru',
  'bangalore': 'bengaluru',
  'bengaluru urban': 'bengaluru',
  'bangalore urban': 'bengaluru',
};

/// Telugu spellings of the 33 Telangana and 26 AP districts (English name ->
/// Telugu variants). Folded into the alias lookup by [_scriptDistrictAliases].
const Map<String, List<String>> _teDistricts = {
  'adilabad': ['ఆదిలాబాద్'],
  'bhadradri kothagudem': ['భద్రాద్రి కొత్తగూడెం', 'కొత్తగూడెం'],
  'hyderabad': ['హైదరాబాద్', 'సికింద్రాబాద్'],
  'jagtial': ['జగిత్యాల'],
  'jangaon': ['జనగాం', 'జనగామ'],
  'jayashankar bhupalpally': ['జయశంకర్ భూపాలపల్లి'],
  'jogulamba gadwal': ['జోగులాంబ గద్వాల', 'గద్వాల'],
  'kamareddy': ['కామారెడ్డి'],
  'karimnagar': ['కరీంనగర్'],
  'khammam': ['ఖమ్మం'],
  'komaram bheem asifabad': ['కొమరం భీమ్ ఆసిఫాబాద్', 'ఆసిఫాబాద్'],
  'mahabubabad': ['మహబూబాబాద్'],
  'mahabubnagar': ['మహబూబ్ నగర్', 'మహబూబ్నగర్'],
  'mancherial': ['మంచిర్యాల'],
  'medak': ['మెదక్'],
  'medchal malkajgiri': [
    'మేడ్చల్ మల్కాజిగిరి',
    'మేడ్చల్ మల్కాజ్గిరి',
    'మేడ్చల్',
  ],
  'mulugu': ['ములుగు'],
  'nagarkurnool': ['నాగర్ కర్నూల్', 'నాగర్కర్నూల్'],
  'nalgonda': ['నల్గొండ'],
  'narayanpet': ['నారాయణపేట'],
  'nirmal': ['నిర్మల్'],
  'nizamabad': ['నిజామాబాద్'],
  'peddapalli': ['పెద్దపల్లి'],
  'rajanna sircilla': ['రాజన్న సిరిసిల్ల'],
  'rangareddy': ['రంగారెడ్డి'],
  'sangareddy': ['సంగారెడ్డి'],
  'siddipet': ['సిద్దిపేట'],
  'suryapet': ['సూర్యాపేట'],
  'vikarabad': ['వికారాబాద్'],
  'wanaparthy': ['వనపర్తి'],
  'warangal': ['వరంగల్'],
  'hanumakonda': ['హనుమకొండ'],
  'yadadri bhuvanagiri': ['యాదాద్రి భువనగిరి'],
  'alluri sitharama raju': ['అల్లూరి సీతారామరాజు'],
  'anakapalli': ['అనకాపల్లి'],
  'anantapur': ['అనంతపురం'],
  'annamayya': ['అన్నమయ్య'],
  'bapatla': ['బాపట్ల'],
  'chittoor': ['చిత్తూరు'],
  'konaseema': ['కోనసీమ', 'డా. బి.ఆర్. అంబేద్కర్ కోనసీమ'],
  'east godavari': ['తూర్పు గోదావరి'],
  'eluru': ['ఏలూరు'],
  'guntur': ['గుంటూరు'],
  'kakinada': ['కాకినాడ'],
  'krishna': ['కృష్ణా', 'కృష్ణ'],
  'kurnool': ['కర్నూలు', 'కర్నూల్'],
  'nandyal': ['నంద్యాల'],
  'ntr': ['ఎన్టీఆర్'],
  'palnadu': ['పల్నాడు'],
  'parvathipuram manyam': ['పార్వతీపురం మన్యం'],
  'prakasam': ['ప్రకాశం'],
  'nellore': ['నెల్లూరు'],
  'sri sathya sai': ['శ్రీ సత్యసాయి'],
  'srikakulam': ['శ్రీకాకుళం'],
  'tirupati': ['తిరుపతి'],
  'visakhapatnam': ['విశాఖపట్నం'],
  'vizianagaram': ['విజయనగరం'],
  'west godavari': ['పశ్చిమ గోదావరి'],
  'kadapa': ['కడప', 'వైఎస్ఆర్ కడప'],
  // A few Hindi spellings (names the Hindi geocoder commonly returns).
  'bengaluru': ['बेंगलुरु', 'बैंगलोर', 'ಬೆಂಗಳೂರು'],
};

String _dropJoiners(String s) => s.replaceAll(RegExp(r'[‌‍]'), '');

/// Script (Telugu / Hindi / Kannada) spelling, spaces removed -> alias key.
final Map<String, String> _scriptDistrictAliases = () {
  final m = <String, String>{};
  _teDistricts.forEach((en, alts) {
    final key = _districtAliases[en] ?? en.replaceAll(' ', '');
    for (final a in alts) {
      m[_dropJoiners(a).toLowerCase().replaceAll(RegExp(r'[\s.]+'), '')] = key;
    }
  });
  return m;
}();

final Map<String, String> _scriptToEnglish = () {
  final m = <String, String>{};
  _teDistricts.forEach((en, alts) {
    final title = en
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    for (final a in alts) {
      m[_dropJoiners(a).toLowerCase().replaceAll(RegExp(r'[\s.]+'), '')] =
          title;
    }
  });
  return m;
}();

/// English display name for a district written in Telugu (or another script
/// in the table); any other input is returned trimmed and unchanged.
String englishDistrictName(String raw) {
  final base = _stripSuffix(raw);
  final hit = _scriptToEnglish[base.replaceAll(RegExp(r'[\s.]+'), '')];
  return hit ?? raw.trim();
}

String _stripSuffix(String s) {
  var out = _dropJoiners(s).toLowerCase();
  // en dash / em dash / minus -> hyphen, then every separator -> space.
  out = out.replaceAll(RegExp(r'[‐-―−]'), '-');
  out = out.replaceAll(RegExp(r'[.,()\-_/]'), ' ');
  out = out.replaceAll('&', ' and ');
  out = _squash(out);
  out = out.replaceAll(
      RegExp(
          r'\s+(district|dist|dt|zilla|taluk|mandal|జిల్లా|जिला|ज़िला|जिले)$'),
      '');
  // Telugu writes the suffix attached too ("రంగారెడ్డిజిల్లా").
  out = out.replaceAll(RegExp(r'(జిల్లా|जिला)$'), '');
  out = out.replaceAll(RegExp(r'^(district|dist)\s+'), '');
  return _squash(out);
}

/// Normalised comparison key for a district name (aliases collapsed).
String normalizeDistrictKey(String raw) {
  final base = _stripSuffix(raw);
  if (base.isEmpty) return '';
  final hit = _districtAliases[base];
  if (hit != null) return hit;
  final compact = base.replaceAll(RegExp(r'[\s.]+'), '');
  final script = _scriptDistrictAliases[compact];
  if (script != null) return script;
  return base.replaceAll(' ', '');
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final v = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
      cur[j] = v;
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Words that distinguish two otherwise equal district names (East / West
/// Godavari, Bengaluru Rural / Urban, ...). Two names that differ in one of
/// these are never the same district.
const List<String> _directionWords = [
  'north',
  'south',
  'east',
  'west',
  'central',
  'urban',
  'rural',
  'city',
  'new',
  'old',
];

/// The direction word a (space-less) key starts or ends with, else ''.
String _directionOf(String key) {
  for (final w in _directionWords) {
    if (key.length > w.length && (key.startsWith(w) || key.endsWith(w))) {
      return w;
    }
  }
  return '';
}

List<String> _wordsOf(String raw) {
  final base = _stripSuffix(raw);
  return base.isEmpty ? const [] : base.split(' ');
}

bool _fuzzy(String rawA, String rawB, String ka, String kb) {
  if (ka.isEmpty || kb.isEmpty) return false;
  if (ka == kb) return true;
  if (_directionOf(ka) != _directionOf(kb)) return false;
  final wa = _wordsOf(rawA), wb = _wordsOf(rawB);
  final aShorter = ka.length <= kb.length;
  final shorter = aShorter ? ka : kb;
  final longer = aShorter ? kb : ka;
  final sw = aShorter ? wa : wb, lw = aShorter ? wb : wa;
  // Whole-word containment ("Medchal" in "Medchal Malkajgiri").
  if (shorter.length >= 5 &&
      sw.length < lw.length &&
      sw.every(lw.contains) &&
      longer.contains(shorter)) {
    return true;
  }
  final maxDist = shorter.length < 9 ? 1 : 2;
  return shorter.length >= 5 && levenshtein(ka, kb) <= maxDist;
}

/// True when two district spellings refer to the same district.
bool sameDistrict(String a, String b) =>
    _fuzzy(a, b, normalizeDistrictKey(a), normalizeDistrictKey(b));

/// Best matching entry of [available] for [raw], or null. An exact (alias)
/// match wins; otherwise the single closest fuzzy match. When two entries tie
/// for closest the answer is ambiguous and null is returned.
String? bestDistrictMatch(String raw, Iterable<String> available) {
  final k = normalizeDistrictKey(raw);
  if (k.isEmpty) return null;
  for (final a in available) {
    if (normalizeDistrictKey(a) == k) return a;
  }
  String? best;
  var bestScore = 1 << 30;
  var tied = false;
  for (final a in available) {
    final ka = normalizeDistrictKey(a);
    if (!_fuzzy(raw, a, k, ka)) continue;
    final score = levenshtein(k, ka);
    if (score < bestScore) {
      bestScore = score;
      best = a;
      tied = false;
    } else if (score == bestScore) {
      tied = true;
    }
  }
  return tied ? null : best;
}

/// Known AP / Telangana districts (alias key -> state), used to derive a
/// state from a profile district when the user model has no state field.
const List<String> _telanganaDistricts = [
  'adilabad',
  'bhadradri kothagudem',
  'hyderabad',
  'jagtial',
  'jangaon',
  'jayashankar bhupalpally',
  'jogulamba gadwal',
  'kamareddy',
  'karimnagar',
  'khammam',
  'komaram bheem asifabad',
  'mahabubabad',
  'mahabubnagar',
  'mancherial',
  'medak',
  'medchal malkajgiri',
  'mulugu',
  'nagarkurnool',
  'nalgonda',
  'narayanpet',
  'nirmal',
  'nizamabad',
  'peddapalli',
  'rajanna sircilla',
  'rangareddy',
  'sangareddy',
  'siddipet',
  'suryapet',
  'vikarabad',
  'wanaparthy',
  'warangal',
  'hanumakonda',
  'yadadri bhuvanagiri',
];
const List<String> _andhraDistricts = [
  'alluri sitharama raju',
  'anakapalli',
  'anantapur',
  'annamayya',
  'bapatla',
  'chittoor',
  'dr b r ambedkar konaseema',
  'konaseema',
  'east godavari',
  'eluru',
  'guntur',
  'kakinada',
  'krishna',
  'kurnool',
  'nandyal',
  'ntr',
  'palnadu',
  'parvathipuram manyam',
  'prakasam',
  'nellore',
  'sri sathya sai',
  'srikakulam',
  'tirupati',
  'visakhapatnam',
  'vizianagaram',
  'west godavari',
  'kadapa',
];

/// Best-effort state for a known AP/Telangana district, else null.
String? stateForKnownDistrict(String district) {
  final k = normalizeDistrictKey(district);
  if (k.isEmpty) return null;
  bool inList(List<String> l) => l.any((d) => normalizeDistrictKey(d) == k);
  final tg = inList(_telanganaDistricts);
  final ap = inList(_andhraDistricts);
  if (tg && !ap) return 'Telangana';
  if (ap && !tg) return 'Andhra Pradesh';
  return null;
}

/// True when [canonical] (already passed through [canonicalState]) is a
/// state name this client knows.
bool isKnownState(String canonical) => _knownStates.contains(canonical);

/// All 36 Indian states / union territories (canonical English names, the
/// same spellings [canonicalState] returns), alphabetical.
final List<String> kAllIndianStates = List.unmodifiable(
  _stateTable.keys.toList()..sort(),
);

final RegExp _teScript = RegExp(r'[ఀ-౿]');
final RegExp _hiScript = RegExp(r'[ऀ-ॿ]');

/// Display name of a canonical state for [langCode] ('te', 'hi', else
/// English). Falls back to the canonical English name.
String stateDisplayName(String canonical, String langCode) {
  final re =
      langCode == 'te' ? _teScript : (langCode == 'hi' ? _hiScript : null);
  if (re == null) return canonical;
  final alts = _stateTable[canonical];
  if (alts == null) return canonical;
  for (final a in alts) {
    if (re.hasMatch(a)) return a;
  }
  return canonical;
}
