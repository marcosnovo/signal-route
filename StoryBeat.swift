import SwiftUI

// MARK: - LocalizedText

/// Multilingual string container for narrative content in story beats.
/// Falls back to `en` when the requested language is unavailable.
struct LocalizedText: Codable, Equatable {
    let en: String
    let es: String
    let fr: String
    let ja: String?

    init(en: String, es: String, fr: String, ja: String? = nil) {
        self.en = en
        self.es = es
        self.fr = fr
        self.ja = ja
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        en = try c.decode(String.self, forKey: .en)
        es = try c.decode(String.self, forKey: .es)
        fr = try c.decode(String.self, forKey: .fr)
        ja = try c.decodeIfPresent(String.self, forKey: .ja)
    }

    func text(for language: AppLanguage) -> String {
        switch language {
        case .en: return en
        case .es: return es
        case .fr: return fr
        case .ja: return ja ?? en
        }
    }
}

// MARK: - StoryTrigger

/// The in-game moment that causes a story beat to surface.
enum StoryTrigger: String, Codable, Equatable, CaseIterable {
    case firstLaunch            // app opened for the very first time
    case firstMissionReady      // player is cleared to begin their first real mission
    case firstMissionComplete   // first regular mission won
    case onboardingComplete     // 8th mission won — free-intro quota exhausted, 24h gate begins
    case sectorComplete         // all missions in a sector finished
    case passUnlocked           // a new PlanetPass issued
    case rankUp                 // astronaut level increases
    case mechanicUnlocked       // a new MechanicType first encountered
    case enteringNewSector      // player unlocks access to a new sector
}

// MARK: - StoryContext

/// Contextual data passed when checking for pending story beats.
struct StoryContext {
    var playerLevel:       Int          = 1
    var completedSectorID: Int?         = nil
    var unlockedMechanic:  MechanicType? = nil

    static func forSector(_ id: Int, level: Int) -> StoryContext {
        StoryContext(playerLevel: level, completedSectorID: id)
    }
    static func forMechanic(_ m: MechanicType, level: Int) -> StoryContext {
        StoryContext(playerLevel: level, unlockedMechanic: m)
    }
    static func forRankUp(to level: Int) -> StoryContext {
        StoryContext(playerLevel: level)
    }
}

// MARK: - StoryBeat

/// A single narrative moment — shown once (by default), persisted when seen.
struct StoryBeat: Identifiable, Codable, Equatable {
    let id:                  String           // unique key used for "seen" persistence
    let title:               String           // EN headline — used as fallback when localizedTitle is nil
    let body:                String           // EN body — used as fallback when localizedBody is nil
    let source:              String           // transmission origin (e.g., "MISSION CONTROL")
    let trigger:             StoryTrigger

    // ── Optional filters (nil = matches any) ─────────────────────────────
    let requiredPlayerLevel: Int?
    let requiredSectorID:    Int?
    let requiredMechanic:    MechanicType?

    let accentHex:           String?
    let footerHint:          String?

    // ── Media & display ──────────────────────────────────────────────────
    let imageName:           String?
    let isSkippable:         Bool
    let priority:            Int
    let sequenceGroup:       String?
    let orderInSequence:     Int
    let onceOnly:            Bool

    // ── Localization ─────────────────────────────────────────────────────
    let localizedTitle:      LocalizedText?
    let localizedBody:       LocalizedText?

    // MARK: - Localization helpers

    func displayTitle(for language: AppLanguage) -> String {
        localizedTitle?.text(for: language) ?? title
    }

    func displayBody(for language: AppLanguage) -> String {
        localizedBody?.text(for: language) ?? body
    }

    /// Localized source label (transmission origin).
    func displaySource(for language: AppLanguage) -> String {
        switch source {
        case "MISSION CONTROL":
            switch language {
            case .en: return source
            case .es: return "CONTROL DE MISIÓN"
            case .fr: return "CONTRÔLE DE MISSION"
            case .ja: return "ミッションコントロール"
            }
        case "COMMAND":
            switch language {
            case .en: return source
            case .es: return "COMANDO"
            case .fr: return "COMMANDEMENT"
            case .ja: return "司令部"
            }
        case "ENGINEERING":
            switch language {
            case .en: return source
            case .es: return "INGENIERÍA"
            case .fr: return "INGÉNIERIE"
            case .ja: return "技術部"
            }
        default: return source
        }
    }

    // MARK: - Init (all new fields have defaults)

    init(
        id:                  String,
        title:               String,
        body:                String,
        source:              String,
        trigger:             StoryTrigger,
        requiredPlayerLevel: Int?          = nil,
        requiredSectorID:    Int?          = nil,
        requiredMechanic:    MechanicType? = nil,
        accentHex:           String?       = nil,
        footerHint:          String?       = nil,
        imageName:           String?       = nil,
        isSkippable:         Bool          = true,
        priority:            Int           = 50,
        sequenceGroup:       String?       = nil,
        orderInSequence:     Int           = 0,
        onceOnly:            Bool          = true,
        localizedTitle:      LocalizedText? = nil,
        localizedBody:       LocalizedText? = nil
    ) {
        self.id                  = id
        self.title               = title
        self.body                = body
        self.source              = source
        self.trigger             = trigger
        self.requiredPlayerLevel = requiredPlayerLevel
        self.requiredSectorID    = requiredSectorID
        self.requiredMechanic    = requiredMechanic
        self.accentHex           = accentHex
        self.footerHint          = footerHint
        self.imageName           = imageName
        self.isSkippable         = isSkippable
        self.priority            = priority
        self.sequenceGroup       = sequenceGroup
        self.orderInSequence     = orderInSequence
        self.onceOnly            = onceOnly
        self.localizedTitle      = localizedTitle
        self.localizedBody       = localizedBody
    }

    // MARK: - Codable (decodeIfPresent for all optional/new fields)

    enum CodingKeys: String, CodingKey {
        case id, title, body, source, trigger
        case requiredPlayerLevel, requiredSectorID, requiredMechanic
        case accentHex, footerHint
        case imageName, isSkippable, priority, sequenceGroup, orderInSequence, onceOnly
        case localizedTitle, localizedBody
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(String.self,       forKey: .id)
        title               = try c.decode(String.self,       forKey: .title)
        body                = try c.decode(String.self,       forKey: .body)
        source              = try c.decode(String.self,       forKey: .source)
        trigger             = try c.decode(StoryTrigger.self, forKey: .trigger)
        requiredPlayerLevel = try c.decodeIfPresent(Int.self,           forKey: .requiredPlayerLevel)
        requiredSectorID    = try c.decodeIfPresent(Int.self,           forKey: .requiredSectorID)
        requiredMechanic    = try c.decodeIfPresent(MechanicType.self,  forKey: .requiredMechanic)
        accentHex           = try c.decodeIfPresent(String.self,        forKey: .accentHex)
        footerHint          = try c.decodeIfPresent(String.self,        forKey: .footerHint)
        imageName           = try c.decodeIfPresent(String.self,        forKey: .imageName)
        isSkippable         = try c.decodeIfPresent(Bool.self,          forKey: .isSkippable)         ?? true
        priority            = try c.decodeIfPresent(Int.self,           forKey: .priority)            ?? 50
        sequenceGroup       = try c.decodeIfPresent(String.self,        forKey: .sequenceGroup)
        orderInSequence     = try c.decodeIfPresent(Int.self,           forKey: .orderInSequence)     ?? 0
        onceOnly            = try c.decodeIfPresent(Bool.self,          forKey: .onceOnly)            ?? true
        localizedTitle      = try c.decodeIfPresent(LocalizedText.self, forKey: .localizedTitle)
        localizedBody       = try c.decodeIfPresent(LocalizedText.self, forKey: .localizedBody)
    }
}

// MARK: - StoryBeatCatalog

/// Complete static catalog of all story beats.
///
/// Priority ordering — lower number = shown first when multiple beats queue simultaneously:
///   1–9   intro sequence
///   10–19 mission-level narrative (post-onboarding, first-mission, etc.)
///   20–29 sector complete
///   30–39 pass unlocked
///   40–49 entering new sector
///   50–69 rank-up / mechanic-specific tutorials
///   70+   generic / repeatable atmospheric beats
enum StoryBeatCatalog {

