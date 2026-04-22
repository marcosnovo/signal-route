import Foundation

// MARK: - AppStrings
/// Localized UI strings for all three supported languages.
/// Usage: `private var S: AppStrings { AppStrings(lang: settings.language) }`
struct AppStrings {
    let lang: AppLanguage

    private func t(_ en: String, _ es: String, _ fr: String) -> String {
        switch lang {
        case .en: return en
        case .es: return es
        case .fr: return fr
        }
    }

    // MARK: - Navigation
    var close:  String { t("CLOSE",  "CERRAR",  "FERMER") }
    var back:   String { t("BACK",   "VOLVER",  "RETOUR") }
    var home:   String { t("HOME",   "INICIO",  "ACCUEIL") }
    var skip:           String { t("SKIP",     "SALTAR",    "PASSER") }
    var continueAction: String { t("CONTINUE", "CONTINUAR", "CONTINUER") }
    var begin:          String { t("BEGIN",    "COMENZAR",  "COMMENCER") }

    // MARK: - Home — system bar
    var nodeActive: String { t("NODE ACTIVE",   "NODO ACTIVO",   "NŒUD ACTIF") }
    var config:     String { t("CONFIG",        "CONFIG",        "CONFIG") }
    var rankings:   String { t("RANKINGS",      "CLASIFICACIÓN", "CLASSEMENT") }

    // MARK: - Home — title
    var restoreTheNetwork: String { t("RESTORE THE NETWORK", "RESTAURA LA RED", "RESTAURER LE RÉSEAU") }

    // MARK: - Home — mission section
    var nextMission:        String { t("NEXT MISSION",         "PRÓXIMA MISIÓN",          "PROCHAINE MISSION") }
    var launch:             String { t("LAUNCH",               "LANZAR",                  "LANCER") }
    var missionMap:         String { t("MISSION MAP",          "MAPA DE MISIONES",        "CARTE DES MISSIONS") }
    var initializeTraining: String { t("INITIALIZE TRAINING",  "INICIAR ENTRENAMIENTO",   "INITIALISER L'ENTRAÎNEMENT") }
    var systemCalibration:  String { t("SYSTEM CALIBRATION",   "CALIBRACIÓN DEL SISTEMA", "CALIBRATION DU SYSTÈME") }
    var trainingMission:    String { t("TRAINING MISSION",     "MISIÓN DE ENTRENAMIENTO", "MISSION D'ENTRAÎNEMENT") }
    var required:           String { t("REQUIRED",             "REQUERIDO",               "REQUIS") }

    var allMissionsCleared: String { t("ALL MISSIONS CLEARED",      "TODAS LAS MISIONES COMPLETAS", "TOUTES LES MISSIONS ACCOMPLIES") }
    func allMissionsClearedSub(count: Int) -> String {
        t("You've completed all \(count) missions.",
          "Has completado las \(count) misiones.",
          "Vous avez complété les \(count) missions.")
    }

    // MARK: - Home — status strip
    var signalActive: String { t("SIGNAL  ·  ACTIVE",   "SEÑAL  ·  ACTIVA",   "SIGNAL  ·  ACTIF") }
    var missions:     String { t("MISSIONS",             "MISIONES",            "MISSIONS") }

    // MARK: - Astronaut progress card
    var astronautProfile:  String { t("MISSION CREDENTIAL",  "CREDENCIAL DE MISIÓN", "ACCRÉDITATION") }
    var levelLabel:        String { t("LEVEL",              "NIVEL",                "NIVEAU") }
    var destination:       String { t("DESTINATION",        "DESTINO",              "DESTINATION") }
    var nextTarget:        String { t("NEXT TARGET",        "PRÓXIMO OBJETIVO",     "PROCHAINE CIBLE") }

    func progressToLevel(_ n: Int) -> String {
        t("PROGRESS TO LEVEL \(n)", "PROGRESO AL NIVEL \(n)", "PROGRESSION NIVEAU \(n)")
    }
    func toQualify(pct: Int) -> String {
        t("≥\(pct)% TO QUALIFY", "≥\(pct)% PARA CALIFICAR", "≥\(pct)% POUR QUALIFIER")
    }
    var qualified:          String { t("QUALIFIED",           "CALIFICADAS",    "QUALIFIÉES") }
    var remaining:          String { t("REMAINING",           "PENDIENTES",     "RESTANTES") }
    var statusLabel:        String { t("STATUS",              "ESTADO",         "ÉTAT") }
    var ready:              String { t("READY",               "LISTO",          "PRÊT") }
    var avgEff:             String { t("AVG EFF",             "EFF. MEDIA",     "EFF. MOY.") }
    var tapToViewPlanetPass: String { t("TAP TO VIEW PLANET PASS", "TOCA PARA VER EL PASE", "TOUCHER POUR LE LAISSEZ-PASSER") }
    var viewPass:            String { t("VIEW PASS",               "VER PASE",              "VOIR LE PASSE") }

    // MARK: - Planet & region names (used in HomeView, LevelSelectView, pass cards)

    func planetName(_ name: String) -> String {
        switch name {
        case "EARTH ORBIT":   return t("EARTH ORBIT",   "ÓRBITA TERRESTRE",         "ORBITE TERRESTRE")
        case "MOON":          return t("MOON",           "LUNA",                     "LUNE")
        case "MARS":          return t("MARS",           "MARTE",                    "MARS")
        case "ASTEROID BELT": return t("ASTEROID BELT",  "CINTURÓN DE ASTEROIDES",   "CEINTURE D'ASTÉROÏDES")
        case "JUPITER":       return t("JUPITER",        "JÚPITER",                  "JUPITER")
        case "SATURN":        return t("SATURN",         "SATURNO",                  "SATURNE")
        case "URANUS":        return t("URANUS",         "URANO",                    "URANUS")
        case "NEPTUNE":       return t("NEPTUNE",        "NEPTUNO",                  "NEPTUNE")
        default: return name
        }
    }

    func regionName(_ name: String) -> String {
        switch name {
        case "EARTH ORBIT":    return t("EARTH ORBIT",    "ÓRBITA TERRESTRE",         "ORBITE TERRESTRE")
        case "LUNAR APPROACH": return t("LUNAR APPROACH", "APROXIMACIÓN LUNAR",       "APPROCHE LUNAIRE")
        case "MARS SECTOR":    return t("MARS SECTOR",    "SECTOR MARTE",             "SECTEUR MARS")
        case "ASTEROID BELT":  return t("ASTEROID BELT",  "CINTURÓN DE ASTEROIDES",   "CEINTURE D'ASTÉROÏDES")
        case "JUPITER RELAY":  return t("JUPITER RELAY",  "RELÉ JÚPITER",             "RELAIS JUPITER")
        case "SATURN RING":    return t("SATURN RING",    "ANILLOS DE SATURNO",       "ANNEAUX DE SATURNE")
        case "URANUS VOID":    return t("URANUS VOID",    "VACÍO DE URANO",           "VIDE D'URANUS")
        case "NEPTUNE DEEP":   return t("NEPTUNE DEEP",   "NEPTUNO PROFUNDO",         "NEPTUNE PROFOND")
        default: return name
        }
    }

    func zoneBrief(_ brief: String) -> String {
        switch brief {
        case "TRAINING ZONE":       return t("TRAINING ZONE",       "ZONA DE ENTRENAMIENTO",     "ZONE D'ENTRAÎNEMENT")
        case "LUNAR APPROACH":      return t("LUNAR APPROACH",      "APROXIMACIÓN LUNAR",        "APPROCHE LUNAIRE")
        case "RED PLANET OPS":      return t("RED PLANET OPS",      "OPS PLANETA ROJO",          "OPS PLANÈTE ROUGE")
        case "DEBRIS FIELD":        return t("DEBRIS FIELD",        "CAMPO DE ESCOMBROS",        "CHAMP DE DÉBRIS")
        case "GAS GIANT RELAY":     return t("GAS GIANT RELAY",     "RELÉ DEL GIGANTE GASEOSO",  "RELAIS DU GÉANT GAZEUX")
        case "GAS GIANT COMMS":     return t("GAS GIANT COMMS",     "COMMS GIGANTE GASEOSO",     "COMMS GÉANT GAZEUX")
        case "RING SYSTEM TRANSIT": return t("RING SYSTEM TRANSIT", "TRÁNSITO DE ANILLOS",       "TRANSIT DES ANNEAUX")
        case "ICE GIANT SURVEY":    return t("ICE GIANT SURVEY",    "EXPLORACIÓN GIGANTE HELADO","EXPLORATION DU GÉANT GLACÉ")
        case "DEEP SPACE COMMS":    return t("DEEP SPACE COMMS",    "COMMS ESPACIO PROFUNDO",    "COMMS ESPACE PROFOND")
        case "PHASE 2 OPERATIONS":  return t("PHASE 2 OPERATIONS",  "OPERACIONES FASE 2",        "OPÉRATIONS PHASE 2")
        default: return brief
        }
    }

    var missionEff: String { t("MISSION EFF", "EFF. MISIÓN", "EFF. MISSION") }

