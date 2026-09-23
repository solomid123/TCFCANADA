import Foundation

// MARK: - CEFR & NCLC Level
enum CEFRLevel: String, CaseIterable, Identifiable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"

    var id: String { rawValue }

    var nclcEquivalent: Int {
        switch self {
        case .a1: return 3
        case .a2: return 4
        case .b1: return 5
        case .b2: return 7
        case .c1: return 9
        case .c2: return 10
        }
    }
}

// MARK: - Reading Question Model
struct TCFReadingQuestion: Identifiable {
    let id: Int
    let level: CEFRLevel
    let contextTitle: String
    let passage: String
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanationFR: String
    let explanationEN: String
    let keyVocabulary: [String: String] // French : English
}

// MARK: - Training Practice Item Model
struct TCFPracticeItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let levelBadge: String
    let questionCountText: String
    let durationText: String
    let iconName: String

    var displayTitle: String {
        let parts = title.components(separatedBy: " : ")
        if parts.count == 2, parts[0] == levelBadge { return parts[1] }
        if id == "ideas_bank" { return "Idées & arguments" }
        return title
    }

    var isResource: Bool {
        ["ideas_bank", "write_connectors", "speak_sim"].contains(id)
    }

    var isCompleteSeries: Bool { id == "read_all" || id == "listen_all" }

    var itemCountText: String {
        if id == "listen_ai" { return questionCountText }
        if id.hasPrefix("read_") {
            let count = TCFMockData.readingQuestions(forPracticeId: id).count
            return "\(count) question\(count == 1 ? "" : "s")"
        }
        if id.hasPrefix("listen_") {
            let count = TCFMockData.listeningQuestions(forPracticeId: id).count
            return "\(count) question\(count == 1 ? "" : "s")"
        }
        return questionCountText
    }
}

// MARK: - Visual Option Model (Compréhension Orale Questions 1-4)
struct TCFVisualOption: Identifiable {
    let id: Int
    let letter: String
    let systemIcon: String
    let title: String
    let subtitle: String
}

// MARK: - Listening Question Model
struct TCFListeningQuestion: Identifiable {
    let id: Int
    let level: CEFRLevel
    let situation: String
    let spokenScript: String
    let question: String
    let options: [String]
    let visualOptions: [TCFVisualOption]?
    let imageFileName: String? // Authentic extracted image from video (e.g. "q1_img")
    let audioFileName: String? // Authentic extracted audio from video (e.g. "q1")
    let correctIndex: Int
    let explanationFR: String
    let explanationEN: String
    let languageCode: String // "fr-CA" or "fr-FR"
}

// MARK: - Writing Task Model
struct TCFWritingTask: Identifiable {
    let id: Int
    let taskNumber: Int // 1, 2, or 3
    let title: String
    let minWords: Int
    let maxWords: Int
    let durationMinutes: Int
    let prompt: String
    let guidelines: [String]
    let sampleAnswerNCLC7: String
    let sampleAnswerNCLC9: String
    let essentialConnectors: [String]
}

// MARK: - Speaking Task Model
struct TCFSpeakingTask: Identifiable {
    let id: Int
    let taskNumber: Int // 1, 2, or 3
    let title: String
    let preparationSeconds: Int
    let speakingSeconds: Int
    let scenario: String
    let promptQuestions: [String]
    let strategyTips: [String]
    let suggestedPhrases: [String]
}

// MARK: - Connecteur Logique Model
struct ConnecteurLogique: Identifiable {
    let id = UUID()
    let category: String
    let french: String
    let english: String
    let exampleSentence: String
}

// MARK: - TCF Canada Ideas & Arguments Model (From 2026 Preparation Guide)
struct TCFIdeaTopic: Identifiable {
    let id: String
    let title: String
    let category: String
    let iconName: String
    let taskScope: String // e.g. "Tâches 2 & 3"
    let examContext: String
    let avantages: [String]
    let inconvenients: [String]
    let connecteursRecommandes: [String]
    let sujetTypeExam: String
}

// MARK: - NCLC & CRS Calculator Engine
struct NCLCScoreEngine {
    static func readingToNCLC(_ score: Int) -> Int {
        switch score {
        case ..<342: return 3
        case 342...374: return 4
        case 375...405: return 5
        case 406...452: return 6
        case 453...498: return 7 // Crucial Express Entry threshold
        case 499...523: return 8
        case 524...548: return 9
        default: return 10
        }
    }

    static func listeningToNCLC(_ score: Int) -> Int {
        switch score {
        case ..<331: return 3
        case 331...368: return 4
        case 369...397: return 5
        case 398...457: return 6
        case 458...502: return 7 // Crucial Express Entry threshold
        case 503...522: return 8
        case 523...548: return 9
        default: return 10
        }
    }

    static func writingToNCLC(_ score: Int) -> Int {
        switch score {
        case ..<4: return 3
        case 4...5: return 4
        case 6: return 5
        case 7...9: return 6
        case 10...11: return 7 // Crucial Express Entry threshold
        case 12...13: return 8
        case 14...15: return 9
        default: return 10
        }
    }

    static func speakingToNCLC(_ score: Int) -> Int {
        switch score {
        case ..<4: return 3
        case 4...5: return 4
        case 6: return 5
        case 7...9: return 6
        case 10...11: return 7 // Crucial Express Entry threshold
        case 12...13: return 8
        case 14...15: return 9
        default: return 10
        }
    }

    /// Calculate bonus CRS points for French language skills in Express Entry
    static func calculateFrenchBonusCRS(reading: Int, listening: Int, writing: Int, speaking: Int, hasEnglishCLB5Plus: Bool) -> Int {
        let rNCLC = readingToNCLC(reading)
        let lNCLC = listeningToNCLC(listening)
        let wNCLC = writingToNCLC(writing)
        let sNCLC = speakingToNCLC(speaking)

        let allNCLC7Plus = (rNCLC >= 7 && lNCLC >= 7 && wNCLC >= 7 && sNCLC >= 7)

        if allNCLC7Plus {
            return hasEnglishCLB5Plus ? 50 : 25
        }
        return 0
    }
}

