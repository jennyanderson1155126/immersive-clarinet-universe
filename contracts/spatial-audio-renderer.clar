
;; title: spatial-audio-renderer
;; version: 1.0.0
;; summary: Creates photorealistic acoustic environments from concert halls worldwide
;; description: This contract manages virtual venue registration, acoustic parameters,
;;              user access control, and performance session tracking for immersive
;;              clarinet practice experiences.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_VENUE_NOT_FOUND (err u101))
(define-constant ERR_VENUE_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMETERS (err u103))
(define-constant ERR_SESSION_NOT_FOUND (err u104))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u105))
(define-constant ERR_VENUE_NOT_ACTIVE (err u106))
(define-constant ERR_ACCESS_DENIED (err u107))

;; Venue access levels
(define-constant ACCESS_PUBLIC u1)
(define-constant ACCESS_PREMIUM u2)
(define-constant ACCESS_EXCLUSIVE u3)

;; Session status constants
(define-constant SESSION_ACTIVE u1)
(define-constant SESSION_COMPLETED u2)
(define-constant SESSION_CANCELLED u3)

;; Maximum values for acoustic parameters (0-100 scale)
(define-constant MAX_ACOUSTIC_VALUE u100)
(define-constant MIN_SESSION_DURATION u300) ;; 5 minutes minimum
(define-constant MAX_SESSION_DURATION u21600) ;; 6 hours maximum

;; data vars
(define-data-var venue-counter uint u0)
(define-data-var session-counter uint u0)
(define-data-var contract-paused bool false)
(define-data-var base-session-cost uint u1000000) ;; 1 STX in microSTX

;; data maps
;; Virtual venue registry with acoustic parameters
(define-map venues
  uint ;; venue-id
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    creator: principal,
    reverb-level: uint,
    echo-delay: uint,
    ambience-volume: uint,
    frequency-response: (list 10 uint), ;; 10-band EQ settings
    access-level: uint,
    is-active: bool,
    created-at: uint,
    usage-count: uint,
    rating-sum: uint,
    rating-count: uint
  }
)

;; User access permissions for premium venues
(define-map user-access
  { user: principal, venue-id: uint }
  {
    granted-at: uint,
    expires-at: (optional uint),
    granted-by: principal
  }
)

;; Performance sessions tracking
(define-map performance-sessions
  uint ;; session-id
  {
    user: principal,
    venue-id: uint,
    start-time: uint,
    duration: uint,
    status: uint,
    recording-hash: (optional (buff 32)),
    performance-score: (optional uint),
    notes: (optional (string-ascii 256))
  }
)

;; User session history
(define-map user-sessions
  principal
  {
    total-sessions: uint,
    total-practice-time: uint,
    favorite-venue: (optional uint),
    achievement-points: uint
  }
)

;; Venue usage statistics
(define-map venue-stats
  uint ;; venue-id
  {
    total-sessions: uint,
    total-duration: uint,
    unique-users: uint,
    peak-concurrent: uint,
    revenue-generated: uint
  }
)

;; public functions

;; Register a new virtual venue
(define-public (register-venue 
    (name (string-ascii 64))
    (description (string-ascii 256))
    (reverb-level uint)
    (echo-delay uint)
    (ambience-volume uint)
    (frequency-response (list 10 uint))
    (access-level uint))
  (let ((venue-id (+ (var-get venue-counter) u1)))
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (and (<= reverb-level MAX_ACOUSTIC_VALUE) 
                   (<= echo-delay MAX_ACOUSTIC_VALUE)
                   (<= ambience-volume MAX_ACOUSTIC_VALUE)) ERR_INVALID_PARAMETERS)
    (asserts! (and (>= access-level ACCESS_PUBLIC) 
                   (<= access-level ACCESS_EXCLUSIVE)) ERR_INVALID_PARAMETERS)
    (asserts! (is-eq (len frequency-response) u10) ERR_INVALID_PARAMETERS)
    
    ;; Validate frequency response values
    (asserts! (fold check-frequency-value frequency-response true) ERR_INVALID_PARAMETERS)
    
    (map-set venues venue-id {
      name: name,
      description: description,
      creator: tx-sender,
      reverb-level: reverb-level,
      echo-delay: echo-delay,
      ambience-volume: ambience-volume,
      frequency-response: frequency-response,
      access-level: access-level,
      is-active: true,
      created-at: stacks-block-height,
      usage-count: u0,
      rating-sum: u0,
      rating-count: u0
    })
    
    ;; Initialize venue statistics
    (map-set venue-stats venue-id {
      total-sessions: u0,
      total-duration: u0,
      unique-users: u0,
      peak-concurrent: u0,
      revenue-generated: u0
    })
    
    (var-set venue-counter venue-id)
    (ok venue-id)
  )
)