    // MARK: - Planet ticket
    var planetPass:           String { t("PLANET PASS",                  "PASE PLANETARIO",               "LAISSEZ-PASSER") }
    var trainingClearance:    String { t("TRAINING CLEARANCE",            "AUTORIZACIÓN DE ENTRENAMIENTO", "AUTORISATION D'ENTRAÎNEMENT") }
    var shareProgress:        String { t("SHARE PROGRESS",               "COMPARTIR PROGRESO",            "PARTAGER LA PROGRESSION") }
    /// Share sheet body text — personalised with the player's current level.
    func shareProgressText(level: Int) -> String {
        t(
            "I reached level \(level) in SIGNAL VOID 🚀\nCan you go further?",
            "He alcanzado el nivel \(level) en SIGNAL VOID 🚀\n¿Puedes llegar más lejos?",
            "J'ai atteint le niveau \(level) dans SIGNAL VOID 🚀\nPeux-tu aller plus loin ?"
        )
    }
    // Ticket renderer labels (CGContext-rendered image)
    var accessAuthorized:     String { t("ACCESS AUTHORIZED",             "ACCESO AUTORIZADO",             "ACCÈS AUTORISÉ") }
    var inTraining:           String { t("IN TRAINING",                   "EN ENTRENAMIENTO",              "EN FORMATION") }
    var missionEfficiency:    String { t("MISSION EFFICIENCY",            "EFICIENCIA DE MISIÓN",          "EFFICACITÉ DE MISSION") }
    var rankLabel:            String { t("RANK",                          "RANGO",                         "RANG") }
    var clearedStatus:        String { t("CLEARED",                       "COMPLETADO",                    "VALIDÉ") }
    var inProgressStatus:     String { t("IN PROGRESS",                   "EN PROGRESO",                   "EN COURS") }
    var sectorTransitPass:    String { t("SECTOR TRANSIT PASS",           "PASE DE TRÁNSITO",              "LAISSEZ-PASSER SECTEUR") }
    var authorizedBearer:     String { t("AUTHORIZED BEARER",             "PORTADOR AUTORIZADO",           "PORTEUR AUTORISÉ") }

    // MARK: - Onboarding tutorial
    var tutorialTitle:        String { t("MISSION BRIEFING",              "INFORME DE MISIÓN",             "BRIEFING DE MISSION") }
    var tutorialBody:         String { t("Connect the signal source to the target by tapping tiles to rotate them.",
                                         "Conecta la fuente de señal al objetivo tocando los bloques para rotarlos.",
                                         "Connectez la source du signal à la cible en touchant les tuiles pour les tourner.") }
    var tutorialSignalSource: String { t("SIGNAL SOURCE",                 "FUENTE DE SEÑAL",               "SOURCE DU SIGNAL") }
    var tutorialTargetRelay:  String { t("TARGET RELAY",                  "RELÉ OBJETIVO",                 "RELAIS CIBLE") }
    var tutorialBeginMission: String { t("BEGIN MISSION",                 "INICIAR MISIÓN",                "COMMENCER LA MISSION") }
    var tutorialTapHint:      String { t("TAP TILES TO ROTATE",           "TOCA BLOQUES PARA ROTAR",       "TOUCHEZ POUR TOURNER") }

    func difficultyFullLabel(_ tier: DifficultyTier) -> String {
        switch tier {
        case .easy:   return t("EASY",   "FÁCIL",   "FACILE")
        case .medium: return t("MEDIUM", "MEDIO",   "MOYEN")
        case .hard:   return t("HARD",   "DIFÍCIL", "DIFFICILE")
        case .expert: return t("EXPERT", "EXPERTO", "EXPERT")
        }
    }

    var renderingPass:        String { t("RENDERING PASS…",              "GENERANDO PASE…",               "GÉNÉRATION DU LAISSEZ-PASSER…") }
    var preparingPass:        String { t("PREPARING PLANET PASS",        "PREPARANDO PASE PLANETARIO",    "PRÉPARATION DU LAISSEZ-PASSER") }
    var generatingCredential: String { t("GENERATING MISSION CREDENTIAL","GENERANDO CREDENCIAL DE MISIÓN","GÉNÉRATION DES ACCRÉDITATIONS") }

    // MARK: - Mission card labels
    var dailyMission:    String { t("DAILY MISSION",  "MISIÓN DIARIA",  "MISSION QUOTIDIENNE") }
    var complete:        String { t("COMPLETE",       "COMPLETA",       "TERMINÉE") }
    var failed:          String { t("FAILED",         "FALLIDA",        "ÉCHOUÉE") }
    var gridLabel:       String { t("GRID",           "CUADRÍCULA",     "GRILLE") }
    var objectiveLabel:  String { t("OBJECTIVE",      "OBJETIVO",       "OBJECTIF") }
    var targetsLabel:    String { t("TARGETS",        "OBJETIVOS",      "CIBLES") }
    var signalLabel:     String { t("SIGNAL",         "SEÑAL",          "SIGNAL") }
    var activeValue:     String { t("ACTIVE",         "ACTIVA",         "ACTIF") }
    var readyValue:      String { t("READY",          "LISTA",          "PRÊTE") }
    var movesLabel:      String { t("MOVES",          "MOVIMIENTOS",    "MOUVEMENTS") }
    var efficiencyLabel: String { t("EFFICIENCY",     "EFICIENCIA",     "EFFICACITÉ") }
    var movesUsedLabel:  String { t("MOVES USED",     "MOVS. USADOS",   "MOUVS. UTILISÉS") }

    // MARK: - Mission map
    var missionMapTitle: String { t("MISSION MAP",     "MAPA DE MISIONES", "CARTE DES MISSIONS") }
    func missionsComplete(done: Int, total: Int) -> String {
        t("\(done) / \(total) COMPLETE", "\(done) / \(total) COMPLETADAS", "\(done) / \(total) TERMINÉES")
    }
    var activeSector:   String { t("ACTIVE SECTOR",  "SECTOR ACTIVO",    "SECTEUR ACTIF") }
    var sectorComplete: String { t("SECTOR COMPLETE", "SECTOR COMPLETADO", "SECTEUR TERMINÉ") }
    var lockedLabel:    String { t("LOCKED",           "BLOQUEADO",        "VERROUILLÉ") }
    var missionsLabel:  String { t("MISSIONS",         "MISIONES",         "MISSIONS") }
    func levelRequired(_ n: Int) -> String { t("LVL \(n)", "NIV \(n)", "NIV \(n)") }
    var next:           String { t("NEXT",             "SGTE",             "SUIV.") }
    var viewMissions:   String { t("VIEW MISSIONS",    "VER MISIONES",     "VOIR LES MISSIONS") }
    var hideMissions:   String { t("HIDE MISSIONS",    "OCULTAR MISIONES", "MASQUER LES MISSIONS") }
    var completePreviousSectors: String { t("COMPLETE PREVIOUS SECTORS", "COMPLETA SECTORES ANTERIORES", "TERMINER LES SECTEURS PRÉCÉDENTS") }
    func unlockAtLevel(_ n: Int) -> String { t("UNLOCK AT LEVEL \(n)", "DESBLOQUEAR EN NIVEL \(n)", "DÉBLOQUER AU NIVEAU \(n)") }
    var avgEfficiency:  String { t("AVG EFFICIENCY",   "EFIC. MEDIA",      "EFF. MOYENNE") }
    var missionsCount:  String { t("MISSIONS",         "MISIONES",         "MISSIONS") }

    // MARK: - Settings
    var systemConfig:        String { t("SYSTEM CONFIG",     "CONFIG. DEL SISTEMA", "CONFIG. DU SYSTÈME") }
    var audio:               String { t("AUDIO",             "AUDIO",               "AUDIO") }
    var soundFX:             String { t("SOUND FX",          "EFECTOS DE SONIDO",   "EFFETS SONORES") }
    var soundFXSub:          String { t("Game sound effects", "Efectos de juego",   "Effets du jeu") }
    var ambientMusic:        String { t("AMBIENT MUSIC",     "MÚSICA AMBIENTAL",    "MUSIQUE D'AMBIANCE") }
    var ambientMusicSub:     String { t("Background drone",  "Dron de fondo",       "Drone d'ambiance") }
    var interfaceSection:    String { t("INTERFACE",         "INTERFAZ",            "INTERFACE") }
    var hapticFeedback:      String { t("HAPTIC FEEDBACK",   "FEEDBACK HÁPTICO",    "RETOUR HAPTIQUE") }
    var hapticFeedbackSub:   String { t("Vibration on actions", "Vibración en acciones", "Vibration sur les actions") }
    var reducedMotion:       String { t("REDUCED MOTION",    "MOVIMIENTO REDUCIDO", "MOUVEMENT RÉDUIT") }
    var reducedMotionSub:    String { t("Simplify animations", "Simplificar animaciones", "Simplifier les animations") }
    var language:            String { t("LANGUAGE",          "IDIOMA",              "LANGUE") }

    // MARK: - Game HUD
    var movesRemaining:    String { t("MOVES REMAINING",  "MOVIMIENTOS RESTANTES", "MOUVEMENTS RESTANTS") }
    var usedLabel:         String { t("USED",             "USADOS",                "UTILISÉS") }
    var parLabel:          String { t("PAR",              "PAR",                   "PAR") }
    var timeRemaining:     String { t("TIME REMAINING",   "TIEMPO RESTANTE",       "TEMPS RESTANT") }
    var elapsed:           String { t("ELAPSED",          "TRANSCURRIDO",          "ÉCOULÉ") }
    var objectiveHUD:      String { t("OBJECTIVE",        "OBJETIVO",              "OBJECTIF") }
    var gridCoverage:      String { t("GRID COVERAGE",    "COBERTURA DE RED",      "COUVERTURE DU RÉSEAU") }
    var extraNodes:        String { t("EXTRA NODES",      "NODOS EXTRA",           "NŒUDS EN EXCÈS") }
    var coverageMinHint:   String { t("· MIN 50% COVERAGE", "· COBERTURA MÍN 50%", "· COUVERTURE MIN 50%") }
    var reduceNetwork:     String { t("· REDUCE NETWORK", "· REDUCE LA RED",       "· RÉDUIRE LE RÉSEAU") }
    var targetsOnline:     String { t("TARGETS ONLINE",   "OBJETIVOS ACTIVOS",     "CIBLES ACTIVES") }
    var activeNodes:       String { t("ACTIVE NODES",     "NODOS ACTIVOS",         "NŒUDS ACTIFS") }
    var coverage:          String { t("COVERAGE",         "COBERTURA",             "COUVERTURE") }
    var waste:             String { t("WASTE",            "DERROCHE",              "GASPILLAGE") }
    var network:           String { t("NETWORK",          "RED",                   "RÉSEAU") }
    var online:            String { t("ONLINE",           "EN LÍNEA",              "EN LIGNE") }
    var offline:           String { t("OFFLINE",          "DESCONECTADA",          "HORS LIGNE") }

