
;; title: historical-musician-ai
;; version: 1.0.0
;; summary: AI recreations of legendary clarinetists for interactive lessons
;; description: This contract manages historical musician profiles, lesson scheduling,
;;              performance evaluation, achievements, and certification system for
;;              immersive learning experiences with legendary clarinetists.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_MUSICIAN_NOT_FOUND (err u201))
(define-constant ERR_LESSON_NOT_FOUND (err u202))
(define-constant ERR_INVALID_PARAMETERS (err u203))
(define-constant ERR_LESSON_CONFLICT (err u204))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u205))
(define-constant ERR_LESSON_ALREADY_COMPLETED (err u206))
(define-constant ERR_EVALUATION_NOT_FOUND (err u207))
(define-constant ERR_CERTIFICATE_NOT_EARNED (err u208))
(define-constant ERR_MUSICIAN_NOT_ACTIVE (err u209))

;; Lesson status constants
(define-constant LESSON_SCHEDULED u1)
(define-constant LESSON_IN_PROGRESS u2)
(define-constant LESSON_COMPLETED u3)
(define-constant LESSON_CANCELLED u4)

;; Performance grade constants
(define-constant GRADE_F u0) ;; 0-59
(define-constant GRADE_D u1) ;; 60-69
(define-constant GRADE_C u2) ;; 70-79
(define-constant GRADE_B u3) ;; 80-89
(define-constant GRADE_A u4) ;; 90-100

;; Achievement levels
(define-constant NOVICE_LEVEL u1)
(define-constant INTERMEDIATE_LEVEL u2)
(define-constant ADVANCED_LEVEL u3)
(define-constant MASTER_LEVEL u4)

;; Lesson type constants
(define-constant TECHNIQUE_LESSON u1)
(define-constant REPERTOIRE_LESSON u2)
(define-constant IMPROVISATION_LESSON u3)
(define-constant MASTERCLASS_LESSON u4)

;; Minimum and maximum lesson duration (in seconds)
(define-constant MIN_LESSON_DURATION u1800) ;; 30 minutes
(define-constant MAX_LESSON_DURATION u10800) ;; 3 hours
(define-constant BASE_LESSON_COST u2000000) ;; 2 STX in microSTX

;; data vars
(define-data-var musician-counter uint u0)
(define-data-var lesson-counter uint u0)
(define-data-var evaluation-counter uint u0)
(define-data-var certificate-counter uint u0)
(define-data-var contract-paused bool false)

;; data maps
;; Historical musician AI profiles
(define-map musicians
  uint ;; musician-id
  {
    name: (string-ascii 64),
    era: (string-ascii 32),
    specialties: (list 5 (string-ascii 32)),
    biography: (string-ascii 512),
    difficulty-level: uint,
    total-lessons: uint,
    average-rating: uint,
    is-active: bool,
    created-at: uint,
    creator: principal
  }
)

;; Lesson scheduling and management
(define-map lessons
  uint ;; lesson-id
  {
    student: principal,
    musician-id: uint,
    lesson-type: uint,
    scheduled-time: uint,
    duration: uint,
    status: uint,
    topic: (string-ascii 128),
    difficulty: uint,
    cost: uint,
    created-at: uint
  }
)

;; Performance evaluations
(define-map evaluations
  uint ;; evaluation-id
  {
    lesson-id: uint,
    student: principal,
    musician-id: uint,
    technique-score: uint,
    musicality-score: uint,
    rhythm-score: uint,
    tone-score: uint,
    overall-score: uint,
    grade: uint,
    feedback: (string-ascii 512),
    improvement-areas: (list 3 (string-ascii 64)),
    evaluated-at: uint
  }
)

;; Student progress tracking
(define-map student-progress
  principal
  {
    total-lessons: uint,
    total-practice-time: uint,
    current-level: uint,
    achievement-points: uint,
    completed-courses: (list 10 uint),
    favorite-musician: (optional uint),
    strengths: (list 5 (string-ascii 32)),
    weaknesses: (list 5 (string-ascii 32))
  }
)