// MARK: - Mock Dataset Provider
struct TCFMockData {
    // MARK: - Reading Questions
    static let readingQuestions: [TCFReadingQuestion] = [
        TCFReadingQuestion(
            id: 1,
            level: .a2,
            contextTitle: "Courriel professionnel - Société des transports de Montréal",
            passage: "Bonjour,\nEn raison de travaux majeurs sur la ligne orange du métro, la station Jean-Talon sera fermée ce samedi de 6h à 18h. Des autobus de remplacement circuleront toutes les 5 minutes pour assurer la liaison entre les stations Henri-Bourassa et Berri-UQAM. Nous vous remercions pour votre compréhension.",
            question: "Quel est l'objectif principal de ce message ?",
            options: [
                "Annoncer l'ouverture d'une nouvelle station de métro",
                "Informer les usagers d'une interruption temporaire de service",
                "Augmenter les tarifs des billets de transport le week-end",
                "Recruter de nouveaux chauffeurs d'autobus"
            ],
            correctIndex: 1,
            explanationFR: "Le texte informe que la station Jean-Talon sera fermée ce samedi et que des autobus de remplacement circuleront. L'objectif est donc d'informer d'une interruption temporaire.",
            explanationEN: "The passage states that Jean-Talon station will be closed this Saturday and replacement buses will run. The primary purpose is to inform users of a temporary service disruption.",
            keyVocabulary: ["travaux": "roadwork / construction", "fermé": "closed", "remplacement": "replacement", "usagers": "riders / users"]
        ),
        TCFReadingQuestion(
            id: 2,
            level: .b1,
            contextTitle: "Offre d'emploi - Agence d'innovation à Québec",
            passage: "Société en pleine expansion dans le secteur des technologies propres recherche un coordonnateur de projets bilingue. Titulaire d'un baccalauréat en administration ou équivalent, vous justifiez d'au moins deux ans d'expérience dans la gestion d'initiatives environnementales. Excellente maîtrise du français et de l'anglais requise.",
            question: "Que doit obligatoirement posséder le candidat sélectionné ?",
            options: [
                "Un diplôme d'ingénieur en énergies fossiles",
                "Une compétence avérée dans les deux langues officielles",
                "Plus de dix années d'expérience en gestion de personnel",
                "Une disponibilité exclusive pour des voyages à l'international"
            ],
            correctIndex: 1,
            explanationFR: "L'offre exige un candidat 'bilingue' avec une 'Excellente maîtrise du français et de l'anglais requise'.",
            explanationEN: "The job posting requires a bilingual candidate with 'excellent mastery of French and English'.",
            keyVocabulary: ["expansion": "growth", "coordonnateur": "coordinator", "bilingue": "bilingual", "maîtrise": "mastery"]
        ),
        TCFReadingQuestion(
            id: 3,
            level: .b2,
            contextTitle: "Article de presse - Le télétravail au Canada",
            passage: "Si le télétravail a initialement été perçu comme une panacée alliant flexibilité et réduction du temps de trajet, de nombreuses entreprises canadiennes réévaluent aujourd'hui leur politique. Les gestionnaires pointent du doigt une dilution progressive du sentiment d'appartenance et des difficultés accrues dans l'intégration des nouvelles recrues. Ainsi, le modèle hybride s'impose désormais comme le compromis idoine.",
            question: "D'après l'auteur, pourquoi les entreprises privilégient-elles désormais le modèle hybride ?",
            options: [
                "Parce que le travail à distance a entraîné une baisse des salaires",
                "Pour contrer l'affaiblissement de la cohésion d'équipe et faciliter l'intégration",
                "Afin d'obliger tous les employés à déménager dans les grandes métropoles",
                "En raison de l'interdiction légale du télétravail à temps plein"
            ],
            correctIndex: 1,
            explanationFR: "Le texte mentionne 'une dilution progressive du sentiment d'appartenance et des difficultés accrues dans l'intégration des nouvelles recrues', ce qui explique l'adoption du modèle hybride comme compromis.",
            explanationEN: "The author notes that managers observe a dilution of belonging and difficulties onboarding recruits, leading to the hybrid model as the ideal compromise.",
            keyVocabulary: ["panacée": "panacea / cure-all", "dilution": "weakening", "sentiment d'appartenance": "sense of belonging", "idoine": "suitable / ideal"]
        ),
        TCFReadingQuestion(
            id: 4,
            level: .c1,
            contextTitle: "Chronique sociologique - La préservation des langues régionales",
            passage: "Loin de n'être qu'un simple réceptacle de conventions syntaxiques, une langue incarne une cosmogonie singulière. Dès lors que s'éteint un idiome vernaculaire, c'est un pan entier de la mémoire collective qui sombre dans l'oubli. Les politiques de revitalisation linguistique ne relèvent donc point d'un passéisme nostalgique, mais d'un impératif anthropologique garantissant la biodiversité cognitive de l'humanité.",
            question: "Quelle thèse l'auteur défend-il principalement dans ce paragraphe ?",
            options: [
                "L'apprentissage des langues modernes doit supplanter les dialectes anciens",
                "La sauvegarde des langues minoritaires est essentielle à la richesse intellectuelle mondiale",
                "Les dialectes régionaux constituent un frein au progrès économique",
                "Les règles syntaxiques doivent être simplifiées pour éviter la disparition des langues"
            ],
            correctIndex: 1,
            explanationFR: "L'auteur soutient que préserver les idiomes est un 'impératif anthropologique garantissant la biodiversité cognitive de l'humanité', et non du passéisme.",
            explanationEN: "The author argues that safeguarding minority idioms is an anthropological imperative that preserves humanity's cognitive biodiversity.",
            keyVocabulary: ["cosmogonie": "worldview / cosmogony", "vernaculaire": "vernacular", "passéisme": "backward-looking nostalgia", "impératif": "imperative"]
        ),
        TCFReadingQuestion(
            id: 5,
            level: .a1,
            contextTitle: "Avis municipal - Bibliothèque de quartier",
            passage: "Chers lecteurs,\nLa bibliothèque municipale modifie ses horaires d'été. Du 1er juillet au 31 août, nous serons ouverts du mardi au samedi de 9h à 13h. Le retour des livres empruntés peut s'effectuer à tout moment grâce à la boîte extérieure située près de l'entrée principale. Bonnes lectures estivales à tous !",
            question: "Que peuvent faire les lecteurs en dehors des heures d'ouverture ?",
            options: [
                "Téléphoner au directeur de la bibliothèque",
                "Déposer leurs livres dans la boîte extérieure",
                "Acheter des livres neufs à tarif réduit",
                "S'inscrire à des cours de français en ligne"
            ],
            correctIndex: 1,
            explanationFR: "Le texte précise que 'Le retour des livres empruntés peut s'effectuer à tout moment grâce à la boîte extérieure'.",
            explanationEN: "The notice states that borrowed books can be returned at any time using the exterior drop box near the main entrance.",
            keyVocabulary: ["horaires": "opening hours", "emprunté": "borrowed", "boîte extérieure": "exterior drop box"]
        ),
        TCFReadingQuestion(
            id: 6,
            level: .b2,
            contextTitle: "Éditorial éducation - L'intelligence artificielle en classe",
            passage: "L'irruption des agents conversationnels intelligents dans les salles de classe canadiennes suscite un vif débat pédagogique. Si certains enseignants y voient une opportunité d'individualiser les apprentissages et de stimuler l'esprit critique par la confrontation aux réponses générées, d'autres redoutent une atrophie progressive des capacités de rédaction autonome chez les élèves.",
            question: "Quel risque majeur certains pédagogues associent-ils à l'IA ?",
            options: [
                "Une hausse incontrôlée du coût du matériel informatique scolaire",
                "Une perte d'autonomie des élèves dans l'exercice d'écriture",
                "L'abandon total des cours de mathématiques et de sciences",
                "Une réduction du nombre d'heures d'enseignement obligatoire"
            ],
            correctIndex: 1,
            explanationFR: "Le texte mentionne expressément que certains enseignants 'redoutent une atrophie progressive des capacités de rédaction autonome'.",
            explanationEN: "The text highlights concerns about a progressive atrophy of students' autonomous writing abilities.",
            keyVocabulary: ["irruption": "arrival / surge", "atrophie": "weakening / atrophy", "autonome": "independent / autonomous"]
        )
    ]

    // MARK: - Subsections Definition
    static let readingSubsections = ["Tous", "A1–A2 Quotidien", "B1 Travail", "B2 Presse", "C1 Analyses"]

    static func readingQuestions(for subsection: String) -> [TCFReadingQuestion] {
        switch subsection {
        case "A1–A2 Quotidien":
            let filtered = readingQuestions.filter { $0.level == .a1 || $0.level == .a2 }
            return filtered.isEmpty ? readingQuestions : filtered
        case "B1 Travail":
            let filtered = readingQuestions.filter { $0.level == .b1 }
            return filtered.isEmpty ? readingQuestions : filtered
        case "B2 Presse":
            let filtered = readingQuestions.filter { $0.level == .b2 }
            return filtered.isEmpty ? readingQuestions : filtered
        case "C1 Analyses":
            let filtered = readingQuestions.filter { $0.level == .c1 || $0.level == .c2 }
            return filtered.isEmpty ? readingQuestions : filtered
        default:
            return readingQuestions
        }
    }

    // MARK: - Practice Item Model & Lists
    static let readingPractices: [TCFPracticeItem] = [
        TCFPracticeItem(
            id: "read_a1_a2",
            title: "A1–A2 : Vie Quotidienne",
            subtitle: "",
            levelBadge: "A1–A2",
            questionCountText: "2 questions",
            durationText: "~5 min",
            iconName: "envelope.fill"
        ),
        TCFPracticeItem(
            id: "read_b1",
            title: "B1 : Milieu Professionnel",
            subtitle: "",
            levelBadge: "B1",
            questionCountText: "1 question",
            durationText: "~5 min",
            iconName: "briefcase.fill"
        ),
        TCFPracticeItem(
            id: "read_b2",
            title: "B2 : Presse & Société",
            subtitle: "",
            levelBadge: "B2",
            questionCountText: "2 questions",
            durationText: "~10 min",
            iconName: "newspaper.fill"
        ),
        TCFPracticeItem(
            id: "read_c1",
            title: "C1 : Analyses & Essais",
            subtitle: "",
            levelBadge: "C1",
            questionCountText: "1 question",
            durationText: "~10 min",
            iconName: "text.book.closed.fill"
        ),
        TCFPracticeItem(
            id: "read_all",
            title: "Série Complète (Mixte)",
            subtitle: "",
            levelBadge: "A1–C1",
            questionCountText: "6 questions",
            durationText: "~20 min",
            iconName: "list.bullet.clipboard.fill"
        )
    ]

    static func readingQuestions(forPracticeId id: String) -> [TCFReadingQuestion] {
        switch id {
        case "read_a1_a2":
            return readingQuestions.filter { $0.level == .a1 || $0.level == .a2 }
        case "read_b1":
            return readingQuestions.filter { $0.level == .b1 }
        case "read_b2":
            return readingQuestions.filter { $0.level == .b2 }
        case "read_c1":
            return readingQuestions.filter { $0.level == .c1 || $0.level == .c2 }
        default:
            return readingQuestions
        }
    }