    // Hint text
    var rotateTilesToRouteSignal: String {
        t("ROTATE TILES TO ROUTE THE SIGNAL",
          "ROTA LOS BLOQUES PARA DIRIGIR LA SEÑAL",
          "ROTEZ LES BLOCS POUR ACHEMINER LE SIGNAL")
    }
    var tapAnyTileToRotate: String {
        t("TAP ANY TILE TO ROTATE IT",
          "TOCA UN BLOQUE PARA ROTARLO",
          "TOUCHEZ UN BLOC POUR LE FAIRE PIVOTER")
    }
    var tapTileToRotate: String {
        t("TAP TILE TO ROTATE",
          "TOCA UN BLOQUE PARA ROTAR",
          "TOUCHER UN BLOC POUR PIVOTER")
    }

    // MARK: - Objective text (Game HUD banner)
    func objectiveText(type: LevelObjectiveType, targets: Int) -> String {
        switch type {
        case .normal:
            return targets > 1
                ? t("ACTIVATE \(targets) TARGETS", "ACTIVAR \(targets) OBJETIVOS", "ACTIVER \(targets) CIBLES")
                : t("BRIDGE THE VOID",              "CRUZAR EL VACÍO",              "COMBLER LE VIDE")
        case .maxCoverage:
            return t("MAXIMIZE ACTIVE GRID",  "MAXIMIZAR RED ACTIVA",  "MAXIMISER LE RÉSEAU ACTIF")
        case .energySaving:
            return t("SAVE ENERGY",           "AHORRAR ENERGÍA",       "ÉCONOMISER L'ÉNERGIE")
        }
    }

    // MARK: - LevelObjectiveType HUD label
    func hudLabel(_ type: LevelObjectiveType) -> String {
        switch type {
        case .normal:       return t("ACTIVATE TARGETS",     "ACTIVAR OBJETIVOS",    "ACTIVER LES CIBLES")
        case .maxCoverage:  return t("MAXIMIZE ACTIVE GRID", "MAXIMIZAR RED ACTIVA", "MAXIMISER LE RÉSEAU")
        case .energySaving: return t("SAVE ENERGY",          "AHORRAR ENERGÍA",      "ÉCONOMISER L'ÉNERGIE")
        }
    }

    // MARK: - Mission overlay (win / lose)
    var statusSuccess:  String { t("STATUS: SUCCESS",    "ESTADO: ÉXITO",      "ÉTAT: SUCCÈS") }
    var statusFailure:  String { t("STATUS: FAILURE",    "ESTADO: FALLO",      "ÉTAT: ÉCHEC") }
    var networkRestored: String { t("NETWORK RESTORED",  "RED RESTAURADA",     "RÉSEAU RESTAURÉ") }
    var signalLost:     String { t("SIGNAL LOST",        "SEÑAL PERDIDA",      "SIGNAL PERDU") }
    var score:          String { t("SCORE",              "PUNTUACIÓN",         "SCORE") }
    var movesOverlay:   String { t("MOVES",              "MOVIMIENTOS",        "MOUVEMENTS") }
    var remainingOverlay: String { t("REMAINING",        "RESTANTES",          "RESTANTS") }
    var retryLevel:     String { t("RETRY LEVEL",        "REINTENTAR NIVEL",   "RÉESSAYER LE NIVEAU") }
    var tryAgain:       String { t("TRY AGAIN",          "INTENTAR DE NUEVO",  "RÉESSAYER") }
    var shareResult:    String { t("SHARE RESULT",       "COMPARTIR RESULTADO","PARTAGER LE RÉSULTAT") }
    var returnToBase:   String { t("RETURN TO BASE",     "VOLVER A LA BASE",   "RETOUR À LA BASE") }
    var efficiencyBar:  String { t("EFFICIENCY",         "EFICIENCIA",         "EFFICACITÉ") }

    // MARK: - Sector complete overlay
    /// "COMPLETE" label shown below the planet name on the sector-complete interstitial.
    var zoneComplete: String { t("COMPLETE", "COMPLETADO", "TERMINÉ") }
    /// "[PLANET] ACCESS GRANTED" — label shown above the pass card.
    func zoneAccessGranted(_ name: String) -> String {
        t("\(name) ACCESS GRANTED", "\(name): ACCESO CONCEDIDO", "\(name): ACCÈS ACCORDÉ")
    }

    // MARK: - Intro win overlay
    var signalRouted:              String { t("VOID BRIDGED",                "VACÍO CRUZADO",                  "VIDE COMBLÉ") }
    var networkOnline:             String { t("NETWORK ONLINE",              "RED EN LÍNEA",                   "RÉSEAU EN LIGNE") }
    var systemCalibrationComplete: String { t("SYSTEM CALIBRATION COMPLETE", "CALIBRACIÓN DEL SISTEMA COMPLETA","CALIBRATION DU SYSTÈME TERMINÉE") }
    var clearedForDeployment:      String { t("CLEARED FOR DEPLOYMENT",      "AUTORIZADO PARA EL DESPLIEGUE",  "AUTORISÉ POUR LE DÉPLOIEMENT") }
    var accessGranted:             String { t("ACCESS GRANTED",              "ACCESO CONCEDIDO",               "ACCÈS ACCORDÉ") }

    // MARK: - Intro fail overlay
    var routingFailed:             String { t("ROUTING FAILED",              "ENRUTAMIENTO FALLIDO",           "ROUTAGE ÉCHOUÉ") }
    var networkDisconnected:       String { t("NETWORK DISCONNECTED",        "RED DESCONECTADA",               "RÉSEAU DÉCONNECTÉ") }
    var introFailInstruction:      String { t("ROTATE THE TILES TO CONNECT THE SOURCE NODE TO THE TARGET NODE", "ROTA LAS PIEZAS PARA CONECTAR EL NODO ORIGEN CON EL NODO DESTINO", "FAITES PIVOTER LES TUILES POUR CONNECTER LE NŒUD SOURCE AU NŒUD CIBLE") }
    var retryMission:              String { t("RETRY MISSION",               "REINTENTAR MISIÓN",              "RÉESSAYER LA MISSION") }
    var signalEstablished:         String { t("SIGNAL ESTABLISHED",          "SEÑAL ESTABLECIDA",              "SIGNAL ÉTABLI") }
    func missionProgress(_ n: Int, _ total: Int) -> String {
        t("\(n) / \(total) MISSIONS", "\(n) / \(total) MISIONES", "\(n) / \(total) MISSIONS")
    }

    // MARK: - Mechanic unlock
    var newMechanicUnlocked: String { t("NEW MECHANIC UNLOCKED",    "NUEVA MECÁNICA DESBLOQUEADA", "NOUVELLE MÉCANIQUE DÉBLOQUÉE") }
    var understood:          String { t("UNDERSTOOD",               "ENTENDIDO",                   "COMPRIS") }

    func mechanicTitle(_ type: MechanicType) -> String {
        switch type {
        case .rotationCap:      return t("ROTATION LIMIT",    "LÍMITE DE ROTACIÓN",    "LIMITE DE ROTATION")
        case .overloaded:       return t("OVERLOADED RELAY",  "RELÉ SOBRECARGADO",     "RELAIS SURCHARGÉ")
        case .timeLimit:        return t("TIME PRESSURE",     "PRESIÓN TEMPORAL",      "PRESSION TEMPORELLE")
        case .autoDrift:        return t("NODE DRIFT",        "DERIVA DE NODO",        "DÉRIVE DE NŒUD")
        case .oneWayRelay:      return t("ONE-WAY RELAY",     "RELÉ UNIDIRECCIONAL",   "RELAIS UNIDIRECTIONNEL")
        case .fragileTile:      return t("FRAGILE RELAY",     "RELÉ FRÁGIL",           "RELAIS FRAGILE")
        case .chargeGate:       return t("CHARGE GATE",       "COMPUERTA DE CARGA",    "PORTE DE CHARGE")
        case .interferenceZone: return t("INTERFERENCE",      "INTERFERENCIA",         "INTERFÉRENCE")
        }
    }

