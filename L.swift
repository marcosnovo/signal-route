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

    // MARK: - Planet ticket
    var planetPass:           String { t("PLANET PASS",                  "PASE PLANETARIO",               "LAISSEZ-PASSER") }
    var trainingClearance:    String { t("TRAINING CLEARANCE",            "AUTORIZACIÓN DE ENTRENAMIENTO", "AUTORISATION D'ENTRAÎNEMENT") }
    var shareProgress:        String { t("SHARE PROGRESS",               "COMPARTIR PROGRESO",            "PARTAGER LA PROGRESSION") }
    /// Share sheet body text — personalised with the player's current level.
    func shareProgressText(level: Int) -> String {
        t(
            "I reached level \(level) in SIGNAL ROUTE 🚀\nCan you go further?",
            "He alcanzado el nivel \(level) en SIGNAL ROUTE 🚀\n¿Puedes llegar más lejos?",
            "J'ai atteint le niveau \(level) dans SIGNAL ROUTE 🚀\nPeux-tu aller plus loin ?"
        )
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
                : t("CONNECT SOURCE TO TARGET",    "CONECTAR FUENTE AL OBJETIVO",  "CONNECTER SOURCE À CIBLE")
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
    var signalRouted:              String { t("SIGNAL ROUTED",               "SEÑAL DIRIGIDA",                 "SIGNAL ACHEMINÉ") }
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
        case .postOnboarding:       return t("TRAINING COMPLETE",   "ENTRENAMIENTO LISTO",     "ENTRAÎNEMENT TERMINÉ")
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

    // MARK: - Local notifications
    var notifCooldownTitle: String { t("The network is live again",
                                       "La red vuelve a estar disponible",
                                       "Le réseau est de nouveau disponible") }
    var notifCooldownBody:  String { t("You can play again in Signal Route.",
                                       "Ya puedes volver a jugar en Signal Route.",
                                       "Vous pouvez rejouer dans Signal Route.") }

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
        case .fragileTileDepleted:  return t("FRAGILE TILE BURNED OUT",   "NODO FRÁGIL AGOTADO",         "NŒUD FRAGILE ÉPUISÉ")
        case .chargeGateIncomplete: return t("CHARGE GATE NOT ACTIVATED", "COMPUERTA DE CARGA INACTIVA", "PORTE DE CHARGE INACTIVE")
        case .moveLimitExhausted:   return t("SIGNAL ROUTE NOT FOUND",    "RUTA DE SEÑAL NO ENCONTRADA", "ROUTE DU SIGNAL INTROUVABLE")
        }
    }

    func failureCauseHint(_ cause: FailureCause) -> String {
        switch cause {
        case .fragileTileDepleted:  return t("Use this node last",           "Usa este nodo al final",      "Utilisez ce nœud en dernier")
        case .chargeGateIncomplete: return t("Activate all gates first",     "Activa todas las compuertas", "Activez toutes les portes d'abord")
        case .moveLimitExhausted:   return t("Plan your route before moving", "Planifica antes de mover",   "Planifiez avant de bouger")
        }
    }
}