;; Start a performance session in a venue
(define-public (start-session 
    (venue-id uint)
    (duration uint))
  (let ((session-id (+ (var-get session-counter) u1))
        (venue-info (unwrap! (map-get? venues venue-id) ERR_VENUE_NOT_FOUND))
        (session-cost (* (var-get base-session-cost) (/ duration u3600))))
    
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (get is-active venue-info) ERR_VENUE_NOT_ACTIVE)
    (asserts! (and (>= duration MIN_SESSION_DURATION) 
                   (<= duration MAX_SESSION_DURATION)) ERR_INVALID_PARAMETERS)
    
    ;; Check access permissions for premium venues
    (asserts! (has-venue-access tx-sender venue-id venue-info) ERR_ACCESS_DENIED)
    
    ;; Record the session
    (map-set performance-sessions session-id {
      user: tx-sender,
      venue-id: venue-id,
      start-time: stacks-block-height,
      duration: duration,
      status: SESSION_ACTIVE,
      recording-hash: none,
      performance-score: none,
      notes: none
    })
    
    ;; Update user session history
    (update-user-sessions tx-sender)
    
    ;; Update venue usage statistics
    (update-venue-usage venue-id duration)
    
    (var-set session-counter session-id)
    (ok session-id)
  )
)

;; Complete a performance session with optional recording and score
(define-public (complete-session 
    (session-id uint)
    (recording-hash (optional (buff 32)))
    (performance-score (optional uint))
    (notes (optional (string-ascii 256))))
  (let ((session-info (unwrap! (map-get? performance-sessions session-id) ERR_SESSION_NOT_FOUND)))
    (asserts! (is-eq (get user session-info) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status session-info) SESSION_ACTIVE) ERR_INVALID_PARAMETERS)
    
    ;; Update session with completion details
    (map-set performance-sessions session-id 
      (merge session-info {
        status: SESSION_COMPLETED,
        recording-hash: recording-hash,
        performance-score: performance-score,
        notes: notes
      })
    )
    
    ;; Award achievement points based on performance
    (award-achievement-points tx-sender performance-score (get duration session-info))
    
    (ok true)
  )
)

;; Grant access to premium venue
(define-public (grant-venue-access 
    (user principal)
    (venue-id uint)
    (expires-at (optional uint)))
  (let ((venue-info (unwrap! (map-get? venues venue-id) ERR_VENUE_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                  (is-eq tx-sender (get creator venue-info))) ERR_UNAUTHORIZED)
    
    (map-set user-access { user: user, venue-id: venue-id } {
      granted-at: stacks-block-height,
      expires-at: expires-at,
      granted-by: tx-sender
    })
    
    (ok true)
  )
)

;; Rate a venue after session completion
(define-public (rate-venue 
    (venue-id uint)
    (rating uint))
  (let ((venue-info (unwrap! (map-get? venues venue-id) ERR_VENUE_NOT_FOUND)))
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_PARAMETERS)
    (asserts! (has-used-venue tx-sender venue-id) ERR_UNAUTHORIZED)
    
    ;; Update venue rating
    (map-set venues venue-id 
      (merge venue-info {
        rating-sum: (+ (get rating-sum venue-info) rating),
        rating-count: (+ (get rating-count venue-info) u1)
      })
    )
    
    (ok true)
  )
)