    func mechanicMessage(_ type: MechanicType) -> String {
        switch type {
        case .rotationCap:
            return t(
                "Your training is progressing fast. Some components are now unstable and can only be rotated a limited number of times. Plan every move carefully.",
                "Tu entrenamiento avanza rápido. Algunos componentes son inestables y solo pueden rotarse un número limitado de veces. Planifica cada movimiento.",
                "Votre entraînement progresse vite. Certains composants sont instables et ne peuvent être pivotés qu'un nombre limité de fois. Planifiez chaque mouvement."
            )
        case .overloaded:
            return t(
                "High-resistance nodes have been detected in the network. Some relays require two commands to rotate — arm first, then execute.",
                "Se han detectado nodos de alta resistencia en la red. Algunos relés requieren dos comandos para rotar: primero armar, luego ejecutar.",
                "Des nœuds à haute résistance ont été détectés dans le réseau. Certains relais nécessitent deux commandes pour pivoter — armer d'abord, puis exécuter."
            )
        case .timeLimit:
            return t(
                "You've shown remarkable routing skills. We believe time won't be a problem for you anymore. From now on, some missions must be completed under time pressure.",
                "Has demostrado habilidades de enrutamiento notables. Creemos que el tiempo no será un problema para ti. A partir de ahora, algunas misiones deben completarse contra el reloj.",
                "Vous avez démontré des compétences d'acheminement remarquables. Désormais, certaines missions doivent être accomplies sous pression temporelle."
            )
        case .autoDrift:
            return t(
                "Advanced systems are now entering the simulation. Some nodes won't hold their orientation for long. Stabilize the route before they shift again.",
                "Sistemas avanzados entran ahora en la simulación. Algunos nodos no mantendrán su orientación por mucho tiempo. Estabiliza la ruta antes de que se desplacen.",
                "Des systèmes avancés entrent dans la simulation. Certains nœuds ne garderont pas leur orientation longtemps. Stabilisez la route avant qu'ils ne basculent à nouveau."
            )
        case .oneWayRelay:
            return t(
                "Advanced routing protocols unlocked. Some relays now only accept signal from specific directions. Read the grid carefully.",
                "Protocolos de enrutamiento avanzados desbloqueados. Algunos relés solo aceptan señal desde direcciones específicas. Lee la cuadrícula con cuidado.",
                "Protocoles d'acheminement avancés débloqués. Certains relais n'acceptent le signal que depuis des directions spécifiques. Lisez attentivement la grille."
            )
        case .fragileTile:
            return t(
                "Network components are degrading. Some relays can only handle limited exposure to the energy field before burning out permanently. Route efficiently before they fail.",
                "Los componentes de la red se están degradando. Algunos relés solo soportan una exposición limitada al campo de energía antes de quemarse. Enruta con eficiencia antes de que fallen.",
                "Les composants du réseau se dégradent. Certains relais ne supportent qu'une exposition limitée au champ d'énergie avant de griller. Achemninez efficacement avant qu'ils ne lâchent."
            )
        case .chargeGate:
            return t(
                "Locked subsystems detected. Some relays require multiple charge cycles before they conduct. Keep the signal flowing until the gate opens.",
                "Se detectaron subsistemas bloqueados. Algunos relés requieren varios ciclos de carga antes de conducir. Mantén el flujo de señal hasta que la compuerta se abra.",
                "Sous-systèmes verrouillés détectés. Certains relais nécessitent plusieurs cycles de charge avant de conduire. Maintenez le signal jusqu'à l'ouverture de la porte."
            )
        case .interferenceZone:
            return t(
                "Electromagnetic interference detected in the grid. Some sectors are compromised — visual readings may be distorted. Trust the signal, not your eyes.",
                "Se ha detectado interferencia electromagnética en la cuadrícula. Algunos sectores están comprometidos — las lecturas visuales pueden estar distorsionadas. Confía en la señal, no en tus ojos.",
                "Interférence électromagnétique détectée dans la grille. Certains secteurs sont compromis — les lectures visuelles peuvent être déformées. Fiez-vous au signal, pas à vos yeux."
            )
        }
    }

    // MARK: - Mission clearance (onboarding bridge screen)
    var missionControlEncryptedLink: String { t("MISSION CONTROL  ·  ENCRYPTED LINK",   "CONTROL DE MISIÓN  ·  ENLACE CIFRADO",    "CONTRÔLE MISSION  ·  LIEN CHIFFRÉ") }
    var clearanceGranted:            String { t("CLEARANCE GRANTED",                    "AUTORIZACIÓN CONCEDIDA",                   "AUTORISATION ACCORDÉE") }
    var missionReadyTitle:           String { t("MISSION READY",                        "MISIÓN LISTA",                             "MISSION PRÊTE") }
    var clearedForFirstMission:      String { t("You are cleared for your first mission.", "Estás autorizado para tu primera misión.", "Tu es autorisé pour ta première mission.") }
    var mission1EarthOrbit:          String { t("MISSION 1  ·  EARTH ORBIT",            "MISIÓN 1  ·  ÓRBITA TERRESTRE",            "MISSION 1  ·  ORBITE TERRESTRE") }
    var launchMission:               String { t("LAUNCH MISSION",                       "LANZAR MISIÓN",                            "LANCER LA MISSION") }

    // MARK: - Story beat UI labels
    var incomingTransmission: String { t("INCOMING TRANSMISSION", "TRANSMISIÓN ENTRANTE", "TRANSMISSION ENTRANTE") }
    var acknowledge:          String { t("ACKNOWLEDGE",           "RECONOCER",            "RECONNAÎTRE") }
    var understoodCTA:        String { t("UNDERSTOOD",            "ENTENDIDO",            "COMPRIS") }

    /// Returns the localized version of a story beat footer hint.
    /// The English text is used as the key; falls back to the original string for unknown hints.
    func storyFooterHint(_ hint: String) -> String {
        switch hint {
        case "EARTH ORBIT SECTOR ACTIVE":     return t(hint, "SECTOR ÓRBITA TERRESTRE ACTIVO",          "SECTEUR ORBITE TERRESTRE ACTIF")
        case "MISSION 1 LOADED":              return t(hint, "MISIÓN 1 CARGADA",                         "MISSION 1 CHARGÉE")
        case "NEXT WINDOW: 24H":             return t(hint, "PRÓXIMA VENTANA: 24H",                     "PROCHAINE FENÊTRE: 24H")
        case "LUNAR APPROACH UNLOCKED":       return t(hint, "LLEGADA LUNAR DESBLOQUEADA",               "APPROCHE LUNAIRE DÉBLOQUÉE")
        case "MARS SECTOR UNLOCKED":          return t(hint, "SECTOR MARTE DESBLOQUEADO",                "SECTEUR MARS DÉBLOQUÉ")
        case "ASTEROID BELT ROUTE OPEN":      return t(hint, "RUTA DEL CINTURÓN ABIERTA",               "ROUTE DE LA CEINTURE OUVERTE")
        case "JUPITER RELAY APPROACH OPEN":   return t(hint, "ACCESO AL RELÉ JÚPITER ABIERTO",          "ACCÈS AU RELAIS JUPITER OUVERT")
        case "SATURN RING SECTOR OPEN":       return t(hint, "SECTOR ANILLOS DE SATURNO ABIERTO",       "SECTEUR ANNEAUX DE SATURNE OUVERT")
        case "URANUS VOID SECTOR OPEN":       return t(hint, "SECTOR VACÍO DE URANO ABIERTO",           "SECTEUR VIDE D'URANUS OUVERT")
        case "NEPTUNE DEEP SECTOR OPEN":      return t(hint, "SECTOR PROFUNDO DE NEPTUNO ABIERTO",      "SECTEUR PROFOND DE NEPTUNE OUVERT")
        case "FULL NETWORK OPERATIONAL":      return t(hint, "RED COMPLETA OPERATIVA",                   "RÉSEAU COMPLET OPÉRATIONNEL")
        case "RANK: PILOT":                   return t(hint, "RANGO: PILOTO",                             "RANG: PILOTE")
        case "RANK: NAVIGATOR":               return t(hint, "RANGO: NAVEGANTE",                          "RANG: NAVIGATEUR")
        case "RANK: COMMANDER":               return t(hint, "RANGO: COMANDANTE",                         "RANG: COMMANDANT")
        case "ROTATION LIMIT ACTIVE":         return t(hint, "LÍMITE DE ROTACIÓN ACTIVO",                "LIMITE DE ROTATION ACTIVE")
        case "TWO-TAP PROTOCOL ACTIVE":       return t(hint, "PROTOCOLO DE DOS TOQUES ACTIVO",           "PROTOCOLE À DEUX TOUCHES ACTIF")
        case "AUTO-DRIFT ACTIVE":             return t(hint, "DERIVA AUTOMÁTICA ACTIVA",                 "DÉRIVE AUTOMATIQUE ACTIVE")
        case "ONE-WAY RELAY ACTIVE":          return t(hint, "RELÉ UNIDIRECCIONAL ACTIVO",               "RELAIS UNIDIRECTIONNEL ACTIF")
        case "FRAGILE RELAY ACTIVE":          return t(hint, "RELÉ FRÁGIL ACTIVO",                       "RELAIS FRAGILE ACTIF")
        case "CHARGE GATE ACTIVE":            return t(hint, "COMPUERTA DE CARGA ACTIVA",                "PORTE DE CHARGE ACTIVE")
        case "INTERFERENCE ZONE ACTIVE":      return t(hint, "ZONA DE INTERFERENCIA ACTIVA",             "ZONE D'INTERFÉRENCE ACTIVE")
        case "TIME LIMIT ACTIVE":             return t(hint, "LÍMITE DE TIEMPO ACTIVO",                  "LIMITE DE TEMPS ACTIVE")
        case "ASTEROID BELT UNLOCKED":        return t(hint, "CINTURÓN DE ASTEROIDES DESBLOQUEADO",     "CEINTURE D'ASTÉROÏDES DÉBLOQUÉE")
        case "JUPITER RELAY UNLOCKED":        return t(hint, "RELÉ JÚPITER DESBLOQUEADO",                "RELAIS JUPITER DÉBLOQUÉ")
        case "SATURN RING SECTOR UNLOCKED":   return t(hint, "SECTOR ANILLOS DE SATURNO DESBLOQUEADO",  "SECTEUR ANNEAUX DE SATURNE DÉBLOQUÉ")
        case "URANUS VOID UNLOCKED":          return t(hint, "VACÍO DE URANO DESBLOQUEADO",              "VIDE D'URANUS DÉBLOQUÉ")
        case "NEPTUNE DEEP UNLOCKED":         return t(hint, "PROFUNDO NEPTUNO DESBLOQUEADO",            "NEPTUNE PROFOND DÉBLOQUÉ")
        case "SECTOR 2 — LUNAR APPROACH":    return t(hint, "SECTOR 2 — LLEGADA LUNAR",                 "SECTEUR 2 — APPROCHE LUNAIRE")
        case "SECTOR 3 — MARS SECTOR":       return t(hint, "SECTOR 3 — SECTOR MARTE",                  "SECTEUR 3 — SECTEUR MARS")
        case "SECTOR 4 — ASTEROID BELT":     return t(hint, "SECTOR 4 — CINTURÓN DE ASTEROIDES",       "SECTEUR 4 — CEINTURE D'ASTÉROÏDES")
        case "SECTOR 5 — JUPITER RELAY":     return t(hint, "SECTOR 5 — RELÉ JÚPITER",                 "SECTEUR 5 — RELAIS JUPITER")
        case "SECTOR 6 — SATURN RING":       return t(hint, "SECTOR 6 — ANILLOS DE SATURNO",           "SECTEUR 6 — ANNEAUX DE SATURNE")
        case "SECTOR 7 — URANUS VOID":       return t(hint, "SECTOR 7 — VACÍO DE URANO",               "SECTEUR 7 — VIDE D'URANUS")
        case "SECTOR 8 — NEPTUNE DEEP":      return t(hint, "SECTOR 8 — NEPTUNO PROFUNDO",             "SECTEUR 8 — NEPTUNE PROFOND")
        default: return hint
        }
    }

