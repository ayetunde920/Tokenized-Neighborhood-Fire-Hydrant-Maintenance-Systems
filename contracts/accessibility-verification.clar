;; Accessibility Verification Contract
;; Ensures hydrants remain unobstructed and visible

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_HYDRANT_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATUS (err u102))
(define-constant ERR_INSUFFICIENT_TOKENS (err u103))
(define-constant ERR_ALREADY_REPORTED (err u104))

;; Data Variables
(define-data-var total-hydrants uint u0)
(define-data-var total-reports uint u0)
(define-data-var verification-reward uint u10)

;; Data Maps
(define-map hydrants
  uint
  {
    location: (string-ascii 100),
    status: (string-ascii 20),
    last-verified: uint,
    verifier: principal,
    accessibility-score: uint
  }
)

(define-map user-tokens principal uint)

(define-map verification-reports
  uint
  {
    hydrant-id: uint,
    reporter: principal,
    issue-type: (string-ascii 50),
    timestamp: uint,
    resolved: bool
  }
)

(define-map user-report-count principal uint)

;; Public Functions

;; Register a new hydrant
(define-public (register-hydrant (location (string-ascii 100)))
  (let
    (
      (hydrant-id (+ (var-get total-hydrants) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set hydrants hydrant-id
      {
        location: location,
        status: "active",
        last-verified: block-height,
        verifier: tx-sender,
        accessibility-score: u100
      }
    )
    (var-set total-hydrants hydrant-id)
    (ok hydrant-id)
  )
)

;; Report accessibility issue
(define-public (report-accessibility-issue (hydrant-id uint) (issue-type (string-ascii 50)))
  (let
    (
      (report-id (+ (var-get total-reports) u1))
      (existing-hydrant (map-get? hydrants hydrant-id))
    )
    (asserts! (is-some existing-hydrant) ERR_HYDRANT_NOT_FOUND)
    (map-set verification-reports report-id
      {
        hydrant-id: hydrant-id,
        reporter: tx-sender,
        issue-type: issue-type,
        timestamp: block-height,
        resolved: false
      }
    )
    (map-set user-report-count tx-sender
      (+ (default-to u0 (map-get? user-report-count tx-sender)) u1)
    )
    (var-set total-reports report-id)
    (mint-tokens tx-sender (var-get verification-reward))
    (ok report-id)
  )
)

;; Verify hydrant accessibility
(define-public (verify-accessibility (hydrant-id uint) (new-status (string-ascii 20)))
  (let
    (
      (existing-hydrant (unwrap! (map-get? hydrants hydrant-id) ERR_HYDRANT_NOT_FOUND))
    )
    (asserts! (or (is-eq new-status "accessible") (is-eq new-status "obstructed") (is-eq new-status "damaged")) ERR_INVALID_STATUS)
    (map-set hydrants hydrant-id
      (merge existing-hydrant
        {
          status: new-status,
          last-verified: block-height,
          verifier: tx-sender,
          accessibility-score: (if (is-eq new-status "accessible") u100 u0)
        }
      )
    )
    (mint-tokens tx-sender (var-get verification-reward))
    (ok true)
  )
)

;; Resolve accessibility issue
(define-public (resolve-issue (report-id uint))
  (let
    (
      (existing-report (unwrap! (map-get? verification-reports report-id) ERR_HYDRANT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set verification-reports report-id
      (merge existing-report { resolved: true })
    )
    (mint-tokens (get reporter existing-report) (* (var-get verification-reward) u2))
    (ok true)
  )
)

;; Private Functions

;; Mint tokens for users
(define-private (mint-tokens (recipient principal) (amount uint))
  (begin
    (map-set user-tokens recipient
      (+ (default-to u0 (map-get? user-tokens recipient)) amount)
    )
    true
  )
)

;; Read-only Functions

;; Get hydrant details
(define-read-only (get-hydrant (hydrant-id uint))
  (map-get? hydrants hydrant-id)
)

;; Get user token balance
(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-tokens user))
)

;; Get verification report
(define-read-only (get-report (report-id uint))
  (map-get? verification-reports report-id)
)

;; Get total hydrants
(define-read-only (get-total-hydrants)
  (var-get total-hydrants)
)

;; Get user report count
(define-read-only (get-user-report-count (user principal))
  (default-to u0 (map-get? user-report-count user))
)