    static let listeningPractices: [TCFPracticeItem] = [
        TCFPracticeItem(
            id: "listen_yt11",
            title: "Série 11 : Enregistrements Réels",
            subtitle: "",
            levelBadge: "A1–B1",
            questionCountText: "7 questions",
            durationText: "~15 min",
            iconName: "play.circle.fill"
        ),
        TCFPracticeItem(
            id: "listen_a1",
            title: "A1 : Situations & Images",
            subtitle: "",
            levelBadge: "A1",
            questionCountText: "3 questions",
            durationText: "~5 min",
            iconName: "photo.fill"
        ),
        TCFPracticeItem(
            id: "listen_a2",
            title: "A2 : Dialogues Courts",
            subtitle: "",
            levelBadge: "A2",
            questionCountText: "2 questions",
            durationText: "~5 min",
            iconName: "bubble.left.and.bubble.right.fill"
        ),
        TCFPracticeItem(
            id: "listen_b1_b2",
            title: "B1–B2 : Débats & Entrevues",
            subtitle: "",
            levelBadge: "B1–B2",
            questionCountText: "2 questions",
            durationText: "~8 min",
            iconName: "waveform"
        ),
        TCFPracticeItem(
            id: "listen_all",
            title: "Banque Complète d'Écoute",
            subtitle: "",
            levelBadge: "A1–B2",
            questionCountText: "7 questions",
            durationText: "~15 min",
            iconName: "headphones"
        )
    ]

    static func listeningQuestions(forPracticeId id: String) -> [TCFListeningQuestion] {
        switch id {
        case "listen_yt11":
            return listeningQuestions.filter { $0.audioFileName != nil }
        case "listen_a1":
            return listeningQuestions.filter { $0.imageFileName != nil }
        case "listen_a2":
            return listeningQuestions.filter { $0.level == .a2 }
        case "listen_b1_b2":
            return listeningQuestions.filter { $0.level == .b1 || $0.level == .b2 }
        default:
            return listeningQuestions
        }
    }

    static let writingPractices: [TCFPracticeItem] = [
        TCFPracticeItem(
            id: "ideas_bank",
            title: "Banque d'Idées & Arguments (PDF 2026)",
            subtitle: "16 Thèmes officiels TCF Canada Tâches 2 & 3",
            levelBadge: "NCLC 7–10",
            questionCountText: "16 thèmes",
            durationText: "Guide PDF",
            iconName: "lightbulb.fill"
        ),
        TCFPracticeItem(
            id: "write_t1",
            title: "Tâche 1 : Message court / Courriel",
            subtitle: "Invitation amicale ou demande de renseignements",
            levelBadge: "60–120 mots",
            questionCountText: "1 tâche",
            durationText: "~15 min",
            iconName: "pencil.line"
        ),
        TCFPracticeItem(
            id: "write_t2",
            title: "Tâche 2 : Article ou lettre d'opinion",
            subtitle: "Récit d'expérience vécue & argumentation",
            levelBadge: "120–150 mots",
            questionCountText: "1 tâche",
            durationText: "~25 min",
            iconName: "doc.text.fill"
        ),
        TCFPracticeItem(
            id: "write_t3",
            title: "Tâche 3 : Comparaison de deux avis",
            subtitle: "Synthèse et prise de position argumentée",
            levelBadge: "120–180 mots",
            questionCountText: "1 tâche",
            durationText: "~20 min",
            iconName: "arrow.left.arrow.right"
        ),
        TCFPracticeItem(
            id: "write_connectors",
            title: "Boîte à Outils : Connecteurs",
            subtitle: "Banque de connecteurs logiques NCLC 7+",
            levelBadge: "Vocabulaire",
            questionCountText: "Outil",
            durationText: "Référence",
            iconName: "link"
        )
    ]

    static let speakingPractices: [TCFPracticeItem] = [
        TCFPracticeItem(
            id: "ideas_bank",
            title: "Banque d'Idées & Arguments (PDF 2026)",
            subtitle: "16 Thèmes officiels TCF Canada Tâches 2 & 3",
            levelBadge: "NCLC 7–10",
            questionCountText: "16 thèmes",
            durationText: "Guide PDF",
            iconName: "lightbulb.fill"
        ),
        TCFPracticeItem(
            id: "speak_t1",
            title: "Tâche 1 : Entretien dirigé",
            subtitle: "Se présenter, parler de son travail et de sa vie",
            levelBadge: "2 min",
            questionCountText: "1 tâche",
            durationText: "Sans prép.",
            iconName: "person.fill"
        ),
        TCFPracticeItem(
            id: "speak_t2",
            title: "Tâche 2 : Exercice en interaction",
            subtitle: "Poser des questions et obtenir des informations",
            levelBadge: "3.5 min",
            questionCountText: "1 tâche",
            durationText: "1 min prép.",
            iconName: "bubble.left.fill"
        ),
        TCFPracticeItem(
            id: "speak_t3",
            title: "Tâche 3 : Expression d'un avis",
            subtitle: "Défendre une position et justifier son point de vue",
            levelBadge: "4.5 min",
            questionCountText: "1 tâche",
            durationText: "Argumentation",
            iconName: "megaphone.fill"
        ),
        TCFPracticeItem(
            id: "speak_sim",
            title: "Simulateur d'Enregistrement",
            subtitle: "Enregistreur vocal chronométré & auto-évaluation",
            levelBadge: "Audio",
            questionCountText: "Outil",
            durationText: "Pratique",
            iconName: "mic.fill"
        )
    ]

