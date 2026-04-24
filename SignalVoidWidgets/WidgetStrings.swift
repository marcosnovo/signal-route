import Foundation

// MARK: - WidgetStrings
/// Localized UI strings for widget extension (EN/ES/FR).
/// Mirrors the main app's AppStrings (L.swift) for widget-relevant labels.
struct WidgetStrings {
    let lang: String // "en", "es", "fr"

    init(language: String?) {
        self.lang = language ?? "en"
    }

    private func t(_ en: String, _ es: String, _ fr: String) -> String {
        switch lang {
        case "es": return es
        case "fr": return fr
        default:   return en
        }
    }

    // MARK: - Progress Widget
    var campaign:          String { t("CAMPAIGN",           "CAMPAÑA",            "CAMPAGNE") }
    var rank:              String { t("RANK",               "RANGO",              "RANG") }
    var totalScore:        String { t("TOTAL SCORE",        "PUNTUACIÓN TOTAL",   "SCORE TOTAL") }
    var missions:          String { t("MISSIONS",           "MISIONES",           "MISSIONS") }
    var careerProgression: String { t("CAREER PROGRESSION", "PROGRESIÓN",         "PROGRESSION") }
    var campaignProgress:  String { t("CAMPAIGN PROGRESS",  "PROGRESO CAMPAÑA",   "PROGRÈS CAMPAGNE") }
    var sectors:           String { t("SECTORS",            "SECTORES",           "SECTEURS") }
    var score:             String { t("SCORE",              "PUNTOS",             "SCORE") }
    var bestEff:           String { t("BEST EFF",           "MEJOR EF",           "MEILL. EFF") }
    func toRank(_ name: String) -> String {
        let localName = rankName(name)
        return t("TO \(localName)", "PARA \(localName)", "VERS \(localName)")
    }

    // MARK: - Rank names
    func rankName(_ name: String) -> String {
        switch name.uppercased() {
        case "CADET":     return t("CADET",     "CADETE",     "CADET")
        case "PILOT":     return t("PILOT",     "PILOTO",     "PILOTE")
        case "NAVIGATOR": return t("NAVIGATOR", "NAVEGANTE",  "NAVIGATEUR")
        case "COMMANDER": return t("COMMANDER", "COMANDANTE", "COMMANDANT")
        case "ADMIRAL":   return t("ADMIRAL",   "ALMIRANTE",  "AMIRAL")
        default: return name
        }
    }

    /// Localized rank names array (same order as WidgetRanks.names).
    var rankNames: [String] {
        ["CADET", "PILOT", "NAVIGATOR", "COMMANDER", "ADMIRAL"].map { rankName($0) }
    }

    func rankSubtitle(rankIdx: Int, sectorIdx: Int, planetName: String) -> String {
        let localPlanet = self.planetName(planetName)
        let rankWord = t("Rank", "Rango", "Rang")
        let sectorWord = t("Sector", "Sector", "Secteur")
        return "\(rankWord) \(String(format: "%02d", rankIdx + 1)) \u{00B7} \(sectorWord) \(sectorIdx + 1) \(localPlanet.capitalized)"
    }

    /// Localized rank title for display (e.g. "Navigator" → "Navegante").
    func localizedRankTitle(_ title: String) -> String {
        rankName(title).capitalized
    }

    // MARK: - Leaderboard Widget
    var leaderboard:       String { t("LEADERBOARD",        "CLASIFICACIÓN",      "CLASSEMENT") }
    var globalLeaderboard: String { t("GLOBAL LEADERBOARD", "CLASIF. GLOBAL",     "CLASSEMENT GLOBAL") }
    var position:          String { t("POSITION",           "POSICIÓN",           "POSITION") }
    var yourScore:         String { t("YOUR SCORE",         "TU PUNTUACIÓN",      "TON SCORE") }
    var thisWeek:          String { t("THIS WEEK",          "ESTA SEMANA",        "CETTE SEMAINE") }
    var streak:            String { t("STREAK",             "RACHA",              "SÉRIE") }
    var efficiency:        String { t("EFFICIENCY",         "EFICIENCIA",         "EFFICACITÉ") }
    func classLabel(_ rankTitle: String) -> String {
        let localRank = rankName(rankTitle).capitalized
        let localClass = t("class", "clase", "classe")
        return "\(localRank) \(localClass)"
    }