;; Achievement and certification system
(define-map certificates
  uint ;; certificate-id
  {
    student: principal,
    musician-id: uint,
    certificate-type: (string-ascii 64),
    level: uint,
    requirements-met: (list 5 uint),
    issued-at: uint,
    valid-until: (optional uint),
    signature-hash: (buff 32)
  }
)

;; Musician statistics and analytics
(define-map musician-stats
  uint ;; musician-id
  {
    total-students: uint,
    total-lesson-hours: uint,
    average-student-score: uint,
    completion-rate: uint,
    revenue-generated: uint,
    student-satisfaction: uint
  }
)

;; Student-musician relationship tracking
(define-map student-musician-history
  { student: principal, musician-id: uint }
  {
    first-lesson-at: uint,
    last-lesson-at: uint,
    total-lessons: uint,
    average-score: uint,
    relationship-level: uint,
    unlocked-content: (list 10 uint)
  }
)

;; public functions

;; Register a new historical musician AI
(define-public (register-musician
    (name (string-ascii 64))
    (era (string-ascii 32))
    (specialties (list 5 (string-ascii 32)))
    (biography (string-ascii 512))
    (difficulty-level uint))
  (let ((musician-id (+ (var-get musician-counter) u1)))
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                  (> (len name) u0)) ERR_UNAUTHORIZED)
    (asserts! (and (>= difficulty-level u1) (<= difficulty-level u5)) ERR_INVALID_PARAMETERS)
    (asserts! (and (> (len name) u0) (> (len era) u0)) ERR_INVALID_PARAMETERS)
    
    (map-set musicians musician-id {
      name: name,
      era: era,
      specialties: specialties,
      biography: biography,
      difficulty-level: difficulty-level,
      total-lessons: u0,
      average-rating: u0,
      is-active: true,
      created-at: stacks-block-height,
      creator: tx-sender
    })
    
    ;; Initialize musician statistics
    (map-set musician-stats musician-id {
      total-students: u0,
      total-lesson-hours: u0,
      average-student-score: u0,
      completion-rate: u0,
      revenue-generated: u0,
      student-satisfaction: u0
    })
    
    (var-set musician-counter musician-id)
    (ok musician-id)
  )
)

;; Schedule a lesson with a historical musician
(define-public (schedule-lesson
    (musician-id uint)
    (lesson-type uint)
    (scheduled-time uint)
    (duration uint)
    (topic (string-ascii 128))
    (difficulty uint))
  (let ((lesson-id (+ (var-get lesson-counter) u1))
        (musician-info (unwrap! (map-get? musicians musician-id) ERR_MUSICIAN_NOT_FOUND))
        (lesson-cost (calculate-lesson-cost musician-id duration difficulty)))
    
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (get is-active musician-info) ERR_MUSICIAN_NOT_ACTIVE)
    (asserts! (and (>= duration MIN_LESSON_DURATION)
                   (<= duration MAX_LESSON_DURATION)) ERR_INVALID_PARAMETERS)
    (asserts! (and (>= lesson-type u1) (<= lesson-type u4)) ERR_INVALID_PARAMETERS)
    (asserts! (and (>= difficulty u1) (<= difficulty u5)) ERR_INVALID_PARAMETERS)
    (asserts! (> scheduled-time stacks-block-height) ERR_INVALID_PARAMETERS)
    
    ;; Check for scheduling conflicts
    (asserts! (not (has-lesson-conflict tx-sender scheduled-time duration)) ERR_LESSON_CONFLICT)
    
    (map-set lessons lesson-id {
      student: tx-sender,
      musician-id: musician-id,
      lesson-type: lesson-type,
      scheduled-time: scheduled-time,
      duration: duration,
      status: LESSON_SCHEDULED,
      topic: topic,
      difficulty: difficulty,
      cost: lesson-cost,
      created-at: stacks-block-height
    })
    
    ;; Update student progress
    (update-student-progress tx-sender musician-id)
    
    (var-set lesson-counter lesson-id)
    (ok lesson-id)
  )
)