    // MARK: - Listening Questions (Compréhension Orale - Série 11)
    static let listeningQuestions: [TCFListeningQuestion] = [
        // Question 1: Visual Matching (A1)
        // MARK: - Authentic Questions from Série 11 (YouTube)
        // Question 1: Visual Situation - Bureau de Poste (A1)
        TCFListeningQuestion(
            id: 1,
            level: .a1,
            situation: "La Poste • Guichet d'envoi",
            spokenScript: "Regardez l'image 1.\nA : J'aimerais ouvrir ce colis, c'est un cadeau.\nB : Je n'arrive pas à écrire le courrier pour le directeur.\nC : Je voudrais envoyer cette lettre s'il vous plaît.\nD : Le facteur est passé, tu vas chercher le courrier.",
            question: "Écoutez les 4 propositions et choisissez celle qui correspond à l'image.",
            options: [
                "Proposition A",
                "Proposition B",
                "Proposition C",
                "Proposition D"
            ],
            visualOptions: nil,
            imageFileName: "q1_img",
            audioFileName: "q1",
            correctIndex: 2,
            explanationFR: "La cliente se présente au guichet postal et tend une enveloppe à l'employé : « Je voudrais envoyer cette lettre s'il vous plaît » (Proposition C).",
            explanationEN: "The customer is at the postal counter handing an envelope/letter to the clerk: 'I would like to send this letter please' (Option C).",
            languageCode: "fr-FR"
        ),

        // Question 2: Visual Situation - Terrasse & Manteau (A1)
        TCFListeningQuestion(
            id: 2,
            level: .a1,
            situation: "Terrasse de maison • Départ pour l'extérieur",
            spokenScript: "Regardez l'image 2.\nA : Arrête de jouer avec le ballon.\nB : Fais attention avant de traverser.\nC : Mets ton bonnet tout de suite.\nD : Regarde les enfants s'amuser.",
            question: "Écoutez les 4 propositions et choisissez celle qui correspond à l'image.",
            options: [
                "Proposition A",
                "Proposition B",
                "Proposition C",
                "Proposition D"
            ],
            visualOptions: nil,
            imageFileName: "q2_img",
            audioFileName: "q2",
            correctIndex: 2,
            explanationFR: "Le père tend un bonnet d'hiver à sa fille qui s'apprête à sortir dehors dans le froid avec son manteau et son écharpe : « Mets ton bonnet tout de suite » (Proposition C).",
            explanationEN: "The father is holding out a winter hat/beanie to his daughter who is heading outside in the cold: 'Put your beanie on right now' (Option C).",
            languageCode: "fr-FR"
        ),

        // Question 3: Visual Situation - Restaurant & Maître d'hôtel (A2)
        TCFListeningQuestion(
            id: 3,
            level: .a2,
            situation: "Entrée d'un restaurant • Accueil du maître d'hôtel",
            spokenScript: "Regardez l'image 3.\nA : Bravo cuisinier, c'est délicieux.\nB : Je voudrais une table près de la fenêtre.\nC : Un autre café s'il vous plaît.\nD : Vous pouvez garder la monnaie.",
            question: "Écoutez les 4 propositions et choisissez celle qui correspond à l'image.",
            options: [
                "Proposition A",
                "Proposition B",
                "Proposition C",
                "Proposition D"
            ],
            visualOptions: nil,
            imageFileName: "q3_img",
            audioFileName: "q3",
            correctIndex: 1,
            explanationFR: "Le client entre dans le restaurant avec son parapluie et s'adresse au serveur pour demander à s'asseoir : « Je voudrais une table près de la fenêtre » (Proposition B).",
            explanationEN: "The customer enters the restaurant holding an umbrella and asks the waiter for a table: 'I would like a table near the window' (Option B).",
            languageCode: "fr-FR"
        ),

        // Question 4: Dialogue / Question Réponse (A2)
        TCFListeningQuestion(
            id: 4,
            level: .a2,
            situation: "Appel téléphonique amical • Invitation à déjeuner",
            spokenScript: "Question 4. Allô Anne, je suis libre demain. Nous déjeunons ensemble ?\nA : Avec plaisir.\nB : Ça va, merci.\nC : Je t'en prie.\nD : Pas de quoi.",
            question: "Écoutez le document sonore et la question. Choisissez la bonne réponse.",
            options: [
                "Avec plaisir",
                "Ça va, merci",
                "Je t'en prie",
                "Pas de quoi"
            ],
            visualOptions: nil,
            imageFileName: nil,
            audioFileName: "q4",
            correctIndex: 0,
            explanationFR: "À une invitation à déjeuner (« Nous déjeunons ensemble ? »), la formule usuelle d'acceptation est « Avec plaisir » (A).",
            explanationEN: "To an invitation for lunch ('Shall we have lunch together?'), the standard affirmative answer is 'With pleasure' (A).",
            languageCode: "fr-FR"
        ),

        // Question 5: Question Réponse (A2)
        TCFListeningQuestion(
            id: 5,
            level: .a2,
            situation: "Conversation courante • Perception auditive",
            spokenScript: "Question 5. Avez-vous entendu quelque chose ?\nA : Merci, je ne veux rien.\nB : Non, c'est par là.\nC : Oui, je crois.\nD : Peut-être demain.",
            question: "Écoutez le document sonore et la question. Choisissez la bonne réponse.",
            options: [
                "Merci, je ne veux rien",
                "Non, c'est par là",
                "Oui, je crois",
                "Peut-être demain"
            ],
            visualOptions: nil,
            imageFileName: nil,
            audioFileName: "q5",
            correctIndex: 2,
            explanationFR: "À la question fermée « Avez-vous entendu quelque chose ? », la réponse affirmative cohérente est « Oui, je crois » (C).",
            explanationEN: "To 'Did you hear something?', the appropriate answer is 'Yes, I think so' (C).",
            languageCode: "fr-FR"
        ),

        // Question 6: Proposition Déjeuner (B1)
        TCFListeningQuestion(
            id: 6,
            level: .b1,
            situation: "Proposition au travail • Restaurant",
            spokenScript: "Question 6. J'ai trouvé un nouveau restaurant. On réserve une table pour deux à midi, tu es d'accord ?\nA : Désolé, je mange avec mes collègues.\nB : Désolé, je ne peux pas t'aider.\nC : Désolé, je préfère le menu à 18 €.\nD : Désolé, je te réponds dans la soirée.",
            question: "Écoutez le document sonore et la question. Choisissez la bonne réponse.",
            options: [
                "Désolé, je mange avec mes collègues",
                "Désolé, je ne peux pas t'aider",
                "Désolé, je préfère le menu à 18 €",
                "Désolé, je te réponds dans la soirée"
            ],
            visualOptions: nil,
            imageFileName: nil,
            audioFileName: "q6",
            correctIndex: 0,
            explanationFR: "Pour refuser poliment une proposition de repas à midi, la justification cohérente est « Désolé, je mange avec mes collègues » (A).",
            explanationEN: "To politely decline a lunch invitation, the logical reason is 'Sorry, I am having lunch with my colleagues' (A).",
            languageCode: "fr-FR"
        ),

        // Question 7: Demande de service (B1)
        TCFListeningQuestion(
            id: 7,
            level: .b1,
            situation: "Service entre amis • Trajet à l'aéroport",
            spokenScript: "Question 7. Salut Charlie, je prends l'avion jeudi à 4h du matin. À cette heure-là, il n'y a pas de transport en commun. Tu pourrais m'emmener à l'aéroport en voiture ?\nA : Avec plaisir, j'adore les voyages.\nB : Bien sûr, je passe te prendre chez toi.\nC : D'accord, je te prêterai ma valise.\nD : Parfait, je viendrai te chercher à la gare.",
            question: "Écoutez le document sonore et la question. Choisissez la bonne réponse.",
            options: [
                "Avec plaisir, j'adore les voyages",
                "Bien sûr, je passe te prendre chez toi",
                "D'accord, je te prêterai ma valise",
                "Parfait, je viendrai te chercher à la gare"
            ],
            visualOptions: nil,
            imageFileName: nil,
            audioFileName: "q7",
            correctIndex: 1,
            explanationFR: "À la demande de Charlie pour se faire conduire à l'aéroport, la réponse acceptant de rendre service est « Bien sûr, je passe te prendre chez toi » (B).",
            explanationEN: "To Charlie's request for a ride to the airport, the positive response is 'Of course, I will pick you up at your place' (B).",
            languageCode: "fr-FR"
        ),

        // Question 8: Sociological interview (B2)
        TCFListeningQuestion(
            id: 8,
            level: .b2,
            situation: "Entrevue sociologique - Les jardins urbains",
            spokenScript: "Au-delà de leur apport indéniable en produits maraîchers frais, les jardins partagés en milieu urbain remplissent une fonction de cohésion sociale déterminante. Dans nos quartiers montréalais, ils favorisent une interculturalité spontanée : des aînés transmettent des savoir-faire horticoles traditionnels à de jeunes ménages issus de l'immigration récente, déconstruisant ainsi les barrières générationnelles et linguistiques.",
            question: "Selon la sociologue, quel est le bénéfice fondamental des jardins partagés ?",
            options: [
                "Augmenter la valeur marchande des résidences voisines",
                "Renforcer les liens sociaux et les échanges intergénérationnels",
                "Remplacer entièrement les circuits de distribution agroalimentaire",
                "Diminuer les dépenses d'entretien des parcs municipaux"
            ],
            visualOptions: nil,
            imageFileName: nil,
            audioFileName: nil,
            correctIndex: 1,
            explanationFR: "La sociologue souligne que ces jardins ont une « fonction de cohésion sociale déterminante » en favorisant la transmission entre aînés et nouveaux arrivants.",
            explanationEN: "The sociologist highlights that community gardens foster social cohesion and cross-generational transmission between seniors and newcomers.",
            languageCode: "fr-CA"
        ),

        // Question 9: Radio debate on hybrid work (B2)
        TCFListeningQuestion(
            id: 9,
            level: .b2,
            situation: "Débat économique - Le modèle de travail hybride",
            spokenScript: "Si le télétravail hybride séduit une majorité d'employés canadiens par sa flexibilité, il soulève de sérieux défis managériaux. Les gestionnaires constatent une dispersion insidieuse de la culture d'entreprise et un sentiment d'isolement chez les juniors. Le véritable écueil réside dans l'incapacité à recréer ces micro-interactions informelles à la machine à café, pourtant indispensables à la créativité collaborative.",
            question: "Quelle est la principale inquiétude exprimée par les gestionnaires ?",
            options: [
                "La baisse drastique du temps de travail effectif",
                "L'impossibilité d'évaluer le rendement des équipes",
                "L'effritement des échanges informels essentiels à la créativité",
                "Le coût excessif des abonnements aux logiciels collaboratifs"
            ],
            visualOptions: nil,
            imageFileName: nil,
            audioFileName: nil,
            correctIndex: 2,
            explanationFR: "Le texte identifie comme écueil majeur « l'incapacité à recréer ces micro-interactions informelles [...] indispensables à la créativité collaborative ».",
            explanationEN: "Managers are primarily concerned by the loss of spontaneous informal interactions that drive collaborative creativity.",
            languageCode: "fr-FR"
        ),

        // Question 10: Scientific analysis (C1)
        TCFListeningQuestion(
            id: 10,
            level: .c1,
            situation: "Chronique scientifique - La forêt boréale canadienne",
            spokenScript: "La forêt boréale canadienne, véritable poumon de l'hémisphère nord, subit une pression sans précédent consécutive aux perturbations climatiques. Le dégel hâtif du pergélisol et la prolifération exponentielle du dendroctone du pin transforment ce puits de carbone historique en émetteur net lors des saisons de feux de forêt. Les dendrologues plaident pour une sylviculture adaptative favorisant la biodiversité d'essences feuillues, plus résilientes face aux incendies récurrents.",
            question: "Quelle solution préconisent les spécialistes pour préserver la résilience de la forêt boréale ?",
            options: [
                "L'interdiction absolue de toute exploitation forestière au pays",
                "Une gestion forestière diversifiant les essences pour mieux résister aux feux",
                "L'arrosage artificiel massif des massifs forestiers durant l'été",
                "La conversion de parcelles boréales en terres arables extensives"
            ],
            visualOptions: nil,
            imageFileName: nil,
            audioFileName: nil,
            correctIndex: 1,
            explanationFR: "Les spécialistes préconisent « une sylviculture adaptative favorisant la biodiversité d'essences feuillues, plus résilientes face aux incendies récurrents ».",
            explanationEN: "Experts recommend adaptive forestry that promotes biodiversity of deciduous species more resilient to recurrent wildfires.",
            languageCode: "fr-CA"
        )
    ]