    func storyTriggerLabel(_ trigger: StoryTrigger) -> String {
        switch trigger {
        case .firstLaunch:          return t("MISSION BRIEF",       "INFORME DE MISIÓN",       "BRIEFING MISSION")
        case .firstMissionReady:    return t("MISSION READY",       "MISIÓN LISTA",            "MISSION PRÊTE")
        case .firstMissionComplete: return t("MISSION REPORT",      "INFORME DE MISIÓN",       "RAPPORT DE MISSION")
        case .onboardingComplete:   return t("GATE ACTIVE",         "COMPUERTA ACTIVA",        "PORTE ACTIVE")
        case .sectorComplete:       return t("SECTOR CLEARED",      "SECTOR DESPEJADO",        "SECTEUR DÉGAGÉ")
        case .passUnlocked:         return t("PASS ISSUED",         "PASE EMITIDO",            "LAISSEZ-PASSER ÉMIS")
        case .rankUp:               return t("RANK UPDATE",         "ACTUALIZACIÓN DE RANGO",  "MISE À JOUR DU RANG")
        case .mechanicUnlocked:     return t("FIELD ALERT",         "ALERTA DE CAMPO",         "ALERTE TERRAIN")
        case .enteringNewSector:    return t("NEW SECTOR",          "NUEVO SECTOR",            "NOUVEAU SECTEUR")
        }
    }

    // MARK: - Upgrade / monetization CTAs
    var unlimitedAccess:          String { t("UNLIMITED ACCESS",          "ACCESO ILIMITADO",          "ACCÈS ILLIMITÉ") }
    var continueWithoutLimits:    String { t("CONTINUE WITHOUT LIMITS",   "CONTINÚA SIN LÍMITES",      "CONTINUER SANS LIMITES") }
    var upgradeLabel:             String { t("UPGRADE",                   "MEJORAR",                   "AMÉLIORER") }
    var unlockUnlimitedAccess:    String { t("UNLOCK UNLIMITED ACCESS",   "DESBLOQUEAR ACCESO",        "DÉBLOQUER L'ACCÈS") }
    var playWithoutDailyLimit:    String { t("Play without daily limit",  "Juega sin límite diario",   "Joue sans limite quotidienne") }
    var gateLocked:               String { t("ACCESS LOCKED",             "ACCESO BLOQUEADO",          "ACCÈS VERROUILLÉ") }
    var availableIn:              String { t("Available in",              "Disponible en",             "Disponible dans") }
    var cooldownActive:           String { t("NEXT WINDOW OPENS IN",      "PRÓXIMA VENTANA EN",        "PROCHAINE FENÊTRE DANS") }
    var upgradeForInstantAccess:  String { t("Upgrade for instant access","Mejora para acceso inmediato","Améliorer pour accès immédiat") }
    var keepPlayingWithoutWaiting: String { t("Keep playing without waiting", "Sigue jugando sin esperas", "Continuez sans attendre") }
    var leaderboard:               String { t("RANKING",   "CLASIFICACIÓN", "CLASSEMENT") }
    var connectForLeaderboard:     String { t("CONNECT",   "CONECTAR",  "CONNECTER") }
    func backIn(_ time: String) -> String { t("Back in \(time)", "Vuelve a jugar en \(time)", "De retour dans \(time)") }
    func dailyPlaysLabel(used: Int, limit: Int) -> String {
        t("\(used)/\(limit) missions used today",
          "\(used)/\(limit) misiones usadas hoy",
          "\(used)/\(limit) missions utilisées aujourd'hui")
    }

    // MARK: - Paywall
    var paywallTitle:           String { t("Unlock Signal Void",               "Desbloquea Signal Void",                "Débloquez Signal Void") }
    var paywallSubtitle:        String { t("Play all 180 levels without limits","Juega sin límites los 180 niveles",     "Jouez aux 180 niveaux sans limite") }
    var paywallFeatureLevels:   String { t("Full access to all 180 levels",    "Acceso completo a los 180 niveles",     "Accès complet aux 180 niveaux") }
    var paywallFeatureNoLimit:  String { t("No daily mission limit",           "Sin límite diario de misiones",         "Aucune limite quotidienne de missions") }
    var paywallFeatureOneTime:  String { t("One-time payment, forever",        "Pago único, para siempre",              "Paiement unique, pour toujours") }
    var paywallFeatureFamily:   String { t("Family Sharing supported",         "Compatible con Compartir en familia",   "Compatible avec le Partage familial") }
    func paywallCtaBuy(_ price: String) -> String { t("Unlock for \(price)", "Desbloquear por \(price)", "Débloquer pour \(price)") }
    var paywallCtaRestore:      String { t("Restore Purchases",                "Restaurar compras",                     "Restaurer les achats") }
    var paywallLegal:           String { t("One-time payment. No subscriptions.", "Pago único. Sin suscripciones.",     "Paiement unique. Sans abonnement.") }
    var paywallLoading:         String { t("Loading…",                         "Cargando…",                             "Chargement…") }

    // MARK: - Daily limit screen
    var limitTitle:             String { t("Missions exhausted",                       "Misiones agotadas",                        "Missions épuisées") }
    var limitSubtitle:          String { t("You've completed your 3 missions for today","Has completado tus 3 misiones de hoy",     "Vous avez terminé vos 3 missions du jour") }
    func limitCountdown(_ time: String) -> String { t("New missions in \(time)", "Nuevas misiones en \(time)", "Nouvelles missions dans \(time)") }
    var limitCtaUnlock:         String { t("Unlock full game",                 "Desbloquear juego completo",            "Débloquer le jeu complet") }
    var limitCtaWait:           String { t("Wait until tomorrow",              "Esperar a mañana",                      "Attendre demain") }

    // MARK: - Purchase states
    var purchaseSuccessTitle:   String { t("Game unlocked!",                   "¡Juego desbloqueado!",                  "Jeu débloqué !") }
    var purchaseSuccessMessage: String { t("Enjoy all 180 levels without limits.","Disfruta de los 180 niveles sin límites.","Profitez des 180 niveaux sans limite.") }
    var purchaseRestoredTitle:  String { t("Purchase restored",                "Compra restaurada",                     "Achat restauré") }
    var purchaseRestoredMessage: String { t("Your full access has been restored.","Tu acceso completo ha sido restaurado.","Votre accès complet a été restauré.") }
    var purchaseErrorTitle:     String { t("Purchase failed",                  "No se pudo completar la compra",        "Échec de l'achat") }
    var purchaseErrorGeneric:   String { t("Please try again later.",          "Inténtalo de nuevo más tarde.",         "Veuillez réessayer plus tard.") }
    var purchaseErrorCancelled: String { t("Purchase cancelled.",              "Compra cancelada.",                     "Achat annulé.") }
    var purchaseErrorNetwork:   String { t("No connection. Check your network.","Sin conexión. Revisa tu red.",         "Pas de connexion. Vérifiez votre réseau.") }
    var purchaseErrorNotAllowed: String { t("In-app purchases are restricted on this device.","Las compras están restringidas en este dispositivo.","Les achats intégrés sont restreints sur cet appareil.") }
    var purchaseAlreadyOwned:   String { t("You already own the full game.",   "Ya tienes el juego completo.",          "Vous possédez déjà le jeu complet.") }

    // MARK: - Discount codes
    var discountCodePlaceholder: String { t("Discount code",     "Código de descuento", "Code de réduction") }
    var applyCode:               String { t("APPLY",             "APLICAR",             "APPLIQUER") }
    var discountValid:           String { t("Code applied",      "Código aplicado",     "Code appliqué") }
    var discountInvalid:         String { t("Invalid code",      "Código inválido",     "Code invalide") }
    var discountExpired:         String { t("Code expired",      "Código expirado",     "Code expiré") }
    var discountInactive:        String { t("Code not active",   "Código inactivo",     "Code inactif") }
    var discountExhausted:       String { t("Usage limit reached","Límite de usos alcanzado","Limite d'utilisations atteinte") }
    func discountOff(_ pct: Int) -> String { t("\(pct)% off", "\(pct)% de descuento", "\(pct)% de réduction") }
    func discountedPrice(original: String, discounted: String) -> String {
        t("\(original) → \(discounted)", "\(original) → \(discounted)", "\(original) → \(discounted)")
    }

    // MARK: - Legal
    var legalSection:    String { t("LEGAL",                "LEGAL",                 "LÉGAL") }
    var termsTitle:      String { t("TERMS & CONDITIONS",   "TÉRMINOS Y CONDICIONES","CONDITIONS D'UTILISATION") }
    var termsSub:        String { t("Usage terms",          "Términos de uso",       "Conditions d'usage") }
    var privacyTitle:    String { t("PRIVACY POLICY",       "POLÍTICA DE PRIVACIDAD","POLITIQUE DE CONFIDENTIALITÉ") }
    var privacySub:      String { t("Data & privacy",       "Datos y privacidad",    "Données et vie privée") }