    static let beats: [StoryBeat] = [

        // ══════════════════════════════════════════════════════════════
        // FIRST LAUNCH — 2-beat cinematic intro (shortened from 4)
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:             "story_intro_01",
            title:          "SIGNAL LOST",
            body:           "Orbital routes are failing. Stations can no longer maintain stability on their own. They need you.",
            source:         "MISSION CONTROL",
            trigger:        .firstLaunch,
            accentHex:      "FF6A3D",
            imageName:      "intro_console",
            priority:       1,
            sequenceGroup:  "intro_first_launch",
            orderInSequence: 1,
            localizedTitle: LocalizedText(
                en: "SIGNAL LOST",
                es: "SEÑAL PERDIDA",
                fr: "SIGNAL PERDU",
                ja: "シグナル消失"
            ),
            localizedBody: LocalizedText(
                en: "Orbital routes are failing. Stations can no longer maintain stability on their own. They need you.",
                es: "Las rutas orbitales están fallando. Las estaciones no pueden mantener la estabilidad por sí solas. Te necesitan.",
                fr: "Les routes orbitales sont en panne. Les stations ne peuvent plus maintenir leur stabilité seules. Elles ont besoin de toi.",
                ja: "軌道ルートが機能不全に陥っています。各ステーションは単独で安定を維持できません。あなたの力が必要です。"
            )
        ),

        StoryBeat(
            id:             "story_intro_03",
            title:          "YOUR MISSION",
            body:           "Restore the network. Prove your precision and earn access to increasingly distant destinations.",
            source:         "COMMAND",
            trigger:        .firstLaunch,
            accentHex:      "4DB87A",
            footerHint:     "EARTH ORBIT SECTOR ACTIVE",
            imageName:      "intro_airlock",
            priority:       2,
            sequenceGroup:  "intro_first_launch",
            orderInSequence: 2,
            localizedTitle: LocalizedText(
                en: "YOUR MISSION",
                es: "TU MISIÓN",
                fr: "TA MISSION",
                ja: "あなたのミッション"
            ),
            localizedBody: LocalizedText(
                en: "Restore the network. Prove your precision and earn access to increasingly distant destinations.",
                es: "Restaura la red. Demuestra tu precisión y obtén acceso a destinos cada vez más lejanos.",
                fr: "Restaure le réseau. Prouve ta précision et obtiens l'accès à des destinations toujours plus lointaines.",
                ja: "ネットワークを復旧せよ。精度を証明し、より遠い目的地へのアクセスを獲得してください。"
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // FIRST MISSION READY
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:             "story_first_mission_ready",
            title:          "DEPLOYMENT READY",
            body:           "The network responded. You are now cleared for your first mission.",
            source:         "MISSION CONTROL",
            trigger:        .firstMissionReady,
            accentHex:      "4DB87A",
            footerHint:     "MISSION 1 LOADED",
            imageName:      "intro_window",
            priority:       10,
            sequenceGroup:  "first_mission_ready",
            orderInSequence: 1,
            localizedTitle: LocalizedText(
                en: "DEPLOYMENT READY",
                es: "LISTO PARA OPERAR",
                fr: "PRÊT À DÉPLOYER",
                ja: "配備準備完了"
            ),
            localizedBody: LocalizedText(
                en: "The network responded. You are now cleared for your first mission.",
                es: "La red ha respondido. Ya estás listo para tu primera misión.",
                fr: "Le réseau a répondu. Tu es désormais autorisé à commencer ta première mission.",
                ja: "ネットワークが応答しました。最初のミッションへの出撃が許可されました。"
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // FIRST MISSION COMPLETE
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:             "story_first_mission_complete",
            title:          "SIGNAL STABLE",
            body:           "Small systems first. Longer routes later. Every stable network expands the reach of the next mission.",
            source:         "MISSION CONTROL",
            trigger:        .firstMissionComplete,
            imageName:      "sector_earth_complete",
            priority:       10,
            sequenceGroup:  "mission_1_complete",
            orderInSequence: 1,
            localizedTitle: LocalizedText(
                en: "SIGNAL STABLE",
                es: "SEÑAL ESTABLE",
                fr: "SIGNAL STABILISÉ",
                ja: "シグナル安定"
            ),
            localizedBody: LocalizedText(
                en: "Small systems first. Longer routes later. Every stable network expands the reach of the next mission.",
                es: "Primero sistemas pequeños. Luego rutas más largas. Cada red estable amplía el alcance de la siguiente misión.",
                fr: "D'abord les petits systèmes. Ensuite les routes plus longues. Chaque réseau stabilisé étend la portée de la mission suivante.",
                ja: "まず小さなシステムから。後に長いルートを。安定したネットワークが次のミッションの到達範囲を広げます。"
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // ONBOARDING COMPLETE — fires after the 8th free mission win
        // Shown when the player returns to Home; appears before the
        // hard gate so the narrative context is clear before they're blocked.
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:             "story_onboarding_complete",
            title:          "SIGNAL LOCKED",
            body:           "Your clearance window has closed. New routes are ready — but the next orbital window opens in 24 hours. Or request immediate access.",
            source:         "MISSION CONTROL",
            trigger:        .onboardingComplete,
            accentHex:      "FF6A3D",
            footerHint:     "NEXT WINDOW: 24H",
            imageName:      "intro_alert",
            priority:       5,
            localizedTitle: LocalizedText(
                en: "SIGNAL LOCKED",
                es: "SEÑAL BLOQUEADA",
                fr: "SIGNAL VERROUILLÉ",
                ja: "シグナルロック"
            ),
            localizedBody: LocalizedText(
                en: "Your clearance window has closed. New routes are ready — but the next orbital window opens in 24 hours. Or request immediate access.",
                es: "Tu ventana de autorización se ha cerrado. Nuevas rutas están listas, pero la siguiente ventana orbital se abre en 24 horas. O solicita acceso inmediato.",
                fr: "Ta fenêtre d'accréditation est terminée. De nouvelles routes sont prêtes — mais la prochaine fenêtre orbitale s'ouvre dans 24 heures. Ou demande un accès immédiat.",
                ja: "認可ウィンドウが閉じました。新しいルートは準備できていますが、次の軌道ウィンドウは24時間後に開きます。または即時アクセスをリクエストしてください。"
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // SECTOR COMPLETE — one beat per sector (IDs 1–8)
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:               "story_earth_complete",
            title:            "ORBIT RESTORED",
            body:             "This was never about speed. It was about reliability.",
            source:           "MISSION CONTROL",
            trigger:          .sectorComplete,
            requiredSectorID: 1,
            accentHex:        "4DB87A",
            footerHint:       "LUNAR APPROACH UNLOCKED",
            imageName:        "sector_earth_complete",
            priority:         20,
            sequenceGroup:    "earth_complete",
            orderInSequence:  1,
            localizedTitle: LocalizedText(
                en: "ORBIT RESTORED",
                es: "ÓRBITA RESTAURADA",
                fr: "ORBITE RESTAURÉE",
                ja: "軌道復旧"
            ),
            localizedBody: LocalizedText(
                en: "This was never about speed. It was about reliability.",
                es: "No se trataba de velocidad. Se trataba de fiabilidad.",
                fr: "Il ne s'agissait pas de vitesse. Il s'agissait de fiabilité.",
                ja: "これは速さの問題ではありませんでした。信頼性の問題だったのです。"
            )
        ),

        StoryBeat(
            id:               "sector_2_clear",
            title:            "LUNAR GRID ONLINE",
            body:             "Moon base power grid fully restored. You're ahead of every estimate. The Mars sector relay chain is within reach.",
            source:           "COMMAND",
            trigger:          .sectorComplete,
            requiredSectorID: 2,
            accentHex:        "D9E7D8",
            footerHint:       "MARS SECTOR UNLOCKED",
            imageName:        "sector_lunar_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "LUNAR GRID ONLINE",
                es: "RED LUNAR ACTIVA",
                fr: "RÉSEAU LUNAIRE EN LIGNE",
                ja: "月面グリッド稼働"
            ),
            localizedBody: LocalizedText(
                en: "Moon base power grid fully restored. You're ahead of every estimate. The Mars sector relay chain is within reach.",
                es: "La red de energía de la base lunar está completamente restaurada. Superas todas las estimaciones. La cadena de retransmisores del sector Marte está al alcance.",
                fr: "Le réseau électrique de la base lunaire est entièrement rétabli. Tu dépasses toutes les estimations. La chaîne de relais du secteur Mars est à portée.",
                ja: "月面基地の電力グリッドが完全復旧。あらゆる予測を上回っています。火星セクターのリレーチェーンが射程内に入りました。"
            )
        ),

        StoryBeat(
            id:               "sector_3_clear",
            title:            "RED PLANET CLEAR",
            body:             "Mars sector relays are running clean for the first time in months. The colonies are noticing. Your record is being watched.",
            source:           "COMMAND",
            trigger:          .sectorComplete,
            requiredSectorID: 3,
            accentHex:        "FF6A3D",
            footerHint:       "ASTEROID BELT ROUTE OPEN",
            imageName:        "sector_mars_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "RED PLANET CLEAR",
                es: "MARTE DESPEJADO",
                fr: "MARS DÉGAGÉ",
                ja: "赤い惑星 完了"
            ),
            localizedBody: LocalizedText(
                en: "Mars sector relays are running clean for the first time in months. The colonies are noticing. Your record is being watched.",
                es: "Los retransmisores del sector Marte funcionan sin fallos por primera vez en meses. Las colonias lo están notando. Tus resultados están siendo observados.",
                fr: "Les relais du secteur Mars fonctionnent sans problème pour la première fois en plusieurs mois. Les colonies le remarquent. Tes résultats sont scrutés.",
                ja: "火星セクターのリレーが数ヶ月ぶりにクリーンに稼働しています。コロニーが注目しています。あなたの記録は注視されています。"
            )
        ),

        StoryBeat(
            id:               "sector_4_clear",
            title:            "DEBRIS CLEARED",
            body:             "Routing through the Asteroid Belt was never done before at this speed. You've set a new baseline for network recovery ops.",
            source:           "COMMAND",
            trigger:          .sectorComplete,
            requiredSectorID: 4,
            accentHex:        "FFB800",
            footerHint:       "JUPITER RELAY APPROACH OPEN",
            imageName:        "asteroid_belt_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "DEBRIS CLEARED",
                es: "ESCOMBROS DESPEJADOS",
                fr: "DÉBRIS ÉLIMINÉS",
                ja: "デブリ除去完了"
            ),
            localizedBody: LocalizedText(
                en: "Routing through the Asteroid Belt was never done before at this speed. You've set a new baseline for network recovery ops.",
                es: "Nunca se había trazado una ruta por el Cinturón de Asteroides a esta velocidad. Has establecido un nuevo estándar para las operaciones de recuperación de red.",
                fr: "Aucun routage n'avait jamais traversé la Ceinture d'astéroïdes à cette vitesse. Tu viens de poser un nouveau standard pour les opérations de récupération réseau.",
                ja: "小惑星帯をこの速度でルーティングしたことは前例がありません。ネットワーク復旧作戦の新基準を打ち立てました。"
            )
        ),

        StoryBeat(
            id:               "sector_5_clear",
            title:            "GIANT ONLINE",
            body:             "Jupiter's relay array is fully operational. The gas giant's atmospheric interference couldn't stop you. Outer system access confirmed.",
            source:           "MISSION CONTROL",
            trigger:          .sectorComplete,
            requiredSectorID: 5,
            accentHex:        "D4A055",
            footerHint:       "SATURN RING SECTOR OPEN",
            imageName:        "jupiter_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "GIANT ONLINE",
                es: "EL GIGANTE EN LÍNEA",
                fr: "LE GÉANT EN LIGNE",
                ja: "巨星オンライン"
            ),
            localizedBody: LocalizedText(
                en: "Jupiter's relay array is fully operational. The gas giant's atmospheric interference couldn't stop you. Outer system access confirmed.",
                es: "El sistema de retransmisores de Júpiter está completamente operativo. La interferencia atmosférica del gigante gaseoso no pudo detenerte. Acceso al sistema exterior confirmado.",
                fr: "Le réseau de relais de Jupiter est pleinement opérationnel. Les interférences atmosphériques du géant gazeux n'ont pas pu t'arrêter. Accès au système extérieur confirmé.",
                ja: "木星のリレーアレイが完全稼働。ガス巨星の大気干渉もあなたを止められませんでした。外部システムへのアクセス確認。"
            )
        ),