;; Complete a lesson and create evaluation
(define-public (complete-lesson
    (lesson-id uint)
    (technique-score uint)
    (musicality-score uint)
    (rhythm-score uint)
    (tone-score uint)
    (feedback (string-ascii 512))
    (improvement-areas (list 3 (string-ascii 64))))
  (let ((lesson-info (unwrap! (map-get? lessons lesson-id) ERR_LESSON_NOT_FOUND))
        (evaluation-id (+ (var-get evaluation-counter) u1))
        (overall-score (calculate-overall-score technique-score musicality-score rhythm-score tone-score))
        (grade (score-to-grade overall-score)))
    
    (asserts! (is-eq (get student lesson-info) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status lesson-info) LESSON_SCHEDULED) ERR_LESSON_ALREADY_COMPLETED)
    (asserts! (validate-scores technique-score musicality-score rhythm-score tone-score) ERR_INVALID_PARAMETERS)
    
    ;; Update lesson status
    (map-set lessons lesson-id
      (merge lesson-info { status: LESSON_COMPLETED })
    )
    
    ;; Create evaluation record
    (map-set evaluations evaluation-id {
      lesson-id: lesson-id,
      student: tx-sender,
      musician-id: (get musician-id lesson-info),
      technique-score: technique-score,
      musicality-score: musicality-score,
      rhythm-score: rhythm-score,
      tone-score: tone-score,
      overall-score: overall-score,
      grade: grade,
      feedback: feedback,
      improvement-areas: improvement-areas,
      evaluated-at: stacks-block-height
    })
    
    ;; Update musician statistics
    (update-musician-stats (get musician-id lesson-info) (get duration lesson-info) overall-score)
    
    ;; Update student-musician relationship
    (update-student-musician-relationship tx-sender (get musician-id lesson-info) overall-score)
    
    ;; Award achievement points
    (award-lesson-points tx-sender overall-score (get duration lesson-info) (get difficulty lesson-info))
    
    (var-set evaluation-counter evaluation-id)
    (ok evaluation-id)
  )
)

;; Issue a certificate upon meeting requirements
(define-public (issue-certificate
    (student principal)
    (musician-id uint)
    (certificate-type (string-ascii 64))
    (level uint)
    (requirements-met (list 5 uint))
    (valid-duration (optional uint)))
  (let ((certificate-id (+ (var-get certificate-counter) u1))
        (musician-info (unwrap! (map-get? musicians musician-id) ERR_MUSICIAN_NOT_FOUND))
        (signature-hash (generate-certificate-hash certificate-id student musician-id level)))
    
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                  (is-eq tx-sender (get creator musician-info))) ERR_UNAUTHORIZED)
    (asserts! (meets-certificate-requirements student musician-id level requirements-met) ERR_CERTIFICATE_NOT_EARNED)
    (asserts! (and (>= level u1) (<= level u4)) ERR_INVALID_PARAMETERS)
    
    (map-set certificates certificate-id {
      student: student,
      musician-id: musician-id,
      certificate-type: certificate-type,
      level: level,
      requirements-met: requirements-met,
      issued-at: stacks-block-height,
      valid-until: (match valid-duration dur (some (+ stacks-block-height dur)) none),
      signature-hash: signature-hash
    })
    
    ;; Update student achievement level
    (update-student-achievement-level student level)
    
    (var-set certificate-counter certificate-id)
    (ok certificate-id)
  )
)