;; Admin function to toggle venue active status
(define-public (toggle-venue-status (venue-id uint))
  (let ((venue-info (unwrap! (map-get? venues venue-id) ERR_VENUE_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                  (is-eq tx-sender (get creator venue-info))) ERR_UNAUTHORIZED)
    
    (map-set venues venue-id 
      (merge venue-info {
        is-active: (not (get is-active venue-info))
      })
    )
    
    (ok (not (get is-active venue-info)))
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

;; Get venue information
(define-read-only (get-venue (venue-id uint))
  (map-get? venues venue-id)
)

;; Get session information
(define-read-only (get-session (session-id uint))
  (map-get? performance-sessions session-id)
)

;; Get user session statistics
(define-read-only (get-user-stats (user principal))
  (map-get? user-sessions user)
)

;; Get venue statistics
(define-read-only (get-venue-statistics (venue-id uint))
  (map-get? venue-stats venue-id)
)

;; Calculate average venue rating
(define-read-only (get-venue-rating (venue-id uint))
  (match (map-get? venues venue-id)
    venue-info 
      (if (> (get rating-count venue-info) u0)
        (some (/ (get rating-sum venue-info) (get rating-count venue-info)))
        none
      )
    none
  )
)

;; Check if user has access to a venue
(define-read-only (check-venue-access (user principal) (venue-id uint))
  (match (map-get? venues venue-id)
    venue-info (has-venue-access user venue-id venue-info)
    false
  )
)

;; Get total number of venues
(define-read-only (get-venue-count)
  (var-get venue-counter)
)

;; Get total number of sessions
(define-read-only (get-session-count)
  (var-get session-counter)
)

;; Check if contract is paused
(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

;; private functions

;; Validate frequency response value
(define-private (check-frequency-value (value uint) (valid bool))
  (and valid (<= value MAX_ACOUSTIC_VALUE))
)

;; Check if user has access to venue based on access level
(define-private (has-venue-access (user principal) (venue-id uint) (venue-info (tuple (name (string-ascii 64)) (description (string-ascii 256)) (creator principal) (reverb-level uint) (echo-delay uint) (ambience-volume uint) (frequency-response (list 10 uint)) (access-level uint) (is-active bool) (created-at uint) (usage-count uint) (rating-sum uint) (rating-count uint))))
  (let ((access-level (get access-level venue-info)))
    (or 
      ;; Public venues are accessible to everyone
      (is-eq access-level ACCESS_PUBLIC)
      ;; Creator always has access
      (is-eq user (get creator venue-info))
      ;; Contract owner always has access
      (is-eq user CONTRACT_OWNER)
      ;; Check specific user access permissions
      (match (map-get? user-access { user: user, venue-id: venue-id })
        access-info
          (match (get expires-at access-info)
            expiry (< stacks-block-height expiry)
            true
          )
        false
      )
    )
  )
)

;; Update user session statistics
(define-private (update-user-sessions (user principal))
  (let ((current-stats (default-to 
                         { total-sessions: u0, total-practice-time: u0, 
                           favorite-venue: none, achievement-points: u0 }
                         (map-get? user-sessions user))))
    (map-set user-sessions user 
      (merge current-stats {
        total-sessions: (+ (get total-sessions current-stats) u1)
      })
    )
  )
)

;; Update venue usage statistics
(define-private (update-venue-usage (venue-id uint) (duration uint))
  (let ((current-stats (default-to 
                         { total-sessions: u0, total-duration: u0, 
                           unique-users: u0, peak-concurrent: u0, revenue-generated: u0 }
                         (map-get? venue-stats venue-id))))
    (map-set venue-stats venue-id 
      (merge current-stats {
        total-sessions: (+ (get total-sessions current-stats) u1),
        total-duration: (+ (get total-duration current-stats) duration)
      })
    )
  )
)

;; Award achievement points based on performance
(define-private (award-achievement-points (user principal) (score (optional uint)) (duration uint))
  (let ((current-stats (default-to 
                         { total-sessions: u0, total-practice-time: u0, 
                           favorite-venue: none, achievement-points: u0 }
                         (map-get? user-sessions user)))
        (base-points (/ duration u600)) ;; 1 point per 10 minutes
        (score-bonus (match score s (/ s u10) u0))
        (total-points (+ base-points score-bonus)))
    
    (map-set user-sessions user 
      (merge current-stats {
        total-practice-time: (+ (get total-practice-time current-stats) duration),
        achievement-points: (+ (get achievement-points current-stats) total-points)
      })
    )
  )
)

;; Check if user has used a venue (for rating eligibility)
(define-private (has-used-venue (user principal) (venue-id uint))
  (is-some (map-get? user-sessions user))
)