        StoryBeat(
            id:               "sector_6_clear",
            title:            "RINGS ALIGNED",
            body:             "Signal threading through Saturn's rings — a routing problem once thought unsolvable. You made it routine. Deep space access is imminent.",
            source:           "ENGINEERING",
            trigger:          .sectorComplete,
            requiredSectorID: 6,
            accentHex:        "E4C87A",
            footerHint:       "URANUS VOID SECTOR OPEN",
            imageName:        "saturn_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "RINGS ALIGNED",
                es: "ANILLOS ALINEADOS",
                fr: "ANNEAUX ALIGNÉS",
                ja: "リング整列完了"
            ),
            localizedBody: LocalizedText(
                en: "Signal threading through Saturn's rings — a routing problem once thought unsolvable. You made it routine. Deep space access is imminent.",
                es: "Señal enrutada a través de los anillos de Saturno, un problema que antes se consideraba irresoluble. Lo has convertido en algo rutinario. El espacio profundo está al alcance.",
                fr: "Signal traversant les anneaux de Saturne — un problème de routage autrefois jugé insoluble. Tu en as fait une routine. L'espace profond est imminent.",
                ja: "土星のリングを通じたシグナルスレッディング — かつて解決不可能と思われたルーティング問題。あなたはそれを日常にしました。深宇宙アクセスが目前です。"
            )
        ),

        StoryBeat(
            id:               "sector_7_clear",
            title:            "VOID NAVIGATED",
            body:             "Uranus sector relays are live. The void between planets no longer means silence — it means signal. You're making history.",
            source:           "COMMAND",
            trigger:          .sectorComplete,
            requiredSectorID: 7,
            accentHex:        "7EC8E3",
            footerHint:       "NEPTUNE DEEP SECTOR OPEN",
            imageName:        "uranus_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "VOID NAVIGATED",
                es: "VACÍO NAVEGADO",
                fr: "LE VIDE TRAVERSÉ",
                ja: "ボイド航行完了"
            ),
            localizedBody: LocalizedText(
                en: "Uranus sector relays are live. The void between planets no longer means silence — it means signal. You're making history.",
                es: "Los retransmisores del sector Urano están activos. El vacío entre planetas ya no significa silencio, significa señal. Estás haciendo historia.",
                fr: "Les relais du secteur Uranus sont actifs. Le vide entre les planètes ne signifie plus le silence — il signifie signal. Tu es en train de faire l'histoire.",
                ja: "天王星セクターのリレーが稼働中。惑星間のボイドはもはや沈黙を意味しません — シグナルを意味します。あなたは歴史を作っています。"
            )
        ),

        StoryBeat(
            id:               "sector_8_clear",
            title:            "DEEP SIGNAL",
            body:             "Neptune sector online. The inner solar system relay network is complete. But signals from beyond Neptune have been detected — faint, frozen, waiting.",
            source:           "MISSION CONTROL",
            trigger:          .sectorComplete,
            requiredSectorID: 8,
            accentHex:        "4B70DD",
            footerHint:       "KUIPER BELT SECTOR OPEN",
            imageName:        "deep_space_network",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "DEEP SIGNAL",
                es: "SEÑAL PROFUNDA",
                fr: "SIGNAL PROFOND",
                ja: "ディープシグナル"
            ),
            localizedBody: LocalizedText(
                en: "Neptune sector online. The inner solar system relay network is complete. But signals from beyond Neptune have been detected — faint, frozen, waiting.",
                es: "Sector Neptuno en línea. La red de retransmisores del sistema solar interior está completa. Pero se han detectado señales más allá de Neptuno — débiles, congeladas, esperando.",
                fr: "Secteur Neptune en ligne. Le réseau de relais du système solaire intérieur est complet. Mais des signaux au-delà de Neptune ont été détectés — faibles, gelés, en attente.",
                ja: "海王星セクターオンライン。内部太陽系リレーネットワーク完成。しかし海王星の彼方からシグナルが検出されました — 微弱で、凍りつき、待っています。"
            )
        ),

        StoryBeat(
            id:               "sector_9_clear",
            title:            "FROZEN FRONTIER",
            body:             "Kuiper Belt relays stabilized. Signal routes now extend through the frozen debris field. The edge of known space pushes further into the dark.",
            source:           "COMMAND",
            trigger:          .sectorComplete,
            requiredSectorID: 9,
            accentHex:        "A8D8EA",
            footerHint:       "OORT CLOUD SECTOR OPEN",
            imageName:        "kuiper_complete",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "FROZEN FRONTIER",
                es: "FRONTERA HELADA",
                fr: "FRONTIÈRE GELÉE",
                ja: "凍てつく辺境"
            ),
            localizedBody: LocalizedText(
                en: "Kuiper Belt relays stabilized. Signal routes now extend through the frozen debris field. The edge of known space pushes further into the dark.",
                es: "Retransmisores del Cinturón de Kuiper estabilizados. Las rutas de señal se extienden ahora a través del campo de escombros helados. El borde del espacio conocido avanza hacia la oscuridad.",
                fr: "Relais de la Ceinture de Kuiper stabilisés. Les routes du signal s'étendent désormais à travers le champ de débris gelés. La frontière de l'espace connu recule dans l'obscurité.",
                ja: "カイパーベルトのリレーが安定。シグナルルートは凍てつくデブリフィールドを通じて拡張されました。既知空間の端がさらに暗闇の中へ押し進みます。"
            )
        ),

        StoryBeat(
            id:               "sector_10_clear",
            title:            "BEYOND THE VOID",
            body:             "Oort Cloud online. The full signal network — from Earth to the outermost reaches — is operational. You've connected humanity across the entire solar system. Mission complete.",
            source:           "MISSION CONTROL",
            trigger:          .sectorComplete,
            requiredSectorID: 10,
            accentHex:        "9B72CF",
            footerHint:       "FULL NETWORK OPERATIONAL",
            imageName:        "oort_complete",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "BEYOND THE VOID",
                es: "MÁS ALLÁ DEL VACÍO",
                fr: "AU-DELÀ DU VIDE",
                ja: "ボイドの彼方"
            ),
            localizedBody: LocalizedText(
                en: "Oort Cloud online. The full signal network — from Earth to the outermost reaches — is operational. You've connected humanity across the entire solar system. Mission complete.",
                es: "Nube de Oort en línea. La red de señal completa — desde la Tierra hasta los confines más lejanos — está operativa. Has conectado a la humanidad a través de todo el sistema solar. Misión cumplida.",
                fr: "Nuage d'Oort en ligne. Le réseau de signal complet — de la Terre jusqu'aux confins les plus lointains — est opérationnel. Tu as connecté l'humanité à travers tout le système solaire. Mission accomplie.",
                ja: "オールトの雲オンライン。地球から最遠端までの完全シグナルネットワークが稼働中。あなたは太陽系全体を通じて人類を接続しました。ミッション完了。"
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // RANK UP — key level milestones
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:                  "rank_up_2",
            title:               "RANK ADVANCED",
            body:                "Your routing metrics exceed baseline. New mission sectors are opening up. This is just the beginning of what you can reach.",
            source:              "MISSION CONTROL",
            trigger:             .rankUp,
            requiredPlayerLevel: 2,
            footerHint:          "RANK: PILOT",
            imageName:           "rank_up_promotion",
            priority:            50,
            localizedTitle: LocalizedText(
                en: "RANK ADVANCED",
                es: "RANGO ASCENDIDO",
                fr: "RANG AVANCÉ",
                ja: "ランク昇進"
            ),
            localizedBody: LocalizedText(
                en: "Your routing metrics exceed baseline. New mission sectors are opening up. This is just the beginning of what you can reach.",
                es: "Tus métricas de enrutamiento superan el nivel base. Se abren nuevos sectores de misiones. Esto es solo el principio de hasta dónde puedes llegar.",
                fr: "Tes métriques de routage dépassent le niveau de référence. De nouveaux secteurs de missions s'ouvrent. Ce n'est que le début de ce que tu peux atteindre.",
                ja: "ルーティング指標がベースラインを超過。新しいミッションセクターが開放されています。これはあなたが到達できる範囲のほんの始まりです。"
            )
        ),

        StoryBeat(
            id:                  "rank_up_5",
            title:               "FIELD PROMOTION",
            body:                "Program leadership has taken notice. You're no longer a cadet routing training nodes — you're a senior engineer in active deployment.",
            source:              "COMMAND",
            trigger:             .rankUp,
            requiredPlayerLevel: 5,
            footerHint:          "RANK: NAVIGATOR",
            imageName:           "rank_up_promotion",
            priority:            50,
            localizedTitle: LocalizedText(
                en: "FIELD PROMOTION",
                es: "ASCENSO EN CAMPO",
                fr: "PROMOTION DE TERRAIN",
                ja: "現場昇進"
            ),
            localizedBody: LocalizedText(
                en: "Program leadership has taken notice. You're no longer a cadet routing training nodes — you're a senior engineer in active deployment.",
                es: "Los responsables del programa te han tomado nota. Ya no eres un cadete enrutando nodos de entrenamiento: eres un ingeniero senior en despliegue activo.",
                fr: "La direction du programme t'a remarqué. Tu n'es plus un cadet routant des nœuds d'entraînement — tu es un ingénieur senior en déploiement actif.",
                ja: "プログラム指導部が注目しています。もはや訓練ノードをルーティングする訓練生ではありません — 実戦配備中のシニアエンジニアです。"
            )
        ),

        StoryBeat(
            id:                  "rank_up_10",
            title:               "DEEP COMMISSION",
            body:                "Only a handful of engineers have ever reached this clearance level. The outer solar system relay grid is now your responsibility.",
            source:              "COMMAND",
            trigger:             .rankUp,
            requiredPlayerLevel: 10,
            accentHex:           "4B70DD",
            footerHint:          "RANK: COMMANDER",
            imageName:           "rank_up_promotion",
            priority:            50,
            localizedTitle: LocalizedText(
                en: "DEEP COMMISSION",
                es: "COMISIÓN PROFUNDA",
                fr: "COMMISSION EN PROFONDEUR",
                ja: "深宇宙任命"
            ),
            localizedBody: LocalizedText(
                en: "Only a handful of engineers have ever reached this clearance level. The outer solar system relay grid is now your responsibility.",
                es: "Solo un puñado de ingenieros han alcanzado este nivel de autorización. La red de retransmisores del sistema solar exterior es ahora tu responsabilidad.",
                fr: "Une poignée d'ingénieurs seulement ont jamais atteint ce niveau d'accréditation. Le réseau de relais du système solaire extérieur est désormais sous ta responsabilité.",
                ja: "このクリアランスレベルに到達したエンジニアはごくわずかです。外部太陽系リレーグリッドはあなたの責任となりました。"
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // MECHANIC UNLOCKED — specific tutorials per mechanic
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:               "mechanic_rotationCap",
            title:            "COMPONENT STRESS",
            body:             "Field alert: relay units in the next sector have been over-rotated and are near tolerance limits. Each rotation you take may be the last.",
            source:           "ENGINEERING",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .rotationCap,
            footerHint:       "ROTATION LIMIT ACTIVE",
            imageName:        "mechanic_rotations",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "COMPONENT STRESS",
                es: "ESTRÉS DE COMPONENTES",
                fr: "STRESS DES COMPOSANTS",
                ja: "コンポーネントストレス"
            ),
            localizedBody: LocalizedText(
                en: "Field alert: relay units in the next sector have been over-rotated and are near tolerance limits. Each rotation you take may be the last.",
                es: "Alerta de campo: las unidades de retransmisor del siguiente sector han sufrido rotaciones excesivas y están cerca de sus límites de tolerancia. Cada rotación que hagas puede ser la última.",
                fr: "Alerte terrain : les unités relais du prochain secteur ont été trop tournées et approchent de leurs limites de tolérance. Chaque rotation que tu effectues peut être la dernière.",
                ja: "フィールドアラート：次のセクターのリレーユニットが過回転により許容限界に近づいています。あなたが行う各回転が最後になるかもしれません。"
            )
        ),

        StoryBeat(
            id:               "mechanic_overloaded",
            title:            "RELAY OVERLOAD",
            body:             "High-resistance nodes detected. These relays require a two-stage command to rotate — arm first, then execute. Rushing will lose the signal.",
            source:           "ENGINEERING",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .overloaded,
            footerHint:       "TWO-TAP PROTOCOL ACTIVE",
            imageName:        "mechanic_interference_2",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "RELAY OVERLOAD",
                es: "SOBRECARGA DE RETRANSMISOR",
                fr: "SURCHARGE DU RELAIS",
                ja: "リレー過負荷"
            ),
            localizedBody: LocalizedText(
                en: "High-resistance nodes detected. These relays require a two-stage command to rotate — arm first, then execute. Rushing will lose the signal.",
                es: "Nodos de alta resistencia detectados. Estos retransmisores requieren un comando en dos etapas para rotar: primero armar, luego ejecutar. Apresurarse hará perder la señal.",
                fr: "Nœuds à haute résistance détectés. Ces relais nécessitent une commande en deux étapes pour tourner — armer d'abord, puis exécuter. Se précipiter, c'est perdre le signal.",
                ja: "高抵抗ノードを検出。これらのリレーは回転に2段階コマンドが必要です — まずアーム、次に実行。急ぐとシグナルを失います。"
            )
        ),

        StoryBeat(
            id:               "mechanic_autoDrift",
            title:            "NODE DRIFT",
            body:             "Advanced sector warning: some nodes won't hold orientation under electromagnetic pressure. Stabilize the full route before they shift back.",
            source:           "COMMAND",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .autoDrift,
            accentHex:        "7EC8E3",
            footerHint:       "AUTO-DRIFT ACTIVE",
            imageName:        "mechanic_autorotate",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "NODE DRIFT",
                es: "DERIVA DE NODO",
                fr: "DÉRIVE DE NŒUD",
                ja: "ノードドリフト"
            ),
            localizedBody: LocalizedText(
                en: "Advanced sector warning: some nodes won't hold orientation under electromagnetic pressure. Stabilize the full route before they shift back.",
                es: "Advertencia de sector avanzado: algunos nodos no mantienen la orientación bajo presión electromagnética. Estabiliza la ruta completa antes de que se desplacen de nuevo.",
                fr: "Avertissement secteur avancé : certains nœuds ne maintiennent pas leur orientation sous pression électromagnétique. Stabilise la route complète avant qu'ils se décalent à nouveau.",
                ja: "高度セクター警告：一部のノードは電磁圧下で向きを保てません。再びずれる前にルート全体を安定させてください。"
            )
        ),

        StoryBeat(
            id:               "mechanic_oneWayRelay",
            title:            "DIRECTED SIGNAL",
            body:             "New relay architecture ahead: some nodes only accept signal from a fixed inbound direction. Read the grid carefully before committing.",
            source:           "ENGINEERING",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .oneWayRelay,
            footerHint:       "ONE-WAY RELAY ACTIVE",
            imageName:        "one_way_relay",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "DIRECTED SIGNAL",
                es: "SEÑAL DIRIGIDA",
                fr: "SIGNAL DIRIGÉ",
                ja: "指向性シグナル"
            ),
            localizedBody: LocalizedText(
                en: "New relay architecture ahead: some nodes only accept signal from a fixed inbound direction. Read the grid carefully before committing.",
                es: "Nueva arquitectura de retransmisor por delante: algunos nodos solo aceptan señal desde una dirección de entrada fija. Lee la cuadrícula cuidadosamente antes de comprometerte.",
                fr: "Nouvelle architecture de relais à venir : certains nœuds n'acceptent le signal que depuis une direction d'entrée fixe. Lis la grille attentivement avant de t'engager.",
                ja: "新しいリレーアーキテクチャが前方に：一部のノードは固定された入力方向からのみシグナルを受信します。確定前にグリッドをよく読んでください。"
            )
        ),

        StoryBeat(
            id:               "mechanic_fragileTile",
            title:            "NETWORK DECAY",
            body:             "Relay degradation detected. Some nodes can only sustain the energy field a limited number of times before permanent burnout. Route efficiently.",
            source:           "MISSION CONTROL",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .fragileTile,
            footerHint:       "FRAGILE RELAY ACTIVE",
            imageName:        "network_decay",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "NETWORK DECAY",
                es: "DEGRADACIÓN DE RED",
                fr: "DÉGRADATION DU RÉSEAU",
                ja: "ネットワーク劣化"
            ),
            localizedBody: LocalizedText(
                en: "Relay degradation detected. Some nodes can only sustain the energy field a limited number of times before permanent burnout. Route efficiently.",
                es: "Degradación de retransmisor detectada. Algunos nodos solo pueden soportar el campo energético un número limitado de veces antes del fallo permanente. Enruta de forma eficiente.",
                fr: "Dégradation de relais détectée. Certains nœuds ne peuvent supporter le champ énergétique qu'un nombre limité de fois avant la panne définitive. Route efficacement.",
                ja: "リレーの劣化を検出。一部のノードは永久焼損前に限られた回数しかエネルギー場に耐えられません。効率的にルーティングしてください。"
            )
        ),

        StoryBeat(
            id:               "mechanic_chargeGate",
            title:            "LOCKED SUBSYSTEM",
            body:             "Encrypted relay nodes ahead. They require repeated charge cycles before they conduct. Keep the signal flowing until the gate opens.",
            source:           "ENGINEERING",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .chargeGate,
            footerHint:       "CHARGE GATE ACTIVE",
            imageName:        "locked_subsystem",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "LOCKED SUBSYSTEM",
                es: "SUBSISTEMA BLOQUEADO",
                fr: "SOUS-SYSTÈME VERROUILLÉ",
                ja: "ロックされたサブシステム"
            ),
            localizedBody: LocalizedText(
                en: "Encrypted relay nodes ahead. They require repeated charge cycles before they conduct. Keep the signal flowing until the gate opens.",
                es: "Nodos de retransmisor cifrados por delante. Requieren ciclos de carga repetidos antes de conducir la señal. Mantén el flujo de señal hasta que la compuerta se abra.",
                fr: "Nœuds relais chiffrés à venir. Ils nécessitent des cycles de charge répétés avant de conduire. Maintiens le flux de signal jusqu'à l'ouverture de la grille.",
                ja: "暗号化されたリレーノードが前方に。導通前に複数の充電サイクルが必要です。ゲートが開くまでシグナルを流し続けてください。"
            )
        ),

        StoryBeat(
            id:               "mechanic_interferenceZone",
            title:            "SIGNAL NOISE",
            body:             "Electromagnetic interference confirmed in the deep sector. Visual readings on some nodes may be corrupted. Trust your routing logic, not your eyes.",
            source:           "MISSION CONTROL",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .interferenceZone,
            accentHex:        "4B70DD",
            footerHint:       "INTERFERENCE ZONE ACTIVE",
            imageName:        "mechanic_interference_1",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "SIGNAL NOISE",
                es: "RUIDO DE SEÑAL",
                fr: "BRUIT DE SIGNAL",
                ja: "シグナルノイズ"
            ),
            localizedBody: LocalizedText(
                en: "Electromagnetic interference confirmed in the deep sector. Visual readings on some nodes may be corrupted. Trust your routing logic, not your eyes.",
                es: "Interferencia electromagnética confirmada en el sector profundo. Las lecturas visuales en algunos nodos pueden estar corruptas. Confía en tu lógica de enrutamiento, no en tus ojos.",
                fr: "Interférence électromagnétique confirmée dans le secteur profond. Les lectures visuelles de certains nœuds peuvent être corrompues. Fais confiance à ta logique de routage, pas à tes yeux.",
                ja: "深部セクターで電磁干渉を確認。一部のノードの視覚情報が破損している可能性があります。目ではなくルーティングロジックを信じてください。"
            )
        ),

        StoryBeat(
            id:               "mechanic_timeLimit",
            title:            "CLOCK ACTIVE",
            body:             "Mission window is limited. Relay protocols in this sector auto-reset if you exceed the operation time. Route before the clock expires.",
            source:           "MISSION CONTROL",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .timeLimit,
            accentHex:        "FF6A3D",
            footerHint:       "TIME LIMIT ACTIVE",
            imageName:        "mechanic_timer",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "CLOCK ACTIVE",
                es: "RELOJ ACTIVADO",
                fr: "HORLOGE ACTIVE",
                ja: "時計稼働"
            ),
            localizedBody: LocalizedText(
                en: "Mission window is limited. Relay protocols in this sector auto-reset if you exceed the operation time. Route before the clock expires.",
                es: "La ventana de misión es limitada. Los protocolos de retransmisor de este sector se reinician automáticamente si superas el tiempo de operación. Traza la ruta antes de que el reloj expire.",
                fr: "La fenêtre de mission est limitée. Les protocoles relais de ce secteur se réinitialisent automatiquement si tu dépasses le temps d'opération. Trace la route avant que le chrono n'expire.",
                ja: "ミッションウィンドウは限られています。このセクターのリレープロトコルは作戦時間を超過すると自動リセットされます。時計が切れる前にルーティングしてください。"
            )
        ),

        // ── Generic mechanic atmosphere beat (fires after specific beat is seen) ──

        StoryBeat(
            id:             "story_mechanic_risk",
            title:          "SYSTEMS AHEAD",
            body:           "The systems ahead are no longer designed for comfort. They are designed to endure.",
            source:         "ENGINEERING",
            trigger:        .mechanicUnlocked,
            accentHex:      "FF6A3D",
            imageName:      "intro_repair",
            priority:       70,               // fires only after specific beats are seen
            onceOnly:       true,             // one-time fallback — fires only when no specific beat exists for a mechanic
            localizedTitle: LocalizedText(
                en: "SYSTEMS AHEAD",
                es: "SISTEMAS AVANZADOS",
                fr: "SYSTÈMES AVANCÉS",
                ja: "前方にシステム"
            ),
            localizedBody: LocalizedText(
                en: "The systems ahead are no longer designed for comfort. They are designed to endure.",
                es: "Los sistemas que vienen a continuación ya no están diseñados para ser cómodos. Están diseñados para resistir.",
                fr: "Les systèmes qui suivent ne sont plus conçus pour être confortables. Ils sont conçus pour résister.",
                ja: "前方のシステムはもはや快適さのために設計されていません。耐久性のために設計されています。"
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // PASS UNLOCKED — official authorization per sector (1–7)
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:               "story_lunar_pass_granted",
            title:            "LUNAR CLEARANCE",
            body:             "Your training phase is over. From now on, every mistake will cost more.",
            source:           "COMMAND",
            trigger:          .passUnlocked,
            requiredSectorID: 1,
            accentHex:        "D9E7D8",
            footerHint:       "LUNAR APPROACH UNLOCKED",
            imageName:        "sector_lunar_unlock",
            priority:         30,
            sequenceGroup:    "lunar_unlock",
            orderInSequence:  1,
            localizedTitle: LocalizedText(
                en: "LUNAR CLEARANCE",
                es: "PASO LUNAR",
                fr: "ACCÈS LUNAIRE",
                ja: "月面クリアランス"
            ),
            localizedBody: LocalizedText(
                en: "Your training phase is over. From now on, every mistake will cost more.",
                es: "Tu entrenamiento ha terminado. A partir de ahora, cada error costará más.",
                fr: "Ta phase d'entraînement est terminée. À partir de maintenant, chaque erreur coûtera plus cher.",
                ja: "訓練フェーズは終了です。今後、すべてのミスはより大きな代償を伴います。"
            )
        ),

        StoryBeat(
            id:               "story_mars_unlock",
            title:            "MARS AUTHORITY",
            body:             "This is no longer orbital maintenance. This is frontier engineering.",
            source:           "COMMAND",
            trigger:          .passUnlocked,
            requiredSectorID: 2,
            accentHex:        "FF6A3D",
            footerHint:       "MARS SECTOR UNLOCKED",
            imageName:        "sector_mars_unlock",
            priority:         30,
            sequenceGroup:    "mars_unlock",
            orderInSequence:  1,
            localizedTitle: LocalizedText(
                en: "MARS AUTHORITY",
                es: "PASO A MARTE",
                fr: "ACCÈS À MARS",
                ja: "火星権限"
            ),
            localizedBody: LocalizedText(
                en: "This is no longer orbital maintenance. This is frontier engineering.",
                es: "Esto ya no es mantenimiento orbital. Es ingeniería de frontera.",
                fr: "Ce n'est plus de la maintenance orbitale. C'est de l'ingénierie de frontière.",
                ja: "これはもはや軌道メンテナンスではありません。フロンティアエンジニアリングです。"
            )
        ),

        StoryBeat(
            id:               "pass_sector_3",
            title:            "BELT TRANSIT",
            body:             "Mars ops complete. Asteroid Belt clearance issued. Routing through the debris field means working around gaps — no straight paths exist in that corridor.",
            source:           "MISSION CONTROL",
            trigger:          .passUnlocked,
            requiredSectorID: 3,
            accentHex:        "FFB800",
            footerHint:       "ASTEROID BELT UNLOCKED",
            imageName:        "asteroid_belt_transit",
            priority:         30,
            localizedTitle: LocalizedText(
                en: "BELT TRANSIT",
                es: "TRÁNSITO DE CINTURÓN",
                fr: "TRANSIT DE LA CEINTURE",
                ja: "ベルト通過"
            ),
            localizedBody: LocalizedText(
                en: "Mars ops complete. Asteroid Belt clearance issued. Routing through the debris field means working around gaps — no straight paths exist in that corridor.",
                es: "Operaciones en Marte completadas. Autorización emitida para el Cinturón de Asteroides. Trazar rutas entre escombros implica trabajar con huecos: aquí no existen caminos directos.",
                fr: "Opérations martiennes terminées. Autorisation pour la Ceinture d'astéroïdes accordée. Tracer des routes dans le champ de débris, c'est travailler avec des lacunes — aucun chemin droit n'existe dans ce couloir.",
                ja: "火星作戦完了。小惑星帯クリアランス発行。デブリフィールドを通じたルーティングはギャップを回避する作業を意味します — この回廊に直線パスは存在しません。"
            )
        ),

        StoryBeat(
            id:               "pass_sector_4",
            title:            "GIANT APPROACH",
            body:             "Belt cleared. Jupiter Relay access authorized. Atmospheric interference at this distance makes routing unpredictable. Your record earned you this clearance.",
            source:           "MISSION CONTROL",
            trigger:          .passUnlocked,
            requiredSectorID: 4,
            accentHex:        "D4A055",
            footerHint:       "JUPITER RELAY UNLOCKED",
            imageName:        "giant_approach",
            priority:         30,
            localizedTitle: LocalizedText(
                en: "GIANT APPROACH",
                es: "APROXIMACIÓN AL GIGANTE",
                fr: "APPROCHE DU GÉANT",
                ja: "巨星接近"
            ),
            localizedBody: LocalizedText(
                en: "Belt cleared. Jupiter Relay access authorized. Atmospheric interference at this distance makes routing unpredictable. Your record earned you this clearance.",
                es: "Cinturón despejado. Acceso al Relé Júpiter autorizado. La interferencia atmosférica a esta distancia hace que el enrutamiento sea impredecible. Tu historial te ha ganado esta oportunidad.",
                fr: "Ceinture dégagée. Accès au relais Jupiter autorisé. Les interférences atmosphériques à cette distance rendent le routage imprévisible. Ton bilan t'a valu cette accréditation.",
                ja: "ベルト通過完了。木星リレーアクセス許可。この距離での大気干渉はルーティングを予測不能にします。あなたの実績がこのクリアランスを獲得しました。"
            )
        ),

        StoryBeat(
            id:               "pass_sector_5",
            title:            "RING TRANSIT",
            body:             "Jupiter array online. Saturn Ring clearance approved. The ring system's interference channels have broken other engineers. You've earned the right to try.",
            source:           "MISSION CONTROL",
            trigger:          .passUnlocked,
            requiredSectorID: 5,
            accentHex:        "E4C87A",
            footerHint:       "SATURN RING SECTOR UNLOCKED",
            imageName:        "ring_transit",
            priority:         30,
            localizedTitle: LocalizedText(
                en: "RING TRANSIT",
                es: "TRÁNSITO DE ANILLOS",
                fr: "TRANSIT DES ANNEAUX",
                ja: "リング通過"
            ),
            localizedBody: LocalizedText(
                en: "Jupiter array online. Saturn Ring clearance approved. The ring system's interference channels have broken other engineers. You've earned the right to try.",
                es: "Red Júpiter en línea. Autorización de los anillos de Saturno aprobada. Los canales de interferencia del sistema de anillos han quebrado a otros ingenieros. Tú te has ganado el derecho a intentarlo.",
                fr: "Réseau Jupiter en ligne. Autorisation pour les anneaux de Saturne accordée. Les canaux d'interférence du système d'anneaux ont brisé d'autres ingénieurs. Tu as mérité le droit d'essayer.",
                ja: "木星アレイオンライン。土星リングクリアランス承認。リングシステムの干渉チャネルは他のエンジニアを挫折させました。あなたは挑戦する権利を得ました。"
            )
        ),

        StoryBeat(
            id:               "pass_sector_6",
            title:            "VOID CLEARANCE",
            body:             "Saturn network stabilized. Uranus Void access granted. Deep space protocol applies. Signal degradation at this range will test instincts built over months of deployment.",
            source:           "MISSION CONTROL",
            trigger:          .passUnlocked,
            requiredSectorID: 6,
            accentHex:        "7EC8E3",
            footerHint:       "URANUS VOID UNLOCKED",
            imageName:        "void_clearance",
            priority:         30,
            localizedTitle: LocalizedText(
                en: "VOID CLEARANCE",
                es: "AUTORIZACIÓN DEL VACÍO",
                fr: "ACCÈS AU VIDE",
                ja: "ボイドクリアランス"
            ),
            localizedBody: LocalizedText(
                en: "Saturn network stabilized. Uranus Void access granted. Deep space protocol applies. Signal degradation at this range will test instincts built over months of deployment.",
                es: "Red Saturno estabilizada. Acceso al Vacío de Urano concedido. Se aplica el protocolo de espacio profundo. La degradación de señal a esta distancia pondrá a prueba los reflejos forjados durante meses de despliegue.",
                fr: "Réseau Saturne stabilisé. Accès au Vide d'Uranus accordé. Protocole d'espace profond en vigueur. La dégradation du signal à cette portée mettra à l'épreuve les réflexes acquis au fil de mois de déploiement.",
                ja: "土星ネットワーク安定。天王星ボイドアクセス許可。深宇宙プロトコル適用。この距離でのシグナル劣化は、数ヶ月の配備で培った直感を試します。"
            )
        ),

        StoryBeat(
            id:               "pass_sector_7",
            title:            "DEEP ACCESS",
            body:             "Uranus sector live. Neptune Deep authorization confirmed. You have gone further than any signal engineer before you. What lies ahead is genuinely uncharted.",
            source:           "MISSION CONTROL",
            trigger:          .passUnlocked,
            requiredSectorID: 7,
            accentHex:        "4B70DD",
            footerHint:       "NEPTUNE DEEP UNLOCKED",
            imageName:        "deep_space_network",
            priority:         30,
            localizedTitle: LocalizedText(
                en: "DEEP ACCESS",
                es: "ACCESO PROFUNDO",
                fr: "ACCÈS EN PROFONDEUR",
                ja: "ディープアクセス"
            ),
            localizedBody: LocalizedText(
                en: "Uranus sector live. Neptune Deep authorization confirmed. You have gone further than any signal engineer before you. What lies ahead is genuinely uncharted.",
                es: "Sector Urano activo. Autorización para el Profundo Neptuno confirmada. Has llegado más lejos que cualquier otro ingeniero de señales. Lo que viene ahora es genuinamente territorio inexplorado.",
                fr: "Secteur Uranus en ligne. Autorisation pour Neptune Profond confirmée. Tu es allé plus loin qu'aucun autre ingénieur signal avant toi. Ce qui t'attend est véritablement inexploré.",
                ja: "天王星セクター稼働中。海王星ディープ認可確認。あなたはどのシグナルエンジニアよりも遠くへ到達しました。前方にあるものは真に未踏の領域です。"
            )
        ),

        StoryBeat(
            id:               "pass_sector_8",
            title:            "FROZEN ACCESS",
            body:             "Neptune sector live. Kuiper Belt authorization confirmed. Beyond the known planets lies a frozen expanse of debris and ancient ice. Relay integrity will be tested like never before.",
            source:           "MISSION CONTROL",
            trigger:          .passUnlocked,
            requiredSectorID: 8,
            accentHex:        "A8D8EA",
            footerHint:       "KUIPER BELT UNLOCKED",
            imageName:        "kuiper_belt_hero",
            priority:         30,
            localizedTitle: LocalizedText(
                en: "FROZEN ACCESS",
                es: "ACCESO HELADO",
                fr: "ACCÈS GELÉ",
                ja: "凍結アクセス"
            ),
            localizedBody: LocalizedText(
                en: "Neptune sector live. Kuiper Belt authorization confirmed. Beyond the known planets lies a frozen expanse of debris and ancient ice. Relay integrity will be tested like never before.",
                es: "Sector Neptuno activo. Autorización para el Cinturón de Kuiper confirmada. Más allá de los planetas conocidos se extiende una vasta extensión helada de escombros y hielo ancestral. La integridad de los retransmisores será puesta a prueba como nunca.",
                fr: "Secteur Neptune actif. Autorisation pour la Ceinture de Kuiper confirmée. Au-delà des planètes connues s'étend une vaste étendue gelée de débris et de glace ancestrale. L'intégrité des relais sera mise à l'épreuve comme jamais.",
                ja: "海王星セクター稼働中。カイパーベルト認可確認。既知の惑星の彼方には、デブリと太古の氷の凍てつく広がりがあります。リレーの完全性がかつてないほど試されます。"
            )
        ),

        StoryBeat(
            id:               "pass_sector_9",
            title:            "FINAL FRONTIER",
            body:             "Kuiper Belt sector live. Oort Cloud authorization confirmed. This is it — the outermost boundary of the solar system. No engineer has ever routed signals this far. Every relay counts.",
            source:           "MISSION CONTROL",
            trigger:          .passUnlocked,
            requiredSectorID: 9,
            accentHex:        "9B72CF",
            footerHint:       "OORT CLOUD UNLOCKED",
            imageName:        "oort_cloud_hero",
            priority:         30,
            localizedTitle: LocalizedText(
                en: "FINAL FRONTIER",
                es: "ÚLTIMA FRONTERA",
                fr: "DERNIÈRE FRONTIÈRE",
                ja: "最後のフロンティア"
            ),
            localizedBody: LocalizedText(
                en: "Kuiper Belt sector live. Oort Cloud authorization confirmed. This is it — the outermost boundary of the solar system. No engineer has ever routed signals this far. Every relay counts.",
                es: "Sector Cinturón de Kuiper activo. Autorización para la Nube de Oort confirmada. Este es el momento — el límite más exterior del sistema solar. Ningún ingeniero ha enrutado señales tan lejos. Cada retransmisor cuenta.",
                fr: "Secteur Ceinture de Kuiper actif. Autorisation pour le Nuage d'Oort confirmée. C'est le moment — la frontière la plus lointaine du système solaire. Aucun ingénieur n'a jamais routé des signaux aussi loin. Chaque relais compte.",
                ja: "カイパーベルトセクター稼働中。オールトの雲認可確認。これが太陽系の最外縁です。この距離までシグナルをルーティングしたエンジニアはいません。すべてのリレーが重要です。"
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // ENTERING NEW SECTOR — destination briefing for sectors 2–10
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:               "story_lunar_intro",
            title:            "LUNAR APPROACH",
            body:             "Lunar systems are older. Less redundancy. More distance. More risk.",
            source:           "COMMAND",
            trigger:          .enteringNewSector,
            requiredSectorID: 2,
            accentHex:        "D9E7D8",
            footerHint:       "SECTOR 2 — LUNAR APPROACH",
            imageName:        "sector_lunar_intro",
            priority:         40,
            sequenceGroup:    "lunar_intro",
            orderInSequence:  1,
            localizedTitle: LocalizedText(
                en: "LUNAR APPROACH",
                es: "LLEGADA LUNAR",
                fr: "APPROCHE LUNAIRE",
                ja: "月面接近"
            ),
            localizedBody: LocalizedText(
                en: "Lunar systems are older. Less redundancy. More distance. More risk.",
                es: "Los sistemas lunares son más antiguos. Menos redundancia. Más distancia. Más riesgo.",
                fr: "Les systèmes lunaires sont plus anciens. Moins de redondance. Plus de distance. Plus de risque.",
                ja: "月面システムはより古い。冗長性が少ない。距離が遠い。リスクが高い。"
            )
        ),

        StoryBeat(
            id:               "enter_sector_3",
            title:            "MARS OPS",
            body:             "Red Planet infrastructure is decades old. You'll find legacy routing patterns and modern failure modes in the same grid. Patience is a tool here.",
            source:           "ENGINEERING",
            trigger:          .enteringNewSector,
            requiredSectorID: 3,
            accentHex:        "FF6A3D",
            footerHint:       "SECTOR 3 — MARS SECTOR",
            imageName:        "sector_mars_intro",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "MARS OPS",
                es: "OPERACIONES EN MARTE",
                fr: "OPÉRATIONS SUR MARS",
                ja: "火星作戦"
            ),
            localizedBody: LocalizedText(
                en: "Red Planet infrastructure is decades old. You'll find legacy routing patterns and modern failure modes in the same grid. Patience is a tool here.",
                es: "La infraestructura del planeta rojo tiene décadas de antigüedad. Encontrarás patrones de enrutamiento heredados y modos de fallo modernos en la misma red. Aquí la paciencia es una herramienta.",
                fr: "L'infrastructure de la planète rouge a des décennies d'existence. Tu trouveras des schémas de routage hérités et des modes de défaillance modernes dans la même grille. La patience est un outil ici.",
                ja: "赤い惑星のインフラは数十年前のものです。同じグリッドにレガシーなルーティングパターンと最新の障害モードが混在しています。ここでは忍耐がツールです。"
            )
        ),

        StoryBeat(
            id:               "enter_sector_4",
            title:            "BELT ENTRY",
            body:             "No straight paths in the debris field. Routes loop around dead relays and drifting rock. Adapt your plan as you read each grid — the belt doesn't forgive rigid thinking.",
            source:           "COMMAND",
            trigger:          .enteringNewSector,
            requiredSectorID: 4,
            accentHex:        "FFB800",
            footerHint:       "SECTOR 4 — ASTEROID BELT",
            imageName:        "asteroid_belt_entry",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "BELT ENTRY",
                es: "ENTRADA AL CINTURÓN",
                fr: "ENTRÉE DANS LA CEINTURE",
                ja: "ベルト突入"
            ),
            localizedBody: LocalizedText(
                en: "No straight paths in the debris field. Routes loop around dead relays and drifting rock. Adapt your plan as you read each grid — the belt doesn't forgive rigid thinking.",
                es: "No hay caminos directos en el campo de escombros. Las rutas rodean retransmisores inactivos y rocas a la deriva. Adapta tu plan según leas cada cuadrícula: el cinturón no perdona el pensamiento rígido.",
                fr: "Pas de chemin direct dans le champ de débris. Les routes contournent les relais morts et les roches en dérive. Adapte ton plan en lisant chaque grille — la ceinture ne pardonne pas la rigidité.",
                ja: "デブリフィールドに直線パスはありません。ルートは停止したリレーと漂流する岩を迂回します。各グリッドを読みながらプランを適応させてください — ベルトは硬直した思考を許しません。"
            )
        ),

        StoryBeat(
            id:               "enter_sector_5",
            title:            "GAS GIANT GRID",
            body:             "Jupiter's relay array spans distances you haven't worked before. Signal latency is measurable at this range. Precision counts more than speed.",
            source:           "COMMAND",
            trigger:          .enteringNewSector,
            requiredSectorID: 5,
            accentHex:        "D4A055",
            footerHint:       "SECTOR 5 — JUPITER RELAY",
            imageName:        "gas_giant_grid",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "GAS GIANT GRID",
                es: "RED DEL GIGANTE GASEOSO",
                fr: "RÉSEAU DU GÉANT GAZEUX",
                ja: "ガス巨星グリッド"
            ),
            localizedBody: LocalizedText(
                en: "Jupiter's relay array spans distances you haven't worked before. Signal latency is measurable at this range. Precision counts more than speed.",
                es: "La red de retransmisores de Júpiter cubre distancias con las que no habías trabajado antes. La latencia de señal es medible a esta distancia. La precisión vale más que la velocidad.",
                fr: "Le réseau de relais de Jupiter couvre des distances que tu n'as jamais eu à gérer. La latence du signal est mesurable à cette portée. La précision compte plus que la vitesse.",
                ja: "木星のリレーアレイは、これまでに経験したことのない距離に及びます。この距離ではシグナル遅延が測定可能です。速度より精度が重要です。"
            )
        ),

        StoryBeat(
            id:               "enter_sector_6",
            title:            "RING SYSTEM",
            body:             "Saturn's rings create interference channels that block and redirect signal in unpredictable ways. Study each grid before committing. Nothing here is what it appears.",
            source:           "ENGINEERING",
            trigger:          .enteringNewSector,
            requiredSectorID: 6,
            accentHex:        "E4C87A",
            footerHint:       "SECTOR 6 — SATURN RING",
            imageName:        "ring_system",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "RING SYSTEM",
                es: "SISTEMA DE ANILLOS",
                fr: "SYSTÈME D'ANNEAUX",
                ja: "リングシステム"
            ),
            localizedBody: LocalizedText(
                en: "Saturn's rings create interference channels that block and redirect signal in unpredictable ways. Study each grid before committing. Nothing here is what it appears.",
                es: "Los anillos de Saturno crean canales de interferencia que bloquean y redirigen la señal de manera impredecible. Estudia cada cuadrícula antes de comprometerte. Aquí nada es lo que parece.",
                fr: "Les anneaux de Saturne créent des canaux d'interférence qui bloquent et redirigent le signal de manière imprévisible. Étudie chaque grille avant de t'engager. Rien n'est ce qu'il paraît ici.",
                ja: "土星のリングは、予測不能な方法でシグナルをブロックしリダイレクトする干渉チャネルを作り出します。確定前に各グリッドを研究してください。ここでは何も見た通りではありません。"
            )
        ),

        StoryBeat(
            id:               "enter_sector_7",
            title:            "DEEP VOID",
            body:             "Uranus sector relays operate at the edge of the inner network. Every node matters — there is no redundancy at this distance. One unresolved failure propagates outward.",
            source:           "COMMAND",
            trigger:          .enteringNewSector,
            requiredSectorID: 7,
            accentHex:        "7EC8E3",
            footerHint:       "SECTOR 7 — URANUS VOID",
            imageName:        "deep_void",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "DEEP VOID",
                es: "VACÍO PROFUNDO",
                fr: "VIDE PROFOND",
                ja: "ディープボイド"
            ),
            localizedBody: LocalizedText(
                en: "Uranus sector relays operate at the edge of the inner network. Every node matters — there is no redundancy at this distance. One unresolved failure propagates outward.",
                es: "Los retransmisores del sector Urano operan en el límite de la red interior. Cada nodo importa: no hay redundancia a esta distancia. Un fallo sin resolver se propaga hacia afuera.",
                fr: "Les relais du secteur Uranus fonctionnent à la limite du réseau intérieur. Chaque nœud compte — il n'y a aucune redondance à cette distance. Une défaillance non résolue se propage vers l'extérieur.",
                ja: "天王星セクターのリレーは内部ネットワークの端で稼働しています。すべてのノードが重要です — この距離に冗長性はありません。一つの未解決の障害が外側へ伝播します。"
            )
        ),

        StoryBeat(
            id:               "enter_sector_8",
            title:            "DEEP SPACE",
            body:             "Neptune's relays are the frontier of the inner solar system. What you build here carries our signal to its edge — and beyond, if you survive.",
            source:           "COMMAND",
            trigger:          .enteringNewSector,
            requiredSectorID: 8,
            accentHex:        "4B70DD",
            footerHint:       "SECTOR 8 — NEPTUNE DEEP",
            imageName:        "deep_space_network",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "DEEP SPACE",
                es: "ESPACIO PROFUNDO",
                fr: "ESPACE PROFOND",
                ja: "ディープスペース"
            ),
            localizedBody: LocalizedText(
                en: "Neptune's relays are the frontier of the inner solar system. What you build here carries our signal to its edge — and beyond, if you survive.",
                es: "Los retransmisores de Neptuno son la frontera del sistema solar interior. Lo que construyas aquí llevará nuestra señal hasta su límite — y más allá, si sobrevives.",
                fr: "Les relais de Neptune sont la frontière du système solaire intérieur. Ce que tu bâtis ici porte notre signal jusqu'à sa limite — et au-delà, si tu survis.",
                ja: "海王星のリレーは内部太陽系のフロンティアです。ここで構築するものが私たちのシグナルをその端まで — そして生き残れば、その先へ運びます。"
            )
        ),

        StoryBeat(
            id:               "enter_sector_9",
            title:            "FROZEN EXPANSE",
            body:             "Kuiper Belt: a frozen graveyard of ancient debris between the planets and the void. Relays here must withstand extreme cold and signal degradation. Every connection is fragile.",
            source:           "ENGINEERING",
            trigger:          .enteringNewSector,
            requiredSectorID: 9,
            accentHex:        "A8D8EA",
            footerHint:       "SECTOR 9 — KUIPER BELT",
            imageName:        "kuiper_approach",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "FROZEN EXPANSE",
                es: "EXTENSIÓN HELADA",
                fr: "ÉTENDUE GELÉE",
                ja: "凍てつく広がり"
            ),
            localizedBody: LocalizedText(
                en: "Kuiper Belt: a frozen graveyard of ancient debris between the planets and the void. Relays here must withstand extreme cold and signal degradation. Every connection is fragile.",
                es: "Cinturón de Kuiper: un cementerio helado de escombros ancestrales entre los planetas y el vacío. Los retransmisores aquí deben resistir el frío extremo y la degradación de señal. Cada conexión es frágil.",
                fr: "Ceinture de Kuiper : un cimetière gelé de débris ancestraux entre les planètes et le vide. Les relais ici doivent résister au froid extrême et à la dégradation du signal. Chaque connexion est fragile.",
                ja: "カイパーベルト：惑星とボイドの間にある太古のデブリの凍てつく墓場。ここのリレーは極度の寒さとシグナル劣化に耐えなければなりません。すべての接続が脆いのです。"
            )
        ),

        StoryBeat(
            id:               "enter_sector_10",
            title:            "THE FINAL FRONTIER",
            body:             "Oort Cloud: the outermost boundary of the solar system. A vast shell of comets and frozen worlds. If you can route signal here, humanity's reach becomes truly interstellar. This is your legacy.",
            source:           "MISSION CONTROL",
            trigger:          .enteringNewSector,
            requiredSectorID: 10,
            accentHex:        "9B72CF",
            footerHint:       "SECTOR 10 — OORT CLOUD",
            imageName:        "oort_approach",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "THE FINAL FRONTIER",
                es: "LA ÚLTIMA FRONTERA",
                fr: "LA DERNIÈRE FRONTIÈRE",
                ja: "最後のフロンティア"
            ),
            localizedBody: LocalizedText(
                en: "Oort Cloud: the outermost boundary of the solar system. A vast shell of comets and frozen worlds. If you can route signal here, humanity's reach becomes truly interstellar. This is your legacy.",
                es: "Nube de Oort: el límite más exterior del sistema solar. Una vasta capa de cometas y mundos helados. Si logras enrutar la señal aquí, el alcance de la humanidad se vuelve verdaderamente interestelar. Este es tu legado.",
                fr: "Nuage d'Oort : la frontière la plus lointaine du système solaire. Une vaste coquille de comètes et de mondes gelés. Si tu peux router le signal ici, la portée de l'humanité devient véritablement interstellaire. C'est ton héritage.",
                ja: "オールトの雲：太陽系の最外縁。彗星と凍てつく世界の広大な殻。ここでシグナルをルーティングできれば、人類の到達範囲は真に恒星間となります。これがあなたの遺産です。"
            )
        ),
    ]
}