    var termsBody: String {
        t(
            """
            SIGNAL VOID — TERMS & CONDITIONS

            Last updated: April 2025

            1. ACCEPTANCE
            By downloading, installing, or using Signal Void ("the App"), you agree to these Terms & Conditions. If you do not agree, do not use the App.

            2. LICENSE
            We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial entertainment on Apple devices you own or control, subject to the Apple Licensed Application End User License Agreement (EULA).

            3. FREE AND PREMIUM ACCESS
            The App offers a free tier with a limited number of daily missions. After the introductory period, free users may play a set number of missions per day with a cooldown period between sessions. A one-time in-app purchase ("Unlimited Access") removes all daily limits permanently.

            4. IN-APP PURCHASES
            The App offers an optional one-time purchase processed exclusively by Apple through the App Store. All transactions are subject to Apple's terms and conditions. Purchases are non-refundable except as required by applicable law. Refund requests must be directed to Apple. The purchase is tied to your Apple ID and can be restored on any device signed into the same account.

            5. APPLE GAME CENTER
            The App integrates with Apple Game Center for leaderboard functionality. By using this feature you agree to Apple's Game Center terms. No additional account creation is required by Signal Void.

            6. ICLOUD SYNC
            If iCloud is enabled on your device, the App may sync your game progress (mission completions, scores, and progression data) to your personal iCloud account. This sync is managed entirely by Apple's infrastructure. You can disable this in your device's Settings > iCloud.

            7. USER CONDUCT
            You agree not to: reverse-engineer, decompile, or disassemble the App; use the App for unlawful purposes; exploit bugs or glitches to gain unfair advantages; attempt to circumvent daily play limits or purchase verification; distribute modified versions of the App.

            8. INTELLECTUAL PROPERTY
            All content, code, graphics, audio, music, and design in the App are the exclusive property of the developer and protected by copyright and intellectual property laws. You may not reproduce, distribute, or create derivative works from any part of the App without prior written permission.

            9. DISCLAIMERS
            The App is provided "as is" without warranties of any kind, express or implied. We do not guarantee uninterrupted or error-free operation. Game progress may be lost due to device failure, software updates, or other circumstances beyond our control. We reserve the right to modify, suspend, or discontinue the App at any time without notice.

            10. LIMITATION OF LIABILITY
            To the maximum extent permitted by applicable law, the developer shall not be liable for any indirect, incidental, special, or consequential damages arising from or related to the use or inability to use the App, including but not limited to loss of game progress or data.

            11. GOVERNING LAW
            These Terms are governed by the laws of Spain. Any disputes arising from or related to these Terms shall be subject to the exclusive jurisdiction of the courts of Spain, without prejudice to mandatory consumer protection laws of your country of residence.

            12. CHANGES
            We may update these Terms at any time by publishing a new version within the App. Continued use after changes constitutes acceptance of the updated Terms.

            13. CONTACT
            For questions about these Terms, contact: marcosnovodev@gmail.com
            """,
            """
            SIGNAL VOID — TÉRMINOS Y CONDICIONES

            Última actualización: Abril 2025

            1. ACEPTACIÓN
            Al descargar, instalar o usar Signal Void ("la App"), aceptas estos Términos y Condiciones. Si no estás de acuerdo, no uses la App.

            2. LICENCIA
            Te otorgamos una licencia limitada, no exclusiva, intransferible y revocable para usar la App con fines de entretenimiento personal y no comercial en dispositivos Apple que poseas o controles, sujeta al Acuerdo de Licencia de Usuario Final (EULA) de Apple.

            3. ACCESO GRATUITO Y PREMIUM
            La App ofrece un nivel gratuito con un número limitado de misiones diarias. Tras el periodo introductorio, los usuarios gratuitos pueden jugar un número determinado de misiones por día con un periodo de espera entre sesiones. Una compra única ("Acceso Ilimitado") elimina todos los límites diarios de forma permanente.

            4. COMPRAS DENTRO DE LA APP
            La App ofrece una compra opcional única procesada exclusivamente por Apple a través de la App Store. Todas las transacciones están sujetas a los términos y condiciones de Apple. Las compras no son reembolsables, excepto cuando lo exija la ley aplicable. Las solicitudes de reembolso deben dirigirse a Apple. La compra está vinculada a tu Apple ID y puede restaurarse en cualquier dispositivo con la misma cuenta.

            5. APPLE GAME CENTER
            La App se integra con Apple Game Center para la funcionalidad de clasificaciones. Al usar esta función, aceptas los términos de Game Center de Apple. Signal Void no requiere la creación de cuentas adicionales.

            6. SINCRONIZACIÓN ICLOUD
            Si iCloud está habilitado en tu dispositivo, la App puede sincronizar tu progreso de juego (misiones completadas, puntuaciones y datos de progresión) en tu cuenta personal de iCloud. Esta sincronización es gestionada íntegramente por la infraestructura de Apple. Puedes desactivarla en Ajustes > iCloud de tu dispositivo.

            7. CONDUCTA DEL USUARIO
            Te comprometes a no: realizar ingeniería inversa, descompilar o desensamblar la App; usar la App con fines ilegales; explotar errores o fallos para obtener ventajas injustas; intentar eludir los límites diarios de juego o la verificación de compras; distribuir versiones modificadas de la App.

            8. PROPIEDAD INTELECTUAL
            Todo el contenido, código, gráficos, audio, música y diseño de la App son propiedad exclusiva del desarrollador y están protegidos por las leyes de derechos de autor y propiedad intelectual. No puedes reproducir, distribuir ni crear obras derivadas de ninguna parte de la App sin permiso previo por escrito.

            9. DESCARGOS DE RESPONSABILIDAD
            La App se proporciona "tal cual", sin garantías de ningún tipo, expresas o implícitas. No garantizamos un funcionamiento ininterrumpido ni libre de errores. El progreso del juego puede perderse debido a fallos del dispositivo, actualizaciones de software u otras circunstancias fuera de nuestro control. Nos reservamos el derecho de modificar, suspender o descontinuar la App en cualquier momento sin previo aviso.

            10. LIMITACIÓN DE RESPONSABILIDAD
            En la máxima medida permitida por la ley aplicable, el desarrollador no será responsable de ningún daño indirecto, incidental, especial o consecuente derivado de o relacionado con el uso o la imposibilidad de uso de la App, incluyendo pero no limitado a la pérdida de progreso o datos del juego.

            11. LEY APLICABLE
            Estos Términos se rigen por las leyes de España. Cualquier disputa derivada de o relacionada con estos Términos estará sujeta a la jurisdicción exclusiva de los tribunales de España, sin perjuicio de las leyes obligatorias de protección al consumidor de tu país de residencia.

            12. CAMBIOS
            Podemos actualizar estos Términos en cualquier momento publicando una nueva versión dentro de la App. El uso continuado tras los cambios constituye la aceptación de los Términos actualizados.

            13. CONTACTO
            Para preguntas sobre estos Términos, contacta: marcosnovodev@gmail.com
            """,
            """
            SIGNAL VOID — CONDITIONS D'UTILISATION

            Dernière mise à jour : Avril 2025

            1. ACCEPTATION
            En téléchargeant, installant ou utilisant Signal Void (« l'Application »), vous acceptez les présentes Conditions d'Utilisation. Si vous n'êtes pas d'accord, n'utilisez pas l'Application.

            2. LICENCE
            Nous vous accordons une licence limitée, non exclusive, non transférable et révocable pour utiliser l'Application à des fins de divertissement personnel et non commercial sur des appareils Apple que vous possédez ou contrôlez, conformément au Contrat de Licence Utilisateur Final (EULA) d'Apple.

            3. ACCÈS GRATUIT ET PREMIUM
            L'Application propose un niveau gratuit avec un nombre limité de missions quotidiennes. Après la période d'introduction, les utilisateurs gratuits peuvent jouer un nombre défini de missions par jour avec un délai d'attente entre les sessions. Un achat unique (« Accès Illimité ») supprime définitivement toutes les limites quotidiennes.

            4. ACHATS INTÉGRÉS
            L'Application propose un achat unique optionnel traité exclusivement par Apple via l'App Store. Toutes les transactions sont soumises aux conditions générales d'Apple. Les achats ne sont pas remboursables, sauf si la loi l'exige. Les demandes de remboursement doivent être adressées à Apple. L'achat est lié à votre identifiant Apple et peut être restauré sur tout appareil connecté au même compte.

            5. APPLE GAME CENTER
            L'Application s'intègre à Apple Game Center pour la fonctionnalité de classement. En utilisant cette fonctionnalité, vous acceptez les conditions de Game Center d'Apple. Signal Void ne nécessite aucune création de compte supplémentaire.

            6. SYNCHRONISATION ICLOUD
            Si iCloud est activé sur votre appareil, l'Application peut synchroniser votre progression (missions terminées, scores et données de progression) dans votre compte iCloud personnel. Cette synchronisation est entièrement gérée par l'infrastructure d'Apple. Vous pouvez la désactiver dans Réglages > iCloud de votre appareil.

            7. CONDUITE DE L'UTILISATEUR
            Vous vous engagez à ne pas : effectuer de rétro-ingénierie, décompiler ou désassembler l'Application ; utiliser l'Application à des fins illégales ; exploiter des bugs ou des failles pour obtenir des avantages injustes ; tenter de contourner les limites quotidiennes de jeu ou la vérification des achats ; distribuer des versions modifiées de l'Application.

            8. PROPRIÉTÉ INTELLECTUELLE
            Tout le contenu, le code, les graphismes, l'audio, la musique et le design de l'Application sont la propriété exclusive du développeur et protégés par les lois sur le droit d'auteur et la propriété intellectuelle. Vous ne pouvez reproduire, distribuer ni créer d'œuvres dérivées d'aucune partie de l'Application sans autorisation écrite préalable.

            9. CLAUSE DE NON-RESPONSABILITÉ
            L'Application est fournie « en l'état », sans garantie d'aucune sorte, expresse ou implicite. Nous ne garantissons pas un fonctionnement ininterrompu ou exempt d'erreurs. La progression du jeu peut être perdue en raison de pannes d'appareil, de mises à jour logicielles ou d'autres circonstances indépendantes de notre volonté. Nous nous réservons le droit de modifier, suspendre ou interrompre l'Application à tout moment sans préavis.

            10. LIMITATION DE RESPONSABILITÉ
            Dans la mesure maximale permise par la loi applicable, le développeur ne pourra être tenu responsable de tout dommage indirect, accessoire, spécial ou consécutif découlant de ou lié à l'utilisation ou l'impossibilité d'utiliser l'Application, y compris mais sans s'y limiter, la perte de progression ou de données de jeu.

            11. LOI APPLICABLE
            Les présentes Conditions sont régies par les lois d'Espagne. Tout litige découlant de ou lié aux présentes Conditions sera soumis à la compétence exclusive des tribunaux d'Espagne, sans préjudice des lois impératives de protection des consommateurs de votre pays de résidence.

            12. MODIFICATIONS
            Nous pouvons mettre à jour ces Conditions à tout moment en publiant une nouvelle version dans l'Application. L'utilisation continue après les modifications vaut acceptation des Conditions mises à jour.

            13. CONTACT
            Pour toute question concernant ces Conditions, contactez : marcosnovodev@gmail.com
            """
        )
    }

