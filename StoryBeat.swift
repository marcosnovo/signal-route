import SwiftUI

// MARK: - LocalizedText

/// Trilingual string container for narrative content in story beats.
/// Falls back to `en` when the requested language is unavailable.
struct LocalizedText: Codable, Equatable {
    let en: String
    let es: String
    let fr: String

    func text(for language: AppLanguage) -> String {
        switch language {
        case .en: return en
        case .es: return es
        case .fr: return fr
        }
    }
}

// MARK: - StoryTrigger

/// The in-game moment that causes a story beat to surface.
enum StoryTrigger: String, Codable, Equatable, CaseIterable {
    case firstLaunch            // app opened for the very first time
    case postOnboarding         // intro mission completed
    case firstMissionReady      // player is cleared to begin their first real mission
    case firstMissionComplete   // first regular mission won
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
                fr: "SIGNAL PERDU"
            ),
            localizedBody: LocalizedText(
                en: "Orbital routes are failing. Stations can no longer maintain stability on their own. They need you.",
                es: "Las rutas orbitales están fallando. Las estaciones no pueden mantener la estabilidad por sí solas. Te necesitan.",
                fr: "Les routes orbitales sont en panne. Les stations ne peuvent plus maintenir leur stabilité seules. Elles ont besoin de toi."
            )
        ),

        StoryBeat(
            id:             "story_intro_03",
            title:          "YOUR MISSION",
            body:           "Restore the network. Prove your precision and earn access to increasingly distant destinations.",
            source:         "CAPT. REYES",
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
                fr: "TA MISSION"
            ),
            localizedBody: LocalizedText(
                en: "Restore the network. Prove your precision and earn access to increasingly distant destinations.",
                es: "Restaura la red. Demuestra tu precisión y obtén acceso a destinos cada vez más lejanos.",
                fr: "Restaure le réseau. Prouve ta précision et obtiens l'accès à des destinations toujours plus lointaines."
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // FIRST MISSION READY (postOnboarding merged here)
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
                fr: "PRÊT À DÉPLOYER"
            ),
            localizedBody: LocalizedText(
                en: "The network responded. You are now cleared for your first mission.",
                es: "La red ha respondido. Ya estás listo para tu primera misión.",
                fr: "Le réseau a répondu. Tu es désormais autorisé à commencer ta première mission."
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
                fr: "SIGNAL STABLE"
            ),
            localizedBody: LocalizedText(
                en: "Small systems first. Longer routes later. Every stable network expands the reach of the next mission.",
                es: "Primero sistemas pequeños. Luego rutas más largas. Cada red estable amplía el alcance de la siguiente misión.",
                fr: "D'abord les petits systèmes. Ensuite les routes plus longues. Chaque réseau stabilisé étend la portée de la mission suivante."
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
                fr: "ORBITE RESTAURÉE"
            ),
            localizedBody: LocalizedText(
                en: "This was never about speed. It was about reliability.",
                es: "No se trataba de velocidad. Se trataba de fiabilidad.",
                fr: "Il ne s'agissait pas de vitesse. Il s'agissait de fiabilité."
            )
        ),

        StoryBeat(
            id:               "sector_2_clear",
            title:            "LUNAR GRID ONLINE",
            body:             "Moon base power grid fully restored. You're ahead of every estimate. The Mars sector relay chain is within reach.",
            source:           "CAPT. REYES",
            trigger:          .sectorComplete,
            requiredSectorID: 2,
            accentHex:        "D9E7D8",
            footerHint:       "MARS SECTOR UNLOCKED",
            imageName:        "sector_lunar_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "LUNAR GRID ONLINE",
                es: "RED LUNAR ACTIVA",
                fr: "RÉSEAU LUNAIRE EN LIGNE"
            ),
            localizedBody: LocalizedText(
                en: "Moon base power grid fully restored. You're ahead of every estimate. The Mars sector relay chain is within reach.",
                es: "La red de energía de la base lunar está completamente restaurada. Superas todas las estimaciones. La cadena de retransmisores del sector Marte está al alcance.",
                fr: "Le réseau électrique de la base lunaire est entièrement rétabli. Tu dépasses toutes les estimations. La chaîne de relais du secteur Mars est à portée."
            )
        ),

        StoryBeat(
            id:               "sector_3_clear",
            title:            "RED PLANET CLEAR",
            body:             "Mars sector relays are running clean for the first time in months. The colonies are noticing. Your record is being watched.",
            source:           "PROGRAM DIRECTOR",
            trigger:          .sectorComplete,
            requiredSectorID: 3,
            accentHex:        "FF6A3D",
            footerHint:       "ASTEROID BELT ROUTE OPEN",
            imageName:        "sector_mars_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "RED PLANET CLEAR",
                es: "MARTE DESPEJADO",
                fr: "MARS DÉGAGÉ"
            ),
            localizedBody: LocalizedText(
                en: "Mars sector relays are running clean for the first time in months. The colonies are noticing. Your record is being watched.",
                es: "Los retransmisores del sector Marte funcionan sin fallos por primera vez en meses. Las colonias lo están notando. Tus resultados están siendo observados.",
                fr: "Les relais du secteur Mars fonctionnent sans problème pour la première fois en plusieurs mois. Les colonies le remarquent. Tes résultats sont scrutés."
            )
        ),

        StoryBeat(
            id:               "sector_4_clear",
            title:            "DEBRIS CLEARED",
            body:             "Routing through the Asteroid Belt was never done before at this speed. You've set a new baseline for network recovery ops.",
            source:           "CAPT. REYES",
            trigger:          .sectorComplete,
            requiredSectorID: 4,
            accentHex:        "FFB800",
            footerHint:       "JUPITER RELAY APPROACH OPEN",
            imageName:        "asteroid_belt_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "DEBRIS CLEARED",
                es: "ESCOMBROS DESPEJADOS",
                fr: "DÉBRIS ÉLIMINÉS"
            ),
            localizedBody: LocalizedText(
                en: "Routing through the Asteroid Belt was never done before at this speed. You've set a new baseline for network recovery ops.",
                es: "Nunca se había trazado una ruta por el Cinturón de Asteroides a esta velocidad. Has establecido un nuevo estándar para las operaciones de recuperación de red.",
                fr: "Aucun routage n'avait jamais traversé la Ceinture d'astéroïdes à cette vitesse. Tu viens de poser un nouveau standard pour les opérations de récupération réseau."
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
                fr: "LE GÉANT EN LIGNE"
            ),
            localizedBody: LocalizedText(
                en: "Jupiter's relay array is fully operational. The gas giant's atmospheric interference couldn't stop you. Outer system access confirmed.",
                es: "El sistema de retransmisores de Júpiter está completamente operativo. La interferencia atmosférica del gigante gaseoso no pudo detenerte. Acceso al sistema exterior confirmado.",
                fr: "Le réseau de relais de Jupiter est pleinement opérationnel. Les interférences atmosphériques du géant gazeux n'ont pas pu t'arrêter. Accès au système extérieur confirmé."
            )
        ),

        StoryBeat(
            id:               "sector_6_clear",
            title:            "RINGS ALIGNED",
            body:             "Signal threading through Saturn's rings — a routing problem once thought unsolvable. You made it routine. Deep space access is imminent.",
            source:           "DR. CHEN",
            trigger:          .sectorComplete,
            requiredSectorID: 6,
            accentHex:        "E4C87A",
            footerHint:       "URANUS VOID SECTOR OPEN",
            imageName:        "saturn_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "RINGS ALIGNED",
                es: "ANILLOS ALINEADOS",
                fr: "ANNEAUX ALIGNÉS"
            ),
            localizedBody: LocalizedText(
                en: "Signal threading through Saturn's rings — a routing problem once thought unsolvable. You made it routine. Deep space access is imminent.",
                es: "Señal enrutada a través de los anillos de Saturno, un problema que antes se consideraba irresoluble. Lo has convertido en algo rutinario. El espacio profundo está al alcance.",
                fr: "Signal traversant les anneaux de Saturne — un problème de routage autrefois jugé insoluble. Tu en as fait une routine. L'espace profond est imminent."
            )
        ),

        StoryBeat(
            id:               "sector_7_clear",
            title:            "VOID NAVIGATED",
            body:             "Uranus sector relays are live. The void between planets no longer means silence — it means signal. You're making history.",
            source:           "PROGRAM DIRECTOR",
            trigger:          .sectorComplete,
            requiredSectorID: 7,
            accentHex:        "7EC8E3",
            footerHint:       "NEPTUNE DEEP SECTOR OPEN",
            imageName:        "uranus_unlock",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "VOID NAVIGATED",
                es: "VACÍO NAVEGADO",
                fr: "LE VIDE TRAVERSÉ"
            ),
            localizedBody: LocalizedText(
                en: "Uranus sector relays are live. The void between planets no longer means silence — it means signal. You're making history.",
                es: "Los retransmisores del sector Urano están activos. El vacío entre planetas ya no significa silencio, significa señal. Estás haciendo historia.",
                fr: "Les relais du secteur Uranus sont actifs. Le vide entre les planètes ne signifie plus le silence — il signifie signal. Tu es en train de faire l'histoire."
            )
        ),

        StoryBeat(
            id:               "sector_8_clear",
            title:            "DEEP SIGNAL",
            body:             "Neptune sector online. The solar system's relay network is complete. Humanity can now communicate across every known outpost. Mission accomplished.",
            source:           "MISSION CONTROL",
            trigger:          .sectorComplete,
            requiredSectorID: 8,
            accentHex:        "4B70DD",
            footerHint:       "FULL NETWORK OPERATIONAL",
            imageName:        "deep_space_network",
            priority:         20,
            localizedTitle: LocalizedText(
                en: "DEEP SIGNAL",
                es: "SEÑAL PROFUNDA",
                fr: "SIGNAL PROFOND"
            ),
            localizedBody: LocalizedText(
                en: "Neptune sector online. The solar system's relay network is complete. Humanity can now communicate across every known outpost. Mission accomplished.",
                es: "Sector Neptuno en línea. La red de retransmisores del sistema solar está completa. La humanidad puede comunicarse con cada puesto conocido. Misión cumplida.",
                fr: "Secteur Neptune en ligne. Le réseau de relais du système solaire est complet. L'humanité peut désormais communiquer avec chaque poste connu. Mission accomplie."
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
                fr: "RANG AVANCÉ"
            ),
            localizedBody: LocalizedText(
                en: "Your routing metrics exceed baseline. New mission sectors are opening up. This is just the beginning of what you can reach.",
                es: "Tus métricas de enrutamiento superan el nivel base. Se abren nuevos sectores de misiones. Esto es solo el principio de hasta dónde puedes llegar.",
                fr: "Tes métriques de routage dépassent le niveau de référence. De nouveaux secteurs de missions s'ouvrent. Ce n'est que le début de ce que tu peux atteindre."
            )
        ),

        StoryBeat(
            id:                  "rank_up_5",
            title:               "FIELD PROMOTION",
            body:                "Program leadership has taken notice. You're no longer a cadet routing training nodes — you're a senior engineer in active deployment.",
            source:              "CAPT. REYES",
            trigger:             .rankUp,
            requiredPlayerLevel: 5,
            footerHint:          "RANK: NAVIGATOR",
            imageName:           "rank_up_promotion",
            priority:            50,
            localizedTitle: LocalizedText(
                en: "FIELD PROMOTION",
                es: "ASCENSO EN CAMPO",
                fr: "PROMOTION DE TERRAIN"
            ),
            localizedBody: LocalizedText(
                en: "Program leadership has taken notice. You're no longer a cadet routing training nodes — you're a senior engineer in active deployment.",
                es: "Los responsables del programa te han tomado nota. Ya no eres un cadete enrutando nodos de entrenamiento: eres un ingeniero senior en despliegue activo.",
                fr: "La direction du programme t'a remarqué. Tu n'es plus un cadet routant des nœuds d'entraînement — tu es un ingénieur senior en déploiement actif."
            )
        ),

        StoryBeat(
            id:                  "rank_up_10",
            title:               "DEEP COMMISSION",
            body:                "Only a handful of engineers have ever reached this clearance level. The outer solar system relay grid is now your responsibility.",
            source:              "PROGRAM DIRECTOR",
            trigger:             .rankUp,
            requiredPlayerLevel: 10,
            accentHex:           "4B70DD",
            footerHint:          "RANK: COMMANDER",
            imageName:           "rank_up_promotion",
            priority:            50,
            localizedTitle: LocalizedText(
                en: "DEEP COMMISSION",
                es: "COMISIÓN PROFUNDA",
                fr: "COMMISSION EN PROFONDEUR"
            ),
            localizedBody: LocalizedText(
                en: "Only a handful of engineers have ever reached this clearance level. The outer solar system relay grid is now your responsibility.",
                es: "Solo un puñado de ingenieros han alcanzado este nivel de autorización. La red de retransmisores del sistema solar exterior es ahora tu responsabilidad.",
                fr: "Une poignée d'ingénieurs seulement ont jamais atteint ce niveau d'accréditation. Le réseau de relais du système solaire extérieur est désormais sous ta responsabilité."
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // MECHANIC UNLOCKED — specific tutorials per mechanic
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:               "mechanic_rotationCap",
            title:            "COMPONENT STRESS",
            body:             "Field alert: relay units in the next sector have been over-rotated and are near tolerance limits. Each rotation you take may be the last.",
            source:           "DR. CHEN",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .rotationCap,
            footerHint:       "ROTATION LIMIT ACTIVE",
            imageName:        "mechanic_rotations",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "COMPONENT STRESS",
                es: "ESTRÉS DE COMPONENTES",
                fr: "STRESS DES COMPOSANTS"
            ),
            localizedBody: LocalizedText(
                en: "Field alert: relay units in the next sector have been over-rotated and are near tolerance limits. Each rotation you take may be the last.",
                es: "Alerta de campo: las unidades de retransmisor del siguiente sector han sufrido rotaciones excesivas y están cerca de sus límites de tolerancia. Cada rotación que hagas puede ser la última.",
                fr: "Alerte terrain : les unités relais du prochain secteur ont été trop tournées et approchent de leurs limites de tolérance. Chaque rotation que tu effectues peut être la dernière."
            )
        ),

        StoryBeat(
            id:               "mechanic_overloaded",
            title:            "RELAY OVERLOAD",
            body:             "High-resistance nodes detected. These relays require a two-stage command to rotate — arm first, then execute. Rushing will lose the signal.",
            source:           "DR. CHEN",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .overloaded,
            footerHint:       "TWO-TAP PROTOCOL ACTIVE",
            imageName:        "mechanic_interference_2",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "RELAY OVERLOAD",
                es: "SOBRECARGA DE RETRANSMISOR",
                fr: "SURCHARGE DU RELAIS"
            ),
            localizedBody: LocalizedText(
                en: "High-resistance nodes detected. These relays require a two-stage command to rotate — arm first, then execute. Rushing will lose the signal.",
                es: "Nodos de alta resistencia detectados. Estos retransmisores requieren un comando en dos etapas para rotar: primero armar, luego ejecutar. Apresurarse hará perder la señal.",
                fr: "Nœuds à haute résistance détectés. Ces relais nécessitent une commande en deux étapes pour tourner — armer d'abord, puis exécuter. Se précipiter, c'est perdre le signal."
            )
        ),

        StoryBeat(
            id:               "mechanic_autoDrift",
            title:            "NODE DRIFT",
            body:             "Advanced sector warning: some nodes won't hold orientation under electromagnetic pressure. Stabilize the full route before they shift back.",
            source:           "CAPT. REYES",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .autoDrift,
            accentHex:        "7EC8E3",
            footerHint:       "AUTO-DRIFT ACTIVE",
            imageName:        "mechanic_autorotate",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "NODE DRIFT",
                es: "DERIVA DE NODO",
                fr: "DÉRIVE DE NŒUD"
            ),
            localizedBody: LocalizedText(
                en: "Advanced sector warning: some nodes won't hold orientation under electromagnetic pressure. Stabilize the full route before they shift back.",
                es: "Advertencia de sector avanzado: algunos nodos no mantienen la orientación bajo presión electromagnética. Estabiliza la ruta completa antes de que se desplacen de nuevo.",
                fr: "Avertissement secteur avancé : certains nœuds ne maintiennent pas leur orientation sous pression électromagnétique. Stabilise la route complète avant qu'ils se décalent à nouveau."
            )
        ),

        StoryBeat(
            id:               "mechanic_oneWayRelay",
            title:            "DIRECTED SIGNAL",
            body:             "New relay architecture ahead: some nodes only accept signal from a fixed inbound direction. Read the grid carefully before committing.",
            source:           "DR. CHEN",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .oneWayRelay,
            footerHint:       "ONE-WAY RELAY ACTIVE",
            imageName:        "one_way_relay",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "DIRECTED SIGNAL",
                es: "SEÑAL DIRIGIDA",
                fr: "SIGNAL DIRIGÉ"
            ),
            localizedBody: LocalizedText(
                en: "New relay architecture ahead: some nodes only accept signal from a fixed inbound direction. Read the grid carefully before committing.",
                es: "Nueva arquitectura de retransmisor por delante: algunos nodos solo aceptan señal desde una dirección de entrada fija. Lee la cuadrícula cuidadosamente antes de comprometerte.",
                fr: "Nouvelle architecture de relais à venir : certains nœuds n'acceptent le signal que depuis une direction d'entrée fixe. Lis la grille attentivement avant de t'engager."
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
                fr: "DÉGRADATION DU RÉSEAU"
            ),
            localizedBody: LocalizedText(
                en: "Relay degradation detected. Some nodes can only sustain the energy field a limited number of times before permanent burnout. Route efficiently.",
                es: "Degradación de retransmisor detectada. Algunos nodos solo pueden soportar el campo energético un número limitado de veces antes del fallo permanente. Enruta de forma eficiente.",
                fr: "Dégradation de relais détectée. Certains nœuds ne peuvent supporter le champ énergétique qu'un nombre limité de fois avant la panne définitive. Route efficacement."
            )
        ),

        StoryBeat(
            id:               "mechanic_chargeGate",
            title:            "LOCKED SUBSYSTEM",
            body:             "Encrypted relay nodes ahead. They require repeated charge cycles before they conduct. Keep the signal flowing until the gate opens.",
            source:           "DR. CHEN",
            trigger:          .mechanicUnlocked,
            requiredMechanic: .chargeGate,
            footerHint:       "CHARGE GATE ACTIVE",
            imageName:        "locked_subsystem",
            priority:         50,
            localizedTitle: LocalizedText(
                en: "LOCKED SUBSYSTEM",
                es: "SUBSISTEMA BLOQUEADO",
                fr: "SOUS-SYSTÈME VERROUILLÉ"
            ),
            localizedBody: LocalizedText(
                en: "Encrypted relay nodes ahead. They require repeated charge cycles before they conduct. Keep the signal flowing until the gate opens.",
                es: "Nodos de retransmisor cifrados por delante. Requieren ciclos de carga repetidos antes de conducir la señal. Mantén el flujo de señal hasta que la compuerta se abra.",
                fr: "Nœuds relais chiffrés à venir. Ils nécessitent des cycles de charge répétés avant de conduire. Maintiens le flux de signal jusqu'à l'ouverture de la grille."
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
                fr: "BRUIT DE SIGNAL"
            ),
            localizedBody: LocalizedText(
                en: "Electromagnetic interference confirmed in the deep sector. Visual readings on some nodes may be corrupted. Trust your routing logic, not your eyes.",
                es: "Interferencia electromagnética confirmada en el sector profundo. Las lecturas visuales en algunos nodos pueden estar corruptas. Confía en tu lógica de enrutamiento, no en tus ojos.",
                fr: "Interférence électromagnétique confirmée dans le secteur profond. Les lectures visuelles de certains nœuds peuvent être corrompues. Fais confiance à ta logique de routage, pas à tes yeux."
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
                fr: "HORLOGE ACTIVE"
            ),
            localizedBody: LocalizedText(
                en: "Mission window is limited. Relay protocols in this sector auto-reset if you exceed the operation time. Route before the clock expires.",
                es: "La ventana de misión es limitada. Los protocolos de retransmisor de este sector se reinician automáticamente si superas el tiempo de operación. Traza la ruta antes de que el reloj expire.",
                fr: "La fenêtre de mission est limitée. Les protocoles relais de ce secteur se réinitialisent automatiquement si tu dépasses le temps d'opération. Trace la route avant que le chrono n'expire."
            )
        ),

        // ── Generic mechanic atmosphere beat (fires after specific beat is seen) ──

        StoryBeat(
            id:             "story_mechanic_risk",
            title:          "SYSTEMS AHEAD",
            body:           "The systems ahead are no longer designed for comfort. They are designed to endure.",
            source:         "DR. CHEN",
            trigger:        .mechanicUnlocked,
            accentHex:      "FF6A3D",
            imageName:      "intro_repair",
            priority:       70,               // fires only after specific beats are seen
            onceOnly:       false,            // repeatable — fires for each new mechanic
            localizedTitle: LocalizedText(
                en: "SYSTEMS AHEAD",
                es: "SISTEMAS AVANZADOS",
                fr: "SYSTÈMES AVANCÉS"
            ),
            localizedBody: LocalizedText(
                en: "The systems ahead are no longer designed for comfort. They are designed to endure.",
                es: "Los sistemas que vienen a continuación ya no están diseñados para ser cómodos. Están diseñados para resistir.",
                fr: "Les systèmes qui suivent ne sont plus conçus pour être confortables. Ils sont conçus pour résister."
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // PASS UNLOCKED — official authorization per sector (1–7)
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:               "story_lunar_pass_granted",
            title:            "LUNAR CLEARANCE",
            body:             "Your training phase is over. From now on, every mistake will cost more.",
            source:           "PROGRAM DIRECTOR",
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
                fr: "ACCÈS LUNAIRE"
            ),
            localizedBody: LocalizedText(
                en: "Your training phase is over. From now on, every mistake will cost more.",
                es: "Tu entrenamiento ha terminado. A partir de ahora, cada error costará más.",
                fr: "Ta phase d'entraînement est terminée. À partir de maintenant, chaque erreur coûtera plus cher."
            )
        ),

        StoryBeat(
            id:               "story_mars_unlock",
            title:            "MARS AUTHORITY",
            body:             "This is no longer orbital maintenance. This is frontier engineering.",
            source:           "PROGRAM DIRECTOR",
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
                fr: "ACCÈS À MARS"
            ),
            localizedBody: LocalizedText(
                en: "This is no longer orbital maintenance. This is frontier engineering.",
                es: "Esto ya no es mantenimiento orbital. Es ingeniería de frontera.",
                fr: "Ce n'est plus de la maintenance orbitale. C'est de l'ingénierie de frontière."
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
                fr: "TRANSIT DE LA CEINTURE"
            ),
            localizedBody: LocalizedText(
                en: "Mars ops complete. Asteroid Belt clearance issued. Routing through the debris field means working around gaps — no straight paths exist in that corridor.",
                es: "Operaciones en Marte completadas. Autorización emitida para el Cinturón de Asteroides. Trazar rutas entre escombros implica trabajar con huecos: aquí no existen caminos directos.",
                fr: "Opérations martiennes terminées. Autorisation pour la Ceinture d'astéroïdes accordée. Tracer des routes dans le champ de débris, c'est travailler avec des lacunes — aucun chemin droit n'existe dans ce couloir."
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
                fr: "APPROCHE DU GÉANT"
            ),
            localizedBody: LocalizedText(
                en: "Belt cleared. Jupiter Relay access authorized. Atmospheric interference at this distance makes routing unpredictable. Your record earned you this clearance.",
                es: "Cinturón despejado. Acceso al Relé Júpiter autorizado. La interferencia atmosférica a esta distancia hace que el enrutamiento sea impredecible. Tu historial te ha ganado esta oportunidad.",
                fr: "Ceinture dégagée. Accès au relais Jupiter autorisé. Les interférences atmosphériques à cette distance rendent le routage imprévisible. Ton bilan t'a valu cette accréditation."
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
                fr: "TRANSIT DES ANNEAUX"
            ),
            localizedBody: LocalizedText(
                en: "Jupiter array online. Saturn Ring clearance approved. The ring system's interference channels have broken other engineers. You've earned the right to try.",
                es: "Red Júpiter en línea. Autorización de los anillos de Saturno aprobada. Los canales de interferencia del sistema de anillos han quebrado a otros ingenieros. Tú te has ganado el derecho a intentarlo.",
                fr: "Réseau Jupiter en ligne. Autorisation pour les anneaux de Saturne accordée. Les canaux d'interférence du système d'anneaux ont brisé d'autres ingénieurs. Tu as mérité le droit d'essayer."
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
                fr: "ACCÈS AU VIDE"
            ),
            localizedBody: LocalizedText(
                en: "Saturn network stabilized. Uranus Void access granted. Deep space protocol applies. Signal degradation at this range will test instincts built over months of deployment.",
                es: "Red Saturno estabilizada. Acceso al Vacío de Urano concedido. Se aplica el protocolo de espacio profundo. La degradación de señal a esta distancia pondrá a prueba los reflejos forjados durante meses de despliegue.",
                fr: "Réseau Saturne stabilisé. Accès au Vide d'Uranus accordé. Protocole d'espace profond en vigueur. La dégradation du signal à cette portée mettra à l'épreuve les réflexes acquis au fil de mois de déploiement."
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
                fr: "ACCÈS EN PROFONDEUR"
            ),
            localizedBody: LocalizedText(
                en: "Uranus sector live. Neptune Deep authorization confirmed. You have gone further than any signal engineer before you. What lies ahead is genuinely uncharted.",
                es: "Sector Urano activo. Autorización para el Profundo Neptuno confirmada. Has llegado más lejos que cualquier otro ingeniero de señales. Lo que viene ahora es genuinamente territorio inexplorado.",
                fr: "Secteur Uranus en ligne. Autorisation pour Neptune Profond confirmée. Tu es allé plus loin qu'aucun autre ingénieur signal avant toi. Ce qui t'attend est véritablement inexploré."
            )
        ),

        // ══════════════════════════════════════════════════════════════
        // ENTERING NEW SECTOR — destination briefing for sectors 2–8
        // ══════════════════════════════════════════════════════════════

        StoryBeat(
            id:               "story_lunar_intro",
            title:            "LUNAR APPROACH",
            body:             "Lunar systems are older. Less redundancy. More distance. More risk.",
            source:           "CAPT. REYES",
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
                fr: "APPROCHE LUNAIRE"
            ),
            localizedBody: LocalizedText(
                en: "Lunar systems are older. Less redundancy. More distance. More risk.",
                es: "Los sistemas lunares son más antiguos. Menos redundancia. Más distancia. Más riesgo.",
                fr: "Les systèmes lunaires sont plus anciens. Moins de redondance. Plus de distance. Plus de risque."
            )
        ),

        StoryBeat(
            id:               "enter_sector_3",
            title:            "MARS OPS",
            body:             "Red Planet infrastructure is decades old. You'll find legacy routing patterns and modern failure modes in the same grid. Patience is a tool here.",
            source:           "DR. CHEN",
            trigger:          .enteringNewSector,
            requiredSectorID: 3,
            accentHex:        "FF6A3D",
            footerHint:       "SECTOR 3 — MARS SECTOR",
            imageName:        "sector_mars_intro",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "MARS OPS",
                es: "OPERACIONES EN MARTE",
                fr: "OPÉRATIONS SUR MARS"
            ),
            localizedBody: LocalizedText(
                en: "Red Planet infrastructure is decades old. You'll find legacy routing patterns and modern failure modes in the same grid. Patience is a tool here.",
                es: "La infraestructura del planeta rojo tiene décadas de antigüedad. Encontrarás patrones de enrutamiento heredados y modos de fallo modernos en la misma red. Aquí la paciencia es una herramienta.",
                fr: "L'infrastructure de la planète rouge a des décennies d'existence. Tu trouveras des schémas de routage hérités et des modes de défaillance modernes dans la même grille. La patience est un outil ici."
            )
        ),

        StoryBeat(
            id:               "enter_sector_4",
            title:            "BELT ENTRY",
            body:             "No straight paths in the debris field. Routes loop around dead relays and drifting rock. Adapt your plan as you read each grid — the belt doesn't forgive rigid thinking.",
            source:           "CAPT. REYES",
            trigger:          .enteringNewSector,
            requiredSectorID: 4,
            accentHex:        "FFB800",
            footerHint:       "SECTOR 4 — ASTEROID BELT",
            imageName:        "asteroid_belt_entry",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "BELT ENTRY",
                es: "ENTRADA AL CINTURÓN",
                fr: "ENTRÉE DANS LA CEINTURE"
            ),
            localizedBody: LocalizedText(
                en: "No straight paths in the debris field. Routes loop around dead relays and drifting rock. Adapt your plan as you read each grid — the belt doesn't forgive rigid thinking.",
                es: "No hay caminos directos en el campo de escombros. Las rutas rodean retransmisores inactivos y rocas a la deriva. Adapta tu plan según leas cada cuadrícula: el cinturón no perdona el pensamiento rígido.",
                fr: "Pas de chemin direct dans le champ de débris. Les routes contournent les relais morts et les roches en dérive. Adapte ton plan en lisant chaque grille — la ceinture ne pardonne pas la rigidité."
            )
        ),

        StoryBeat(
            id:               "enter_sector_5",
            title:            "GAS GIANT GRID",
            body:             "Jupiter's relay array spans distances you haven't worked before. Signal latency is measurable at this range. Precision counts more than speed.",
            source:           "PROGRAM DIRECTOR",
            trigger:          .enteringNewSector,
            requiredSectorID: 5,
            accentHex:        "D4A055",
            footerHint:       "SECTOR 5 — JUPITER RELAY",
            imageName:        "gas_giant_grid",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "GAS GIANT GRID",
                es: "RED DEL GIGANTE GASEOSO",
                fr: "RÉSEAU DU GÉANT GAZEUX"
            ),
            localizedBody: LocalizedText(
                en: "Jupiter's relay array spans distances you haven't worked before. Signal latency is measurable at this range. Precision counts more than speed.",
                es: "La red de retransmisores de Júpiter cubre distancias con las que no habías trabajado antes. La latencia de señal es medible a esta distancia. La precisión vale más que la velocidad.",
                fr: "Le réseau de relais de Jupiter couvre des distances que tu n'as jamais eu à gérer. La latence du signal est mesurable à cette portée. La précision compte plus que la vitesse."
            )
        ),

        StoryBeat(
            id:               "enter_sector_6",
            title:            "RING SYSTEM",
            body:             "Saturn's rings create interference channels that block and redirect signal in unpredictable ways. Study each grid before committing. Nothing here is what it appears.",
            source:           "DR. CHEN",
            trigger:          .enteringNewSector,
            requiredSectorID: 6,
            accentHex:        "E4C87A",
            footerHint:       "SECTOR 6 — SATURN RING",
            imageName:        "ring_system",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "RING SYSTEM",
                es: "SISTEMA DE ANILLOS",
                fr: "SYSTÈME D'ANNEAUX"
            ),
            localizedBody: LocalizedText(
                en: "Saturn's rings create interference channels that block and redirect signal in unpredictable ways. Study each grid before committing. Nothing here is what it appears.",
                es: "Los anillos de Saturno crean canales de interferencia que bloquean y redirigen la señal de manera impredecible. Estudia cada cuadrícula antes de comprometerte. Aquí nada es lo que parece.",
                fr: "Les anneaux de Saturne créent des canaux d'interférence qui bloquent et redirigent le signal de manière imprévisible. Étudie chaque grille avant de t'engager. Rien n'est ce qu'il paraît ici."
            )
        ),

        StoryBeat(
            id:               "enter_sector_7",
            title:            "DEEP VOID",
            body:             "Uranus sector relays operate at the edge of the inner network. Every node matters — there is no redundancy at this distance. One unresolved failure propagates outward.",
            source:           "PROGRAM DIRECTOR",
            trigger:          .enteringNewSector,
            requiredSectorID: 7,
            accentHex:        "7EC8E3",
            footerHint:       "SECTOR 7 — URANUS VOID",
            imageName:        "deep_void",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "DEEP VOID",
                es: "VACÍO PROFUNDO",
                fr: "VIDE PROFOND"
            ),
            localizedBody: LocalizedText(
                en: "Uranus sector relays operate at the edge of the inner network. Every node matters — there is no redundancy at this distance. One unresolved failure propagates outward.",
                es: "Los retransmisores del sector Urano operan en el límite de la red interior. Cada nodo importa: no hay redundancia a esta distancia. Un fallo sin resolver se propaga hacia afuera.",
                fr: "Les relais du secteur Uranus fonctionnent à la limite du réseau intérieur. Chaque nœud compte — il n'y a aucune redondance à cette distance. Une défaillance non résolue se propage vers l'extérieur."
            )
        ),

        StoryBeat(
            id:               "enter_sector_8",
            title:            "FINAL SECTOR",
            body:             "This is as far as the network reaches. Neptune's relays are the frontier of human infrastructure. What you build here carries our signal to its absolute edge.",
            source:           "PROGRAM DIRECTOR",
            trigger:          .enteringNewSector,
            requiredSectorID: 8,
            accentHex:        "4B70DD",
            footerHint:       "SECTOR 8 — NEPTUNE DEEP",
            imageName:        "deep_space_network",
            priority:         40,
            localizedTitle: LocalizedText(
                en: "FINAL SECTOR",
                es: "SECTOR FINAL",
                fr: "SECTEUR FINAL"
            ),
            localizedBody: LocalizedText(
                en: "This is as far as the network reaches. Neptune's relays are the frontier of human infrastructure. What you build here carries our signal to its absolute edge.",
                es: "Hasta aquí llega la red. Los retransmisores de Neptuno son la frontera de la infraestructura humana. Lo que construyas aquí llevará nuestra señal hasta su límite absoluto.",
                fr: "C'est aussi loin que le réseau s'étend. Les relais de Neptune sont la frontière de l'infrastructure humaine. Ce que tu bâtis ici porte notre signal jusqu'à son ultime limite."
            )
        ),
    ]
}