    // MARK: - Planet Pass Widget
    var planetPass:        String { t("PLANET PASS",         "PASE PLANETARIO",    "LAISSEZ-PASSER") }
    var accessAuthorized:  String { t("ACCESS AUTHORIZED",   "ACCESO AUTORIZADO",  "ACCÈS AUTORISÉ") }
    var missionEfficiency: String { t("MISSION EFFICIENCY",  "EFIC. DE MISIÓN",    "EFF. DE MISSION") }
    var level:             String { t("LEVEL",               "NIVEL",              "NIVEAU") }
    var status:            String { t("STATUS",              "ESTADO",             "ÉTAT") }
    var cleared:           String { t("CLEARED",             "COMPLETADO",         "VALIDÉ") }
    var active:            String { t("ACTIVE",              "ACTIVO",             "ACTIF") }
    var clearedShort:      String { t("CLR",                 "OK",                 "OK") }
    var activeShort:       String { t("ACT",                 "ACT",                "ACT") }

    // MARK: - Empty States
    var playMission:       String { t("PLAY A MISSION\nTO SEE PROGRESS",  "JUEGA UNA MISIÓN\nPARA VER PROGRESO",  "JOUE UNE MISSION\nPOUR VOIR TA PROGRESSION") }
    var connectGC:         String { t("PLAY & CONNECT\nTO GAME CENTER",   "JUEGA Y CONECTA\nA GAME CENTER",      "JOUE ET CONNECTE\nGAME CENTER") }
    var earnPass:          String { t("COMPLETE A SECTOR\nTO EARN A PASS", "COMPLETA UN SECTOR\nPARA OBTENER PASE","TERMINE UN SECTEUR\nPOUR OBTENIR UN PASSE") }

    // MARK: - Board labels (for leaderboard intent)
    func boardLabel(_ board: String) -> String {
        switch board.uppercased() {
        case "TOTAL":  return t("TOTAL",  "TOTAL",  "TOTAL")
        case "EASY":   return t("EASY",   "FÁCIL",  "FACILE")
        case "MEDIUM": return t("MEDIUM", "MEDIO",  "MOYEN")
        case "HARD":   return t("HARD",   "DIFÍCIL","DIFFICILE")
        case "EXPERT": return t("EXPERT", "EXPERTO","EXPERT")
        default: return board
        }
    }

    // MARK: - Planet names
    func planetName(_ name: String) -> String {
        switch name.uppercased() {
        case "EARTH ORBIT":   return t("EARTH ORBIT",   "ÓRBITA TERRESTRE",       "ORBITE TERRESTRE")
        case "MOON":          return t("MOON",           "LUNA",                   "LUNE")
        case "MARS":          return t("MARS",           "MARTE",                  "MARS")
        case "ASTEROID BELT": return t("ASTEROID BELT",  "CINTURÓN DE ASTEROIDES", "CEINTURE D'ASTÉROÏDES")
        case "JUPITER":       return t("JUPITER",        "JÚPITER",                "JUPITER")
        case "SATURN":        return t("SATURN",         "SATURNO",                "SATURNE")
        case "URANUS":        return t("URANUS",         "URANO",                  "URANUS")
        case "NEPTUNE":       return t("NEPTUNE",        "NEPTUNO",                "NEPTUNE")
        default: return name
        }
    }

    // MARK: - PlanetInfo categories
    func category(for planetIndex: Int) -> String {
        switch planetIndex {
        case 0:  return t("TRAINING ZONE",       "ZONA ENTRENAMIENTO",     "ZONE D'ENTRAÎNEMENT")
        case 1:  return t("LUNAR OPERATIONS",    "OPS LUNARES",            "OPS LUNAIRES")
        case 2:  return t("RED PLANET OPS",      "OPS PLANETA ROJO",       "OPS PLANÈTE ROUGE")
        case 3:  return t("ASTEROID FIELD",      "CAMPO DE ASTEROIDES",    "CHAMP D'ASTÉROÏDES")
        case 4:  return t("GAS GIANT RELAY",     "RELÉ GIGANTE GASEOSO",   "RELAIS GÉANT GAZEUX")
        case 5:  return t("RING SYSTEM TRANSIT", "TRÁNSITO DE ANILLOS",    "TRANSIT DES ANNEAUX")
        case 6:  return t("ICE GIANT PATROL",    "PATRULLA GIGANTE HELADO","PATROUILLE GÉANT GLACÉ")
        case 7:  return t("DEEP VOID",           "VACÍO PROFUNDO",         "VIDE PROFOND")
        default: return t("UNKNOWN SECTOR",      "SECTOR DESCONOCIDO",     "SECTEUR INCONNU")
        }
    }

    // MARK: - Difficulty
    func difficulty(for planetIndex: Int) -> String {
        switch planetIndex {
        case 0, 1:  return t("EASY",   "FÁCIL",   "FACILE")
        case 2, 3:  return t("MEDIUM", "MEDIO",   "MOYEN")
        case 4, 5:  return t("HARD",   "DIFÍCIL", "DIFFICILE")
        case 6, 7:  return t("EXPERT", "EXPERTO", "EXPERT")
        default:    return "\u{2014}"
        }
    }
}