    var privacyBody: String {
        t(
            """
            SIGNAL VOID — PRIVACY POLICY

            Last updated: April 2025

            1. OVERVIEW
            Signal Void ("the App") is designed with privacy as a core principle. We do not require user accounts, do not collect personal information, and do not send data to external servers.

            2. DATA PROCESSED BY APPLE SERVICES
            The App integrates exclusively with Apple's own services. The developer does not have direct access to the data processed by these services:
            • Apple Game Center — Your Game Center alias and efficiency scores are shared with Apple for leaderboard functionality. This data is governed by Apple's Privacy Policy.
            • iCloud — If enabled on your device, your game progress (mission completions, scores, planet passes, and progression data) is synced to your personal iCloud account. You can manage or delete this data in Settings > [your name] > iCloud.
            • App Store — If you make the optional in-app purchase, Apple processes the transaction. We do not receive or store any payment information.

            3. DATA STORED ON YOUR DEVICE
            The App stores the following data locally on your device using standard system storage:
            • Game progress (completed missions, scores, efficiency ratings)
            • User preferences (sound, music, haptics, language, motion settings)
            • Session data (daily play counts, cooldown timers)
            This data remains on your device and is not transmitted to any external server.

            4. DATA WE DO NOT COLLECT
            We do not collect, store, or transmit: names, email addresses, phone numbers, location data, device identifiers, advertising identifiers (IDFA), usage analytics, crash reports, or any personally identifiable information. The App does not use Apple's App Tracking Transparency framework because no tracking occurs.

            5. LOCAL NOTIFICATIONS
            The App may request permission to send local notifications (e.g., to inform you when a cooldown period ends). These notifications are generated and stored entirely on your device. No notification data is sent to external servers. You can disable notifications at any time in Settings > Notifications > Signal Void.

            6. THIRD-PARTY SERVICES
            The App does not integrate any third-party analytics, advertising, crash reporting, or tracking services. All functionality is provided through Apple's native frameworks.

            7. CHILDREN'S PRIVACY
            The App does not knowingly collect personal data from anyone, including children under the age of 13 (or applicable age in your jurisdiction). The minimal data processing described above (all handled by Apple's services) applies equally to all users regardless of age.

            8. DATA RETENTION AND DELETION
            Since we do not collect data on external servers, there is no data for us to retain or delete. Local game data can be removed by deleting the App from your device. iCloud data can be managed through your device's iCloud settings.

            9. INTERNATIONAL USERS
            The App does not transfer personal data across borders because it does not collect personal data. All data storage is either local to your device or within your personal iCloud account, managed by Apple according to their data processing policies.

            10. YOUR RIGHTS (GDPR / CCPA)
            Under the EU General Data Protection Regulation (GDPR) and the California Consumer Privacy Act (CCPA), you have rights regarding your personal data. Since Signal Void does not collect personal data, these rights are inherently fulfilled. For data stored by Apple's services (Game Center, iCloud, App Store), please refer to Apple's Privacy Policy and your device settings.

            11. CHANGES
            We may update this Privacy Policy at any time by publishing a new version within the App. Continued use after changes constitutes acceptance.

            12. CONTACT
            For privacy-related questions, contact: marcosnovodev@gmail.com
            """,
            """
            SIGNAL VOID — POLÍTICA DE PRIVACIDAD

            Última actualización: Abril 2025

            1. DESCRIPCIÓN GENERAL
            Signal Void ("la App") está diseñada con la privacidad como principio fundamental. No requerimos cuentas de usuario, no recopilamos información personal y no enviamos datos a servidores externos.

            2. DATOS PROCESADOS POR SERVICIOS DE APPLE
            La App se integra exclusivamente con los propios servicios de Apple. El desarrollador no tiene acceso directo a los datos procesados por estos servicios:
            • Apple Game Center — Tu alias y puntuaciones de eficiencia de Game Center se comparten con Apple para la funcionalidad de clasificaciones. Estos datos se rigen por la Política de Privacidad de Apple.
            • iCloud — Si está habilitado en tu dispositivo, tu progreso de juego (misiones completadas, puntuaciones, pases planetarios y datos de progresión) se sincroniza en tu cuenta personal de iCloud. Puedes gestionar o eliminar estos datos en Ajustes > [tu nombre] > iCloud.
            • App Store — Si realizas la compra opcional, Apple procesa la transacción. No recibimos ni almacenamos ninguna información de pago.

            3. DATOS ALMACENADOS EN TU DISPOSITIVO
            La App almacena los siguientes datos localmente en tu dispositivo mediante el almacenamiento estándar del sistema:
            • Progreso del juego (misiones completadas, puntuaciones, calificaciones de eficiencia)
            • Preferencias de usuario (sonido, música, hápticos, idioma, ajustes de movimiento)
            • Datos de sesión (conteo de partidas diarias, temporizadores de espera)
            Estos datos permanecen en tu dispositivo y no se transmiten a ningún servidor externo.

            4. DATOS QUE NO RECOPILAMOS
            No recopilamos, almacenamos ni transmitimos: nombres, direcciones de correo electrónico, números de teléfono, datos de ubicación, identificadores de dispositivo, identificadores publicitarios (IDFA), análisis de uso, informes de errores ni ninguna información de identificación personal. La App no utiliza el framework App Tracking Transparency de Apple porque no se realiza ningún seguimiento.

            5. NOTIFICACIONES LOCALES
            La App puede solicitar permiso para enviar notificaciones locales (por ejemplo, para informarte cuando termina un periodo de espera). Estas notificaciones se generan y almacenan completamente en tu dispositivo. No se envían datos de notificación a servidores externos. Puedes desactivar las notificaciones en cualquier momento en Ajustes > Notificaciones > Signal Void.

            6. SERVICIOS DE TERCEROS
            La App no integra ningún servicio de análisis, publicidad, informes de errores ni seguimiento de terceros. Toda la funcionalidad se proporciona a través de los frameworks nativos de Apple.

            7. PRIVACIDAD DE MENORES
            La App no recopila conscientemente datos personales de nadie, incluidos menores de 13 años (o la edad aplicable en tu jurisdicción). El procesamiento mínimo de datos descrito anteriormente (todo gestionado por los servicios de Apple) se aplica por igual a todos los usuarios independientemente de su edad.

            8. RETENCIÓN Y ELIMINACIÓN DE DATOS
            Dado que no recopilamos datos en servidores externos, no hay datos que retener o eliminar por nuestra parte. Los datos locales del juego pueden eliminarse borrando la App de tu dispositivo. Los datos de iCloud pueden gestionarse a través de los ajustes de iCloud de tu dispositivo.

            9. USUARIOS INTERNACIONALES
            La App no transfiere datos personales a través de fronteras porque no recopila datos personales. Todo el almacenamiento de datos es local en tu dispositivo o dentro de tu cuenta personal de iCloud, gestionada por Apple según sus políticas de procesamiento de datos.

            10. TUS DERECHOS (RGPD / CCPA)
            Bajo el Reglamento General de Protección de Datos (RGPD) de la UE y la Ley de Privacidad del Consumidor de California (CCPA), tienes derechos sobre tus datos personales. Dado que Signal Void no recopila datos personales, estos derechos se cumplen inherentemente. Para datos almacenados por los servicios de Apple (Game Center, iCloud, App Store), consulta la Política de Privacidad de Apple y los ajustes de tu dispositivo.

            11. CAMBIOS
            Podemos actualizar esta Política de Privacidad en cualquier momento publicando una nueva versión dentro de la App. El uso continuado tras los cambios constituye su aceptación.

            12. CONTACTO
            Para preguntas relacionadas con la privacidad, contacta: marcosnovodev@gmail.com
            """,
            """
            SIGNAL VOID — POLITIQUE DE CONFIDENTIALITÉ

            Dernière mise à jour : Avril 2025

            1. APERÇU
            Signal Void (« l'Application ») est conçue avec le respect de la vie privée comme principe fondamental. Nous ne nécessitons pas de compte utilisateur, ne collectons pas d'informations personnelles et n'envoyons pas de données à des serveurs externes.

            2. DONNÉES TRAITÉES PAR LES SERVICES APPLE
            L'Application s'intègre exclusivement aux propres services d'Apple. Le développeur n'a pas d'accès direct aux données traitées par ces services :
            • Apple Game Center — Votre alias et vos scores d'efficacité Game Center sont partagés avec Apple pour la fonctionnalité de classement. Ces données sont régies par la Politique de Confidentialité d'Apple.
            • iCloud — Si activé sur votre appareil, votre progression (missions terminées, scores, laissez-passer planétaires et données de progression) est synchronisée dans votre compte iCloud personnel. Vous pouvez gérer ou supprimer ces données dans Réglages > [votre nom] > iCloud.
            • App Store — Si vous effectuez l'achat optionnel, Apple traite la transaction. Nous ne recevons ni ne stockons aucune information de paiement.

            3. DONNÉES STOCKÉES SUR VOTRE APPAREIL
            L'Application stocke les données suivantes localement sur votre appareil via le stockage système standard :
            • Progression du jeu (missions terminées, scores, notes d'efficacité)
            • Préférences utilisateur (son, musique, haptique, langue, réglages de mouvement)
            • Données de session (compteur de parties quotidiennes, minuteries d'attente)
            Ces données restent sur votre appareil et ne sont transmises à aucun serveur externe.

            4. DONNÉES QUE NOUS NE COLLECTONS PAS
            Nous ne collectons, ne stockons ni ne transmettons : noms, adresses e-mail, numéros de téléphone, données de localisation, identifiants d'appareil, identifiants publicitaires (IDFA), analyses d'utilisation, rapports de plantage, ni aucune information personnelle identifiable. L'Application n'utilise pas le framework App Tracking Transparency d'Apple car aucun suivi n'est effectué.

            5. NOTIFICATIONS LOCALES
            L'Application peut demander l'autorisation d'envoyer des notifications locales (par exemple, pour vous informer de la fin d'un délai d'attente). Ces notifications sont générées et stockées entièrement sur votre appareil. Aucune donnée de notification n'est envoyée à des serveurs externes. Vous pouvez désactiver les notifications à tout moment dans Réglages > Notifications > Signal Void.

            6. SERVICES TIERS
            L'Application n'intègre aucun service d'analyse, de publicité, de rapport de plantage ou de suivi tiers. Toutes les fonctionnalités sont fournies via les frameworks natifs d'Apple.

            7. VIE PRIVÉE DES ENFANTS
            L'Application ne collecte sciemment aucune donnée personnelle de quiconque, y compris des enfants de moins de 13 ans (ou l'âge applicable dans votre juridiction). Le traitement minimal des données décrit ci-dessus (entièrement géré par les services d'Apple) s'applique également à tous les utilisateurs, quel que soit leur âge.

            8. CONSERVATION ET SUPPRESSION DES DONNÉES
            Comme nous ne collectons pas de données sur des serveurs externes, il n'y a pas de données à conserver ou supprimer de notre côté. Les données locales du jeu peuvent être supprimées en désinstallant l'Application de votre appareil. Les données iCloud peuvent être gérées via les réglages iCloud de votre appareil.

            9. UTILISATEURS INTERNATIONAUX
            L'Application ne transfère pas de données personnelles au-delà des frontières car elle ne collecte pas de données personnelles. Tout le stockage de données est soit local sur votre appareil, soit dans votre compte iCloud personnel, géré par Apple conformément à ses politiques de traitement des données.

            10. VOS DROITS (RGPD / CCPA)
            En vertu du Règlement Général sur la Protection des Données (RGPD) de l'UE et du California Consumer Privacy Act (CCPA), vous disposez de droits concernant vos données personnelles. Comme Signal Void ne collecte pas de données personnelles, ces droits sont intrinsèquement respectés. Pour les données stockées par les services d'Apple (Game Center, iCloud, App Store), veuillez consulter la Politique de Confidentialité d'Apple et les réglages de votre appareil.

            11. MODIFICATIONS
            Nous pouvons mettre à jour cette Politique de Confidentialité à tout moment en publiant une nouvelle version dans l'Application. L'utilisation continue après les modifications vaut acceptation.

            12. CONTACT
            Pour toute question relative à la vie privée, contactez : marcosnovodev@gmail.com
            """
        )
    }