;; Cancel a scheduled lesson
(define-public (cancel-lesson (lesson-id uint))
  (let ((lesson-info (unwrap! (map-get? lessons lesson-id) ERR_LESSON_NOT_FOUND)))
    (asserts! (is-eq (get student lesson-info) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status lesson-info) LESSON_SCHEDULED) ERR_INVALID_PARAMETERS)
    
    (map-set lessons lesson-id
      (merge lesson-info { status: LESSON_CANCELLED })
    )
    
    (ok true)
  )
)

;; Rate a musician after lesson completion
(define-public (rate-musician
    (musician-id uint)
    (rating uint))
  (let ((musician-info (unwrap! (map-get? musicians musician-id) ERR_MUSICIAN_NOT_FOUND)))
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_PARAMETERS)
    (asserts! (has-completed-lesson-with-musician tx-sender musician-id) ERR_UNAUTHORIZED)
    
    ;; Update musician rating (simplified implementation)
    (map-set musicians musician-id
      (merge musician-info {
        total-lessons: (+ (get total-lessons musician-info) u1)
      })
    )
    
    (ok true)
  )
)

;; Admin function to toggle musician active status
(define-public (toggle-musician-status (musician-id uint))
  (let ((musician-info (unwrap! (map-get? musicians musician-id) ERR_MUSICIAN_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                  (is-eq tx-sender (get creator musician-info))) ERR_UNAUTHORIZED)
    
    (map-set musicians musician-id
      (merge musician-info {
        is-active: (not (get is-active musician-info))
      })
    )
    
    (ok (not (get is-active musician-info)))
  )
)

;; Admin function to pause/unpause contract
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

;; read only functions

;; Get musician information
(define-read-only (get-musician (musician-id uint))
  (map-get? musicians musician-id)
)

;; Get lesson information
(define-read-only (get-lesson (lesson-id uint))
  (map-get? lessons lesson-id)
)

;; Get evaluation information
(define-read-only (get-evaluation (evaluation-id uint))
  (map-get? evaluations evaluation-id)
)

;; Get certificate information
(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates certificate-id)
)

;; Get student progress
(define-read-only (get-student-progress (student principal))
  (map-get? student-progress student)
)

;; Get musician statistics
(define-read-only (get-musician-stats (musician-id uint))
  (map-get? musician-stats musician-id)
)

;; Get student-musician relationship history
(define-read-only (get-student-musician-history (student principal) (musician-id uint))
  (map-get? student-musician-history { student: student, musician-id: musician-id })
)

;; Get total counts
(define-read-only (get-musician-count)
  (var-get musician-counter)
)

(define-read-only (get-lesson-count)
  (var-get lesson-counter)
)

(define-read-only (get-evaluation-count)
  (var-get evaluation-counter)
)

(define-read-only (get-certificate-count)
  (var-get certificate-counter)
)