    // MARK: - Writing Tasks
    static let writingTasks: [TCFWritingTask] = [
        TCFWritingTask(
            id: 1,
            taskNumber: 1,
            title: "Tâche 1 : Message court (Invitation / Information)",
            minWords: 60,
            maxWords: 120,
            durationMinutes: 15,
            prompt: "Vous venez d'emménager dans votre nouvel appartement à Calgary. Vous écrivez un courriel à vos amis canadiens pour les inviter à votre pendaison de crémaillère (housewarming party). Vous décrivez brièvement le logement et indiquez la date, l'heure et l'itinéraire.",
            guidelines: [
                "Saluez chaleureusement vos amis",
                "Donnez l'adresse et les détails d'accès (métro / stationnement)",
                "Décrivez un point fort de l'appartement (terrasse, luminosité)",
                "Demandez de confirmer leur présence avant une date précise"
            ],
            sampleAnswerNCLC7: "Chers amis,\n\nJ'ai le plaisir de vous annoncer que je viens enfin de m'installer dans mon nouvel appartement à Calgary ! Le logement est très lumineux et dispose d'une superbe terrasse avec vue sur les montagnes.\n\nPour célébrer cet événement, je vous invite à ma pendaison de crémaillère qui aura lieu le samedi 15 octobre à partir de 18 heures.\n\nMon adresse est le 450 7th Avenue SW. Vous pouvez facilement vous y rendre en prenant le C-Train jusqu'à la station 7th Street.\n\nMerci de me confirmer votre présence avant mercredi prochain afin que je puisse préparer le buffet.\n\nÀ très bientôt,\nAlexandre",
            sampleAnswerNCLC9: "Chers tous,\n\nC'est avec un immense enthousiasme que je vous écris depuis mon nouveau chez-moi au cœur de Calgary ! Après quelques semaines de cartons et de rénovations, l'appartement est enfin fin prêt. Niché au dernier étage, il bénéficie d'une clarté remarquable et d'une vue panoramique imprenable sur le centre-ville.\n\nAfin de fêter dignement cette étape, je vous convie à une pendaison de crémaillère le samedi 15 octobre dès 18h30. L'immeuble se situe au 450 7th Avenue SW, à deux pas de la station de C-Train.\n\nFaites-moi savoir d'ici mercredi si vous serez des nôtres, afin d'ajuster les victuailles.\n\nAu plaisir de vous accueillir,\nAlexandre",
            essentialConnectors: ["Afin de", "C'est avec plaisir que", "À cet effet", "D'ici là", "En outre"]
        ),
        TCFWritingTask(
            id: 2,
            taskNumber: 2,
            title: "Tâche 2 : Récit d'une expérience marquante",
            minWords: 120,
            maxWords: 150,
            durationMinutes: 20,
            prompt: "Pour le journal de votre communauté francophone, vous rédigez un article racontant une activité bénévole ou citoyenne à laquelle vous avez participé récemment. Vous décrivez ce que vous avez fait, vos impressions et pourquoi cette expérience vous a enrichi.",
            guidelines: [
                "Introduire le cadre de l'activité bénévole",
                "Raconter les actions concrètes menées avec les autres bénévoles",
                "Exprimer vos sentiments et les bénéfices pour la communauté",
                "Utiliser les temps du passé (passé composé, imparfait) avec précision"
            ],
            sampleAnswerNCLC7: "Le mois dernier, j'ai eu l'opportunité de participer en tant que bénévole à la banque alimentaire de mon quartier. Dès notre arrivée à 8 heures, notre équipe a trié et emballé plusieurs centaines de kilogrammes de denrées destinées à des familles vulnérables.\n\nCette journée fut particulièrement marquante. D'une part, j'ai été touché par la solidarité exceptionnelle entre bénévoles de toutes origines. D'autre part, discuter avec les bénéficiaires m'a fait prendre conscience des réalités économiques locales.\n\nEn conclusion, cet engagement civique m'a permis de me sentir véritablement utile. Je recommande vivement à chacun de consacrer un peu de temps à ces initiatives chaleureuses qui renforcent le tissu social canadien.",
            sampleAnswerNCLC9: "L'automne dernier, j'ai rejoint le collectif bénévole d'une banque alimentaire montréalaise, une expérience qui a profondément bouleversé ma perception de la solidarité urbaine. Dès l'aube, notre équipe s'est attelée à la logistique : réception des invendus, tri rigoureux et confection de paniers nutritifs.\n\nAu-delà de l'effort physique soutenu, ce furent les échanges humains qui m'ont le plus marqué. Côtoyer des concitoyens d'horizons variés, unis par une même volonté de bienveillance, suscite une profonde humilité. Cette immersion m'a permis d'appréhender concrètement la résilience des communautés marginalisées.\n\nEn somme, ce bénévolat m'a apporté un sentiment d'ancrage inestimable. S'investir auprès des plus démunis demeure sans conteste le plus sûr moyen d'édifier une société plus équitable.",
            essentialConnectors: ["Dès lors", "D'une part... d'autre part", "Au-delà de", "En somme", "Sans conteste"]
        ),
        TCFWritingTask(
            id: 3,
            taskNumber: 3,
            title: "Tâche 3 : Prise de position argumentée (Deux avis)",
            minWords: 120,
            maxWords: 180,
            durationMinutes: 25,
            prompt: "Vous lisez sur un forum deux avis contradictoires concernant l'interdiction des téléphones intelligents dans les écoles secondaires. Vous devez : 1. Résumer brièvement les deux points de vue. 2. Donner votre avis personnel et argumenté sur la question.",
            guidelines: [
                "Document 1 : Favorise la concentration et diminue la cyberintimidation.",
                "Document 2 : Prive les élèves d'un outil pédagogique essentiel pour le monde moderne.",
                "Adopter une structure équilibrée (synthèse puis opinion étayée d'exemples)",
                "Respecter rigoureusement la tranche de mots (120 - 180)"
            ],
            sampleAnswerNCLC7: "Le débat autour de l'usage des téléphones intelligents à l'école suscite des positions divergentes. D'un côté, certains soutiennent que leur interdiction permet de restaurer la concentration des élèves et d'endiguer le fléau du cyberharcèlement en milieu scolaire. De l'autre côté, leurs détracteurs arguent que le téléphone constitue un instrument d'apprentissage incontournable dans une société numérisée.\n\nPour ma part, j'estime que l'interdiction totale est la mesure la plus judicieuse durant les heures de cours. En effet, de nombreuses études démontrent que les notifications incessantes nuisent dramatiquement aux facultés d'attention des adolescents. Par ailleurs, rien n'empêche les établissements de fournir des tablettes dédiées sous encadrement professoral pour les activités pédagogiques.\n\nEn conclusion, bannir le téléphone personnel favorise un climat propice aux études tout en préservant les relations humaines réelles.",
            sampleAnswerNCLC9: "L'opportunité de prohiber les téléphones cellulaires en milieu scolaire cristallise les tensions. Si les partisans d'une interdiction stricte invoquent la préservation de l'attention cognitive et la lutte contre le harcèlement virtuel, d'autres estiment anachronique d'évincer un vecteur technologique omniprésent dans la sphère professionnelle.\n\nÀ mon sens, une restriction ferme en classe s'avère indispensable. Certes, le numérique offre des potentialités didactiques indéniables ; néanmoins, laisser libre cours aux distractions algorithmiques compromet l'assimilation des savoirs fondamentaux. L'école doit demeurer un sanctuaire préservé de l'immédiateté numérique.\n\nAinsi, réguler rigoureusement cet outil garantit tant l'équité des apprentissages que la vitalité des interactions spontanées entre jeunes.",
            essentialConnectors: ["D'un côté... de l'autre côté", "Pour ma part", "En effet", "Néanmoins", "À mon sens", "Ainsi"]
        )
    ]

