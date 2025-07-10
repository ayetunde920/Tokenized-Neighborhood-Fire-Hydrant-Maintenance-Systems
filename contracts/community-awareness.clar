;; Community Awareness Contract
;; Educates residents about hydrant protection responsibilities

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_PROGRAM_NOT_FOUND (err u501))
(define-constant ERR_ALREADY_COMPLETED (err u502))
(define-constant ERR_INVALID_SCORE (err u503))
(define-constant ERR_PARTICIPANT_NOT_FOUND (err u504))

;; Data Variables
(define-data-var total-programs uint u0)
(define-data-var total-participants uint u0)
(define-data-var education-reward uint u5)
(define-data-var program-coordinator principal tx-sender)

;; Data Maps
(define-map educational-programs
  uint
  {
    program-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 200),
    duration: uint,
    completion-reward: uint,
    created-by: principal,
    active: bool
  }
)

(define-map participant-records
  principal
  {
    participant-id: uint,
    programs-completed: uint,
    total-score: uint,
    certification-level: (string-ascii 20),
    last-activity: uint,
    community-contributions: uint
  }
)

(define-map program-completions
  { participant: principal, program-id: uint }
  {
    completion-date: uint,
    score: uint,
    feedback: (string-ascii 200),
    certified: bool
  }
)

(define-map community-education-tokens principal uint)

(define-map awareness-campaigns
  uint
  {
    campaign-id: uint,
    title: (string-ascii 100),
    target-audience: (string-ascii 50),
    start-date: uint,
    end-date: uint,
    participation-count: uint,
    effectiveness-score: uint
  }
)

(define-map hydrant-adoption
  uint
  {
    hydrant-id: uint,
    adopter: principal,
    adoption-date: uint,
    maintenance-score: uint,
    community-impact: uint
  }
)

;; Public Functions

;; Register community participant
(define-public (register-participant)
  (let
    (
      (participant-id (+ (var-get total-participants) u1))
    )
    (map-set participant-records tx-sender
      {
        participant-id: participant-id,
        programs-completed: u0,
        total-score: u0,
        certification-level: "beginner",
        last-activity: block-height,
        community-contributions: u0
      }
    )
    (var-set total-participants participant-id)
    (mint-tokens tx-sender (var-get education-reward))
    (ok participant-id)
  )
)

;; Create educational program
(define-public (create-educational-program (title (string-ascii 100)) (description (string-ascii 200)) (duration uint) (reward uint))
  (let
    (
      (program-id (+ (var-get total-programs) u1))
    )
    (asserts! (is-eq tx-sender (var-get program-coordinator)) ERR_UNAUTHORIZED)
    (map-set educational-programs program-id
      {
        program-id: program-id,
        title: title,
        description: description,
        duration: duration,
        completion-reward: reward,
        created-by: tx-sender,
        active: true
      }
    )
    (var-set total-programs program-id)
    (ok program-id)
  )
)

;; Complete educational program
(define-public (complete-program (program-id uint) (score uint) (feedback (string-ascii 200)))
  (let
    (
      (existing-program (unwrap! (map-get? educational-programs program-id) ERR_PROGRAM_NOT_FOUND))
      (participant (unwrap! (map-get? participant-records tx-sender) ERR_PARTICIPANT_NOT_FOUND))
      (completion-key { participant: tx-sender, program-id: program-id })
    )
    (asserts! (is-none (map-get? program-completions completion-key)) ERR_ALREADY_COMPLETED)
    (asserts! (and (>= score u0) (<= score u100)) ERR_INVALID_SCORE)
    (asserts! (get active existing-program) ERR_PROGRAM_NOT_FOUND)

    (map-set program-completions completion-key
      {
        completion-date: block-height,
        score: score,
        feedback: feedback,
        certified: (>= score u80)
      }
    )

    (map-set participant-records tx-sender
      (merge participant
        {
          programs-completed: (+ (get programs-completed participant) u1),
          total-score: (+ (get total-score participant) score),
          last-activity: block-height,
          certification-level: (if (>= score u90) "expert" (if (>= score u70) "intermediate" "beginner"))
        }
      )
    )

    (mint-tokens tx-sender (get completion-reward existing-program))
    (ok true)
  )
)

;; Adopt hydrant for community care
(define-public (adopt-hydrant (hydrant-id uint))
  (let
    (
      (participant (unwrap! (map-get? participant-records tx-sender) ERR_PARTICIPANT_NOT_FOUND))
    )
    (map-set hydrant-adoption hydrant-id
      {
        hydrant-id: hydrant-id,
        adopter: tx-sender,
        adoption-date: block-height,
        maintenance-score: u0,
        community-impact: u0
      }
    )

    (map-set participant-records tx-sender
      (merge participant
        {
          community-contributions: (+ (get community-contributions participant) u1),
          last-activity: block-height
        }
      )
    )

    (mint-tokens tx-sender (* (var-get education-reward) u3))
    (ok true)
  )
)

;; Create awareness campaign
(define-public (create-awareness-campaign (title (string-ascii 100)) (target-audience (string-ascii 50)) (duration uint))
  (let
    (
      (campaign-id (+ (var-get total-programs) u1000))
    )
    (asserts! (is-eq tx-sender (var-get program-coordinator)) ERR_UNAUTHORIZED)
    (map-set awareness-campaigns campaign-id
      {
        campaign-id: campaign-id,
        title: title,
        target-audience: target-audience,
        start-date: block-height,
        end-date: (+ block-height duration),
        participation-count: u0,
        effectiveness-score: u0
      }
    )
    (ok campaign-id)
  )
)

;; Update community contribution
(define-public (update-community-contribution (participant principal) (contribution-points uint))
  (let
    (
      (existing-participant (unwrap! (map-get? participant-records participant) ERR_PARTICIPANT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (var-get program-coordinator)) ERR_UNAUTHORIZED)
    (map-set participant-records participant
      (merge existing-participant
        {
          community-contributions: (+ (get community-contributions existing-participant) contribution-points),
          last-activity: block-height
        }
      )
    )
    (mint-tokens participant (* (var-get education-reward) contribution-points))
    (ok true)
  )
)

;; Private Functions

;; Mint tokens for community participants
(define-private (mint-tokens (recipient principal) (amount uint))
  (begin
    (map-set community-education-tokens recipient
      (+ (default-to u0 (map-get? community-education-tokens recipient)) amount)
    )
    true
  )
)

;; Read-only Functions

;; Get educational program
(define-read-only (get-educational-program (program-id uint))
  (map-get? educational-programs program-id)
)

;; Get participant record
(define-read-only (get-participant-record (participant principal))
  (map-get? participant-records participant)
)

;; Get program completion
(define-read-only (get-program-completion (participant principal) (program-id uint))
  (map-get? program-completions { participant: participant, program-id: program-id })
)

;; Get community token balance
(define-read-only (get-community-balance (participant principal))
  (default-to u0 (map-get? community-education-tokens participant))
)

;; Get awareness campaign
(define-read-only (get-awareness-campaign (campaign-id uint))
  (map-get? awareness-campaigns campaign-id)
)

;; Get hydrant adoption info
(define-read-only (get-hydrant-adoption (hydrant-id uint))
  (map-get? hydrant-adoption hydrant-id)
)

;; Get total programs
(define-read-only (get-total-programs)
  (var-get total-programs)
)

;; Get total participants
(define-read-only (get-total-participants)
  (var-get total-participants)
)

;; Get program coordinator
(define-read-only (get-program-coordinator)
  (var-get program-coordinator)
)