;; Check if contract is paused
(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

;; private functions

;; Calculate lesson cost based on musician, duration, and difficulty
(define-private (calculate-lesson-cost (musician-id uint) (duration uint) (difficulty uint))
  (let ((base-cost BASE_LESSON_COST)
        (duration-multiplier (/ duration u1800)) ;; Per 30-minute segments
        (difficulty-multiplier difficulty))
    (* base-cost (* duration-multiplier difficulty-multiplier))
  )
)

;; Check for lesson scheduling conflicts
(define-private (has-lesson-conflict (student principal) (scheduled-time uint) (duration uint))
  ;; Simplified implementation - always returns false
  false
)

;; Calculate overall score from individual components
(define-private (calculate-overall-score (technique uint) (musicality uint) (rhythm uint) (tone uint))
  (/ (+ technique musicality rhythm tone) u4)
)

;; Convert numerical score to letter grade
(define-private (score-to-grade (score uint))
  (if (>= score u90) GRADE_A
    (if (>= score u80) GRADE_B
      (if (>= score u70) GRADE_C
        (if (>= score u60) GRADE_D
          GRADE_F
        )
      )
    )
  )
)

;; Validate score parameters
(define-private (validate-scores (technique uint) (musicality uint) (rhythm uint) (tone uint))
  (and (<= technique u100) (<= musicality u100) (<= rhythm u100) (<= tone u100))
)

;; Update student progress tracking
(define-private (update-student-progress (student principal) (musician-id uint))
  (let ((current-progress (default-to
                            { total-lessons: u0, total-practice-time: u0,
                              current-level: NOVICE_LEVEL, achievement-points: u0,
                              completed-courses: (list), favorite-musician: none,
                              strengths: (list), weaknesses: (list) }
                            (map-get? student-progress student))))
    (map-set student-progress student
      (merge current-progress {
        total-lessons: (+ (get total-lessons current-progress) u1)
      })
    )
  )
)

;; Update musician statistics
(define-private (update-musician-stats (musician-id uint) (duration uint) (score uint))
  (let ((current-stats (default-to
                         { total-students: u0, total-lesson-hours: u0,
                           average-student-score: u0, completion-rate: u0,
                           revenue-generated: u0, student-satisfaction: u0 }
                         (map-get? musician-stats musician-id))))
    (map-set musician-stats musician-id
      (merge current-stats {
        total-lesson-hours: (+ (get total-lesson-hours current-stats) (/ duration u3600))
      })
    )
  )
)

;; Update student-musician relationship
(define-private (update-student-musician-relationship (student principal) (musician-id uint) (score uint))
  (let ((current-history (default-to
                           { first-lesson-at: stacks-block-height, last-lesson-at: stacks-block-height,
                             total-lessons: u0, average-score: u0,
                             relationship-level: u1, unlocked-content: (list) }
                           (map-get? student-musician-history { student: student, musician-id: musician-id }))))
    (map-set student-musician-history { student: student, musician-id: musician-id }
      (merge current-history {
        last-lesson-at: stacks-block-height,
        total-lessons: (+ (get total-lessons current-history) u1)
      })
    )
  )
)

;; Award achievement points for lesson completion
(define-private (award-lesson-points (student principal) (score uint) (duration uint) (difficulty uint))
  (let ((current-progress (default-to
                            { total-lessons: u0, total-practice-time: u0,
                              current-level: NOVICE_LEVEL, achievement-points: u0,
                              completed-courses: (list), favorite-musician: none,
                              strengths: (list), weaknesses: (list) }
                            (map-get? student-progress student)))
        (base-points (/ duration u1800)) ;; 1 point per 30 minutes
        (score-bonus (/ score u10))
        (difficulty-bonus difficulty)
        (total-points (+ base-points (+ score-bonus difficulty-bonus))))
    
    (map-set student-progress student
      (merge current-progress {
        total-practice-time: (+ (get total-practice-time current-progress) duration),
        achievement-points: (+ (get achievement-points current-progress) total-points)
      })
    )
  )
)

;; Check if student meets certificate requirements
(define-private (meets-certificate-requirements (student principal) (musician-id uint) (level uint) (requirements (list 5 uint)))
  ;; Simplified implementation - always returns true
  true
)

;; Update student achievement level
(define-private (update-student-achievement-level (student principal) (level uint))
  (let ((current-progress (default-to
                            { total-lessons: u0, total-practice-time: u0,
                              current-level: NOVICE_LEVEL, achievement-points: u0,
                              completed-courses: (list), favorite-musician: none,
                              strengths: (list), weaknesses: (list) }
                            (map-get? student-progress student))))
    (map-set student-progress student
      (merge current-progress {
        current-level: (if (> level (get current-level current-progress))
                         level
                         (get current-level current-progress))
      })
    )
  )
)

;; Generate certificate signature hash (simplified)
(define-private (generate-certificate-hash (cert-id uint) (student principal) (musician-id uint) (level uint))
  (sha256 (+ cert-id (* musician-id level)))
)

;; Check if student has completed lesson with musician
(define-private (has-completed-lesson-with-musician (student principal) (musician-id uint))
  (is-some (map-get? student-musician-history { student: student, musician-id: musician-id }))
)