    // MARK: - Speaking Tasks
    static let speakingTasks: [TCFSpeakingTask] = [
        TCFSpeakingTask(
            id: 1,
            taskNumber: 1,
            title: "Tâche 1 : Entretien sans préparation (Présentation)",
            preparationSeconds: 0,
            speakingSeconds: 120, // 2 minutes
            scenario: "L'examinateur vous demande de vous présenter : votre parcours professionnel, votre ville d'origine, vos centres d'intérêt et les motivations qui vous poussent à immigrer au Canada.",
            promptQuestions: [
                "Pouvez-vous vous présenter brièvement ?",
                "Quel est votre métier et qu'appréciez-vous le plus dans votre travail ?",
                "Pourquoi avez-vous choisi le Canada comme destination d'immigration ?"
            ],
            strategyTips: [
                "Parlez de façon naturelle et fluide sans réciter un texte appris par cœur",
                "Utilisez une palette variée de temps : passé pour vos études/expériences, présent pour vos activités actuelles, futur/conditionnel pour vos projets canadiens",
                "Mentionnez une province canadienne précise (ex: l'Ontario, le Québec, l'Alberta) et pourquoi elle vous correspond"
            ],
            suggestedPhrases: [
                "Je suis originaire de... où j'ai exercé en tant que...",
                "Ce qui me passionne avant tout dans mon domaine, c'est...",
                "J'aspire à m'établir au Canada en raison de ses valeurs d'ouverture et de ses perspectives professionnelles dynamiques."
            ]
        ),
        TCFSpeakingTask(
            id: 2,
            taskNumber: 2,
            title: "Tâche 2 : Exercice en interaction (Poser des questions)",
            preparationSeconds: 60, // 1 minute prep
            speakingSeconds: 210, // 3.5 minutes
            scenario: "Vous voyez une annonce pour des cours de perfectionnement linguistique à l'Université de Montréal. Vous téléphonez au responsable (joué par l'examinateur) pour obtenir des renseignements détaillés.",
            promptQuestions: [
                "Demandez les horaires et les dates de début des sessions",
                "Renseignez-vous sur le niveau exigé pour s'inscrire",
                "Interrogez sur les tarifs et les possibilités de bourses ou financements",
                "Demandez si les cours ont lieu en présentiel ou en ligne"
            ],
            strategyTips: [
                "C'est VOUS qui devez mener l'échange en posant des questions variées (inversion, 'Est-ce que', pronoms interrogatifs)",
                "Ne vous contentez pas de questions fermées (oui/non) ; rebondissez sur les réponses de l'examinateur",
                "Utilisez un registre formel poli (conditionnel : 'Je souhaiterais savoir...', 'Pourriez-vous m'indiquer...')"
            ],
            suggestedPhrases: [
                "Bonjour monsieur, je me permets de vous contacter au sujet de...",
                "Pourriez-vous m'éclairer sur les conditions d'admissibilité ?",
                "Qu'en est-il des modalités de règlement ? Existe-t-il un échelonnement ?",
                "Je vous remercie pour tous ces précieux renseignements."
            ]
        ),
        TCFSpeakingTask(
            id: 3,
            taskNumber: 3,
            title: "Tâche 3 : Expression d'un point de vue argumenté",
            preparationSeconds: 0,
            speakingSeconds: 270, // 4.5 minutes
            scenario: "Sujet : 'Selon certains, les cours universitaires entièrement en ligne remplaceront bientôt les cours traditionnels en amphithéâtre.' Partagez-vous cet avis ? Développez votre argumentation avec des exemples concrets.",
            promptQuestions: [
                "Quels sont les atouts de l'enseignement virtuel (accessibilité, coût, flexibilité) ?",
                "Quelles sont ses limites majeures (isolement, baisse de motivation, manque de pratique) ?",
                "Quelle est votre conclusion sur l'avenir de l'université ?"
            ],
            strategyTips: [
                "Structurez impérativement votre discours : Introduction -> Thèse 1 -> Thèse 2 -> Avis personnel nuancé -> Conclusion",
                "Émaillez votre discours de connecteurs logiques audibles (*D'abord, En outre, Toutefois, Par conséquent*)",
                "Donnez un ou deux exemples vécus ou observés pour donner du poids à vos arguments"
            ],
            suggestedPhrases: [
                "Cette question soulève un débat particulièrement stimulant à l'ère numérique.",
                "D'un côté, il est indéniable que la formation à distance offre une démocratisation sans précédent...",
                "Cependant, l'expérience universitaire ne se résume pas à l'assimilation passive de données...",
                "En somme, je suis convaincu que la formule hybride représente l'équilibre le plus pertinent."
            ]
        )
    ]

    // MARK: - Connecteurs Logiques
    static let connectors: [ConnecteurLogique] = [
        ConnecteurLogique(category: "Introduction & Ordre", french: "En premier lieu / Tout d'abord", english: "First of all / Primarily", exampleSentence: "En premier lieu, il convient d'analyser les retombées économiques du projet."),
        ConnecteurLogique(category: "Introduction & Ordre", french: "D'une part... d'autre part", english: "On the one hand... on the other hand", exampleSentence: "D'une part, le coût est minime ; d'autre part, les bénéfices sont immenses."),
        ConnecteurLogique(category: "Cause & Explication", french: "En effet / Étant donné que", english: "Indeed / Given that", exampleSentence: "Le projet a réussi. En effet, l'équipe a fait preuve d'un grand dévouement."),
        ConnecteurLogique(category: "Cause & Explication", french: "Grâce à / En raison de", english: "Thanks to / Due to", exampleSentence: "Grâce à cette initiative, le taux de chômage a diminué de moitié."),
        ConnecteurLogique(category: "Opposition & Nuance", french: "Cependant / Néanmoins", english: "However / Nevertheless", exampleSentence: "L'idée est séduisante ; néanmoins, sa mise en œuvre demeure complexe."),
        ConnecteurLogique(category: "Opposition & Nuance", french: "Bien que (+ subjonctif)", english: "Although / Even though", exampleSentence: "Bien que la tâche soit ardue, nous sommes déterminés à réussir."),
        ConnecteurLogique(category: "Conséquence", french: "Par conséquent / C'est pourquoi", english: "Therefore / That is why", exampleSentence: "Les transports étaient bloqués, c'est pourquoi nous sommes arrivés en retard."),
        ConnecteurLogique(category: "Conséquence", french: "Ainsi / Il en résulte que", english: "Thus / As a result", exampleSentence: "Ainsi, l'ensemble des objectifs trimestriels ont été atteints."),
        ConnecteurLogique(category: "Conclusion", french: "En somme / En conclusion", english: "In short / In conclusion", exampleSentence: "En somme, l'intégration culturelle repose avant tout sur le dialogue mutuel.")
    ]