    // MARK: - Local notifications
    var notifCooldownTitle: String { t("The network is live again",
                                       "La red vuelve a estar disponible",
                                       "Le réseau est de nouveau disponible") }
    var notifCooldownBody:  String { t("You can play again in Signal Void.",
                                       "Ya puedes volver a jugar en Signal Void.",
                                       "Vous pouvez rejouer dans Signal Void.") }

    // MARK: - Home V2 / V3
    var play:        String { t("PLAY",          "JUGAR",               "JOUER") }
    var viewFullMap: String { t("VIEW FULL MAP", "VER MAPA COMPLETO",   "VOIR LA CARTE COMPLÈTE") }
    var inProgress:  String { t("IN PROGRESS",   "EN PROGRESO",         "EN COURS") }
    func resumeMissionLabel(_ id: String) -> String {
        t("CONTINUE MISSION \(id)", "CONTINUAR MISIÓN \(id)", "CONTINUER MISSION \(id)")
    }
    func missionsCompleted(done: Int, total: Int) -> String {
        t("\(done) of \(total) missions completed",
          "\(done) de \(total) misiones completadas",
          "\(done) sur \(total) missions terminées")
    }
    var missionsCompletedShort: String { t("missions completed", "misiones completadas", "missions terminées") }

    // MARK: - Victory telemetry
    var missionDebrief:  String { t("MISSION\nDEBRIEF",  "INFORME\nDE MISIÓN",  "COMPTE-RENDU\nDE MISSION") }
    var missionQuality:  String { t("MISSION QUALITY",   "CALIDAD DE MISIÓN",   "QUALITÉ DE MISSION") }
    var usedMin:         String { t("USED / MIN",         "USADO / MÍN",         "UTILISÉ / MIN") }
    var missionScore:    String { t("MISSION SCORE",      "PUNTUACIÓN MISIÓN",   "SCORE MISSION") }
    var rankingTotal:    String { t("RANKING TOTAL",      "TOTAL RANKING",       "TOTAL CLASSEMENT") }
    var maxLabel:        String { t("MAX",                "MÁX",                 "MAX") }
    var retryLabel:      String { t("RETRY",              "REINTENTAR",          "RÉESSAYER") }
    var shareLabel:      String { t("SHARE",              "COMPARTIR",           "PARTAGER") }
    var mapLabel:        String { t("MAP",                "MAPA",                "CARTE") }

    func nextMissionLabel(_ displayID: String) -> String {
        t("MISSION \(displayID)", "MISIÓN \(displayID)", "MISSION \(displayID)")
    }

    func routeRating(_ eff: Float) -> String {
        switch eff {
        case 0.95...: return t("OPTIMAL",    "ÓPTIMO",     "OPTIMAL")
        case 0.80...: return t("EFFICIENT",  "EFICIENTE",  "EFFICACE")
        case 0.60...: return t("ADEQUATE",   "ADECUADO",   "ADÉQUAT")
        default:      return t("SUBOPTIMAL", "SUBÓPTIMO",  "SOUS-OPTIMAL")
        }
    }

    func routeMessage(_ eff: Float) -> String {
        switch eff {
        case 0.95...:
            return t("Optimal route achieved.",
                     "Ruta óptima conseguida.",
                     "Route optimale atteinte.")
        case 0.80...:
            return t("A more efficient route was possible.",
                     "Una ruta más eficiente era posible.",
                     "Un itinéraire plus efficace était possible.")
        case 0.60...:
            return t("Mission complete. A more efficient route was possible.",
                     "Misión completada. Una ruta más eficiente era posible.",
                     "Mission accomplie. Un itinéraire plus efficace était possible.")
        default:
            return t("You completed the mission, but not with the most efficient network.",
                     "Misión completada, pero la red no fue la más eficiente.",
                     "Mission accomplie, mais le réseau n'était pas le plus efficace.")
        }
    }

    // MARK: - Astronaut rank
    func rankTitle(_ level: Int) -> String {
        switch level {
        case 1...2:  return t("CADET",     "CADETE",     "CADET")
        case 3...4:  return t("PILOT",     "PILOTO",     "PILOTE")
        case 5...6:  return t("NAVIGATOR", "NAVEGANTE",  "NAVIGATEUR")
        case 7...9:  return t("COMMANDER", "COMANDANTE", "COMMANDANT")
        default:     return t("ADMIRAL",   "ALMIRANTE",  "AMIRAL")
        }
    }

    // MARK: - Anti-frustration messages (loss overlay)
    /// Encouraging micro-message shown from the 2nd consecutive failure onward.
    func frustrationMessage(failures: Int) -> String {
        switch failures {
        case 2:  return t("ALMOST THERE",          "CASI LO TIENES",      "VOUS Y ÊTES PRESQUE")
        case 3:  return t("TRY A DIFFERENT ROUTE",  "PRUEBA OTRA RUTA",    "ESSAYEZ UN AUTRE CHEMIN")
        default: return t("YOU'VE GOT THIS",        "TÚ PUEDES HACERLO",   "VOUS POUVEZ LE FAIRE")
        }
    }

    // MARK: - Failure cause (loss overlay)
    func failureCauseLabel(_ cause: FailureCause) -> String {
        switch cause {
        case .fragileTileDepleted:   return t("FRAGILE TILE BURNED OUT",   "NODO FRÁGIL AGOTADO",         "NŒUD FRAGILE ÉPUISÉ")
        case .chargeGateIncomplete:  return t("CHARGE GATE NOT ACTIVATED", "COMPUERTA DE CARGA INACTIVA", "PORTE DE CHARGE INACTIVE")
        case .coverageInsufficient:  return t("INSUFFICIENT COVERAGE",     "COBERTURA INSUFICIENTE",      "COUVERTURE INSUFFISANTE")
        case .moveLimitExhausted:    return t("SIGNAL LOST IN VOID",       "SEÑAL PERDIDA EN EL VACÍO",   "SIGNAL PERDU DANS LE VIDE")
        }
    }

    func failureCauseHint(_ cause: FailureCause) -> String {
        switch cause {
        case .fragileTileDepleted:   return t("Use this node last",                    "Usa este nodo al final",               "Utilisez ce nœud en dernier")
        case .chargeGateIncomplete:  return t("Activate all gates first",              "Activa todas las compuertas",          "Activez toutes les portes d'abord")
        case .coverageInsufficient:  return t("Activate more tiles before connecting", "Activa más bloques antes de conectar", "Activez plus de tuiles avant de connecter")
        case .moveLimitExhausted:    return t("Plan your route before moving",         "Planifica antes de mover",            "Planifiez avant de bouger")
        }
    }
}