    // MARK: - Banque d'Idées & Arguments Officiels (Issus du Guide TCF Canada 2026)
    static let ideasBank: [TCFIdeaTopic] = [
        TCFIdeaTopic(
            id: "teletravail",
            title: "Le Télétravail & Travail Hybride",
            category: "Travail",
            iconName: "laptopcomputer",
            taskScope: "Tâches 2 & 3",
            examContext: "Débat récurrent sur la généralisation du travail à domicile et ses impacts sociaux.",
            avantages: [
                "Flexibilité horaire : possibilité d'organiser son emploi du temps selon ses contraintes familiales et personnelles.",
                "Gain de temps et d'énergie : suppression des trajets quotidiens aux heures de pointe et des embouteillages urbains.",
                "Autonomie accrue : diminution des interruptions fréquentes au bureau, favorisant une concentration approfondie.",
                "Bénéfice écologique : réduction sensible des émissions de gaz à effet de serre liées aux transports individuels."
            ],
            inconvenients: [
                "Affaiblissement du lien social : raréfaction des échanges informels et risque d'isolement professionnel.",
                "Frontière floue vie pro / vie perso : difficulté à déconnecter le soir, générant un risque de surmenage.",
                "Inégalités matérielles : dépendance à une connexion internet performante et à un espace de travail adapté à domicile."
            ],
            connecteursRecommandes: ["Force est de constater que", "D'un côté... de l'autre", "Toutefois, il convient de souligner", "En définitive"],
            sujetTypeExam: "« Le télétravail intégral annonce-t-il la disparition définitive des bureaux d'entreprise ? » Exprimez votre point de vue argumenté."
        ),
        TCFIdeaTopic(
            id: "bio",
            title: "L'Alimentation Biologique",
            category: "Environnement",
            iconName: "leaf.fill",
            taskScope: "Tâches 2 & 3",
            examContext: "Consommation responsable, santé publique et modèle agricole contemporain.",
            avantages: [
                "Protection de la santé : absence de pesticides de synthèse et de résidus chimiques toxiques pour l'organisme.",
                "Préservation de la biodiversité : respect de la microbiologie des sols, des cours d'eau et de la faune pollinisatrice.",
                "Qualité nutritionnelle et goût : aliments plus riches en antioxydants et saveurs authentiques du terroir."
            ],
            inconvenients: [
                "Coût financier élevé : prix en rayon souvent 20 à 40% plus cher, limitant l'accès aux foyers modestes.",
                "Rendements agricoles inférieurs : risque de ne pas subvenir aux besoins alimentaires d'une population mondiale croissante.",
                "Conservation plus courte : absence de conservateurs artificiels provoquant une détérioration rapide des produits."
            ],
            connecteursRecommandes: ["Il est indéniable que", "Néanmoins, l'obstacle financier", "À cet égard", "Pour conclure"],
            sujetTypeExam: "« L'agriculture biologique doit-elle devenir la seule norme alimentaire de demain ? » Donnez votre avis."
        ),
        TCFIdeaTopic(
            id: "energies_renouvelables",
            title: "Les Énergies Renouvelables",
            category: "Environnement",
            iconName: "bolt.batteryblock.fill",
            taskScope: "Tâches 2 & 3",
            examContext: "Transition énergétique face à l'urgence climatique et géopolitique mondiale.",
            avantages: [
                "Décarbonation durable : production électrique éolienne et solaire sans émission directe de CO2.",
                "Ressources inépuisables : exploitation d'énergies perpétuelles (soleil, vent, marées) à l'inverse des énergies fossiles.",
                "Souveraineté nationale : affranchissement de la dépendance économique envers les pays exportateurs d'hydrocarbures.",
                "Création d'emplois verts : développement rapide des filières industrielles d'installation et de maintenance."
            ],
            inconvenients: [
                "Intermittence de la production : dépendance absolue aux aléas météorologiques et absence de vent ou d'ensoleillement.",
                "Coût initial des infrastructures : investissements capitaux colossaux pour bâtir les parcs et adapter le réseau.",
                "Impact environnemental des batteries : extraction polluante des terres rares et métaux nécessaires au stockage."
            ],
            connecteursRecommandes: ["Face à l'urgence climatique", "Bien que la mise en œuvre soit ardue", "Par ailleurs", "Ainsi s'impose la nécessité"],
            sujetTypeExam: "« Les États doivent-ils interdire immédiatement les énergies fossiles au profit exclusif du renouvelable ? » Argumentez."
        ),
        TCFIdeaTopic(
            id: "tri_dechets",
            title: "Le Tri des Déchets & Économie Circulaire",
            category: "Environnement",
            iconName: "arrow.3.trianglepath",
            taskScope: "Tâches 2 & 3",
            examContext: "Gestion des déchets ménagers, responsabilité citoyenne et politique zéro déchet.",
            avantages: [
                "Désengorgement des décharges : baisse spectaculaire du volume de détritus incinérés ou enfouis.",
                "Économie de matières vierges : recyclage de l'aluminium, du verre et du papier évitant l'épuisement des ressources naturelles.",
                "Éveil de la conscience collective : rituel quotidien incitant les citoyens et enfants à consommer plus sobrement."
            ],
            inconvenients: [
                "Complexité des consignes : multiplication des bacs de couleurs provoquant des erreurs de tri fréquentes.",
                "Coût logistique des filières : camions dédiés et centres de tri automatisés pesant lourdement sur la fiscalité locale.",
                "Recyclabilité limitée de certains plastiques : procédés chimiques encore inefficaces pour les emballages multicouches."
            ],
            connecteursRecommandes: ["En premier lieu", "Il n'en demeure pas moins que", "Dès lors", "En définitive"],
            sujetTypeExam: "« Faut-il pénaliser financièrement les ménages qui ne trient pas rigoureusement leurs déchets ? » Partagez votre avis."
        ),
        TCFIdeaTopic(
            id: "sans_voiture",
            title: "Vivre sans Voiture en Ville",
            category: "Transports",
            iconName: "figure.walk",
            taskScope: "Tâches 2 & 3",
            examContext: "Mobilité douce, zones piétonnes et désengorgement des centres urbains.",
            avantages: [
                "Économies budgétaires considérables : suppression des coûts de carburant, d'assurance, d'entretien et de stationnement.",
                "Bénéfices pour la santé : incitation à la marche active et au vélo, réduisant les risques cardio-vasculaires.",
                "Amélioration du cadre de vie : diminution drastique du smog urbain, des particules fines et de la pollution sonore."
            ],
            inconvenients: [
                "Perte de spontanéité : assujettissement strict aux horaires et trajets fixes des transports en commun.",
                "Inapplicabilité en périphérie et campagne : isolement garanti dans les secteurs non desservis par le rail ou le bus.",
                "Pénibilité logistique : difficultés majeures pour transporter des charges lourdes ou voyager avec de jeunes enfants."
            ],
            connecteursRecommandes: ["Certes... mais", "D'un point de vue économique", "Il convient de nuancer", "En somme"],
            sujetTypeExam: "« Les métropoles doivent-elles bannir définitivement la voiture individuelle de leurs centres-villes ? » Développez."
        ),
        TCFIdeaTopic(
            id: "transports_gratuits",
            title: "La Gratuité des Transports Publics",
            category: "Transports",
            iconName: "tram.fill",
            taskScope: "Tâches 2 & 3",
            examContext: "Politiques tarifaires des transports urbains et égalité citoyenne.",
            avantages: [
                "Justice sociale universelle : mobilité accessible à tous, sans distinction de revenu (étudiants, sans-emploi, retraités).",
                "Report modal massif : incitation financière immédiate pour inciter les conducteurs à laisser leur voiture au garage.",
                "Simplification administrative : disparition des tourniquets, composteurs, contrôles et frais d'impression de tickets."
            ],
            inconvenients: [
                "Impact budgétaire pour la collectivité : compensation financière assurée par l'impôt de tous les contribuables.",
                "Risque de saturation et d'usure : afflux massif d'usagers dégradant le confort et la ponctualité du matériel roulant.",
                "Effet d'éviction de la marche : usagers prenant le bus pour une seule station au détriment de l'activité physique."
            ],
            connecteursRecommandes: ["À première vue", "Cependant, sur le plan budgétaire", "Par conséquent", "Au vu de ces éléments"],
            sujetTypeExam: "« Rendre les bus et métros totalement gratuits est-il le meilleur moyen de sauver le climat urbain ? » Qu'en pensez-vous ?"
        ),
        TCFIdeaTopic(
            id: "velo_quotidien",
            title: "Le Vélo comme Moyen de Transport Principal",
            category: "Transports",
            iconName: "bicycle",
            taskScope: "Tâches 2 & 3",
            examContext: "Aménagement des pistes cyclables, santé publique et cohabitation routière.",
            avantages: [
                "Rapidité imbattable en hypercentre : fluidité totale en évitant les bouchons et gain de temps sur le stationnement.",
                "Empreinte carbone nulle : mode de transport propre, silencieux et respectueux de l'environnement.",
                "Activité physique intégrée : maintien d'une hygiène de vie saine sans abonnement en salle de sport."
            ],
            inconvenients: [
                "Sensibilité météorologique : rigueur des hivers canadiens (neige, verglas) et intempéries rendant la pratique périlleuse.",
                "Insécurité routière persistante : risques constants de collision avec les automobiles faute de pistes protégées.",
                "Limitation des distances : inadapté pour des trajets quotidiens supérieurs à une dizaine de kilomètres."
            ],
            connecteursRecommandes: ["D'une part", "D'autre part", "Néanmoins, les conditions climatiques", "Tout bien considéré"],
            sujetTypeExam: "« Peut-on raisonnablement envisager le vélo comme substitut universel à l'automobile ? » Partagez votre opinion."
        ),
        TCFIdeaTopic(
            id: "ia_travail",
            title: "L'Intelligence Artificielle au Travail",
            category: "Technologie",
            iconName: "cpu",
            taskScope: "Tâches 2 & 3",
            examContext: "Automatisation, robotique et avenir de l'emploi à l'ère des algorithmes génératifs.",
            avantages: [
                "Productivité décuplée : traitement automatisé de données volumineuses et rédaction assistée de synthèses.",
                "Élimination des corvées répétitives : libération de temps pour les missions créatives et relationnelles à haute valeur.",
                "Précision accrue : réduction des erreurs de calcul et d'analyse dans des domaines exigeants comme la finance ou la médecine."
            ],
            inconvenients: [
                "Menace sur les emplois qualifiés : obsolescence rapide de postes de rédaction, traduction et support client.",
                "Déshumanisation du management : évaluation algorithmique de la cadence de travail créant une pression toxique.",
                "Failles éthiques et sécurité : risques de divulgation de secrets industriels et de biais discriminatoires non contrôlés."
            ],
            connecteursRecommandes: ["À l'évidence", "Toutefois, une vigilance s'impose", "En d'autres termes", "Il apparaît donc que"],
            sujetTypeExam: "« L'intelligence artificielle représente-t-elle une opportunité inouïe ou un péril mortel pour le travailleur moderne ? »"
        ),
        TCFIdeaTopic(
            id: "reseaux_sociaux",
            title: "L'Impact des Réseaux Sociaux",
            category: "Société",
            iconName: "bubble.left.and.bubble.right.fill",
            taskScope: "Tâches 2 & 3",
            examContext: "Hyper-connexion, communication planétaire et bien-être psychologique.",
            avantages: [
                "Connexion sans frontières : maintien de liens vivants avec des proches installés au bout du monde.",
                "Solidarité et entraide citoyenne : constitution rapide de réseaux de soutien pour les nouveaux arrivants au Canada.",
                "Tremplin professionnel et artistique : visibilité immédiate pour les artisans, freelances et créateurs indépendants."
            ],
            inconvenients: [
                "Désinformation massive : propagation virale de fausses nouvelles et de théories complotistes sans filtre éditorial.",
                "Détérioration de la santé mentale : comparaison sociale permanente, baisse de l'estime de soi et cyber-harcèlement.",
                "Chronophagie et addiction : scrolling compulsif empiétant sur le temps de sommeil, de lecture et les échanges réels."
            ],
            connecteursRecommandes: ["Certes, les plateformes offrent", "Toutefois, les dérives constatées", "De surcroît", "En définitive"],
            sujetTypeExam: "« Les réseaux sociaux rapprochent-ils les individus ou favorisent-ils l'isolement social ? » Rédigez une synthèse critique."
        ),
        TCFIdeaTopic(
            id: "telephones_ecole",
            title: "Les Smartphones dans les Établissements Scolaires",
            category: "Éducation",
            iconName: "iphone.gen3",
            taskScope: "Tâches 2 & 3",
            examContext: "Pédagogie numérique, attention des élèves et cadre réglementaire en classe.",
            avantages: [
                "Accès immédiat au savoir : consultation instantanée de dictionnaires, encyclopédies et outils de calcul en classe.",
                "Rassurance parentale : moyen pour les familles de rester en contact en cas d'urgence durant les trajets scolaires.",
                "Apprentissage de la citoyenneté numérique : opportunité d'éduquer les jeunes aux bons usages sous l'œil des pédagogues."
            ],
            inconvenients: [
                "Source constante de distraction : alertes, notifications de jeux et messages perturbant gravement les cours.",
                "Déclin des jeux collectifs en récréation : sédentarité accrue des élèves captivés par leurs écrans individuels.",
                "Vecteur de triche et de harcèlement : enregistrements vidéo à l'insu d'autrui et diffusion de contenus préjudiciables."
            ],
            connecteursRecommandes: ["Si l'outil peut s'avérer utile", "Il n'en reste pas moins que", "Par conséquent", "Pour conclure"],
            sujetTypeExam: "« Doit-on interdire purement et simplement les téléphones portables dans toutes les écoles ? » Exprimez votre avis."
        ),
        TCFIdeaTopic(
            id: "travail_etranger",
            title: "Partir Travailler à l'Étranger (Immigration)",
            category: "Société",
            iconName: "airplane.departure",
            taskScope: "Tâches 2 & 3",
            examContext: "Expatriation, mobilité internationale et intégration socio-professionnelle.",
            avantages: [
                "Enrichissement personnel remarquable : ouverture à une nouvelle culture et développement de l'adaptabilité.",
                "Atout majeur sur le CV : maîtrise des langues étrangères et valorisation d'une expérience internationale diversifiée.",
                "Perspectives de carrière supérieures : opportunités économiques attractives dans les secteurs en pénurie au Canada."
            ],
            inconvenients: [
                "Éloignement affectif : manque de la famille, des repères culturels et sentiment d'isolement au démarrage.",
                "Parcours administratif fastidieux : reconnaissance des diplômes étrangers, permis de travail et équivalences de titres.",
                "Choc culturel et linguistique : adaptation parfois ardue aux codes tacites du milieu de travail d'accueil."
            ],
            connecteursRecommandes: ["L'expatriation constitue incontestablement", "Néanmoins, les embûches", "C'est la raison pour laquelle", "Au final"],
            sujetTypeExam: "« Vivre et travailler dans un autre pays est-il une expérience indispensable pour réussir sa vie professionnelle ? »"
        ),
        TCFIdeaTopic(
            id: "musees_gratuits",
            title: "La Gratuité des Musées et Lieux Culturels",
            category: "Culture",
            iconName: "building.columns.fill",
            taskScope: "Tâches 2 & 3",
            examContext: "Démocratisation de l'art, financement public et politiques culturelles.",
            avantages: [
                "Égalité d'accès aux chefs-d'œuvre : suppression de la barrière financière pour les familles et étudiants.",
                "Rayonnement touristique : augmentation sensible de la fréquentation globale et dynamisation du commerce local.",
                "Éveil artistique spontané : visites fréquentes et détendues, encourageant la curiosité dès le plus jeune âge."
            ],
            inconvenients: [
                "Pression financière sur l'État : baisse des recettes propres obligeant à des subventions publiques plus lourdes.",
                "Risque d'engorgement : afflux touristique massif nuisant à la quiétude de la contemplation et à la sécurité des œuvres.",
                "Moins de budget pour les grandes expositions : limitation des acquisitions et restaurations faute de rentrées billetterie."
            ],
            connecteursRecommandes: ["La culture étant un bien commun", "Cependant, il ne faut pas sous-estimer", "Dès lors", "En conclusion"],
            sujetTypeExam: "« La gratuité générale des musées favorise-t-elle véritablement l'accès des classes populaires à l'art ? » Débattez."
        ),
        TCFIdeaTopic(
            id: "impact_tourisme",
            title: "L'Impact Écologique du Tourisme de Masse",
            category: "Voyage",
            iconName: "globe.americas.fill",
            taskScope: "Tâches 2 & 3",
            examContext: "Surtourisme, empreinte carbone des voyages et préservation des écosystèmes.",
            avantages: [
                "Vitalité économique des régions : création d'emplois locaux non délocalisables (hôtellerie, restauration, artisanat).",
                "Entretien du patrimoine : taxes de séjour finançant la conservation des monuments historiques et des parcs naturels.",
                "Tolérance interculturelle : découverte respectueuse des coutumes et rapprochement des peuples."
            ],
            inconvenients: [
                "Pollution massive des transports : bilan carbone désastreux des vols long-courriers et des paquebots de croisière.",
                "Dégradation des sites naturels : érosion des sentiers, pollution plastique sur les plages et bétonisation des côtes.",
                "Crise du logement pour les résidents : multiplication des locations touristiques de courte durée chassant les locaux."
            ],
            connecteursRecommandes: ["Si le tourisme dynamise l'économie", "Force est de constater ses ravages", "Il apparaît impératif de", "En somme"],
            sujetTypeExam: "« Doit-on instaurer des quotas stricts pour limiter le nombre de visiteurs sur les sites naturels fragiles ? »"
        ),
        TCFIdeaTopic(
            id: "sieste_travail",
            title: "La Sieste au Travail",
            category: "Travail",
            iconName: "bed.double.fill",
            taskScope: "Tâches 2 & 3",
            examContext: "Rythmes circadiens, bien-être en entreprise et performance cognitive.",
            avantages: [
                "Régénération cognitive prouvée : une micro-sieste de 15 à 20 minutes restaure l'attention et la mémoire pour l'après-midi.",
                "Réduction du stress et de l'irritabilité : baisse de la tension nerveuse favorisant des relations de travail sereines.",
                "Prévention des accidents : diminution drastique des fautes d'inattention dans les métiers techniques et manuels."
            ],
            inconvenients: [
                "Persistance de préjugés culturels : assimilation trompeuse du repos à la paresse ou au manque de professionnalisme.",
                "Risque d'inertie du sommeil : difficultés à redémarrer immédiatement si le sommeil dépasse 30 minutes.",
                "Contraintes d'aménagement : obligation pour l'employeur de disposer de salles calmes, sombres et bien insonorisées."
            ],
            connecteursRecommandes: ["Loin d'être une perte de temps", "Néanmoins, son instauration requiert", "C'est ainsi que", "En définitive"],
            sujetTypeExam: "« Les entreprises devraient-elles aménager des espaces de sieste obligatoires pour leurs collaborateurs ? » Donnez votre avis."
        ),
        TCFIdeaTopic(
            id: "changement_carriere",
            title: "La Reconversion Professionnelle",
            category: "Travail",
            iconName: "arrow.triangle.2.circlepath",
            taskScope: "Tâches 2 & 3",
            examContext: "Carrières non linéaires, formation continue et épanouissement personnel.",
            avantages: [
                "Alignement avec ses valeurs : chance de quitter un emploi devenu mécanique pour un métier porteur de sens.",
                "Enrichissement par la polyvalence : combinaison unique de compétences issues d'horizons professionnels distincts.",
                "Adaptation aux mutations sociétales : opportunité de s'orienter vers des secteurs d'avenir (transition écologique, santé)."
            ],
            inconvenients: [
                "Précarité financière passagère : baisse des revenus pendant la période de reprise d'études ou de reconversion.",
                "Sentiment d'illégitimité et remise en question : stress de repartir de zéro au milieu de collègues plus expérimentés.",
                "Charge mentale intense : concilier les exigences de formation avec la vie familiale et les charges du foyer."
            ],
            connecteursRecommandes: ["Changer de cap professionnel suppose", "Malgré les doutes légitimes", "Par conséquent", "Pour résumer"],
            sujetTypeExam: "« Changer plusieurs fois de métier au cours d'une vie est-il un gage de réussite ou un signe d'instabilité ? »"
        ),
        TCFIdeaTopic(
            id: "amitie_travail",
            title: "L'Amitié et la Convivialité au Travail",
            category: "Travail",
            iconName: "person.2.fill",
            taskScope: "Tâches 2 & 3",
            examContext: "Cohésion d'équipe, climat d'entreprise et frontières professionnelles.",
            avantages: [
                "Climat de travail stimulant : plaisir quotidien à collaborer renforçant l'engagement et réduisant le burn-out.",
                "Entraide et réactivité spontanée : résolution collective plus rapide des problèmes sans passer par la hiérarchie lourde.",
                "Fluidité de communication : franchise accrue et absence de faux-semblants lors des réunions d'équipe."
            ],
            inconvenients: [
                "Confusion des registres : difficulté éprouvée à critiquer objectivement le travail d'un ami ou à le manager.",
                "Effet de clan néfaste : risque de créer des cercles fermés générant un sentiment d'exclusion pour les nouveaux arrivants.",
                "Impact des conflits personnels : retombées émotionnelles sur l'ambiance du bureau en cas de brouille amicale."
            ],
            connecteursRecommandes: ["Si la complicité entre collègues favorise", "Elle peut néanmoins compliquer", "D'où l'importance de", "En conclusion"],
            sujetTypeExam: "« L'amitié sur le lieu de travail nuit-elle à la rigueur professionnelle ou en est-elle le moteur ? » Développez votre point de vue."
        )
    ]
}
