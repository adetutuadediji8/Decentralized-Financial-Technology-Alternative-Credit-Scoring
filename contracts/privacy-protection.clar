;; Privacy Protection Contract
;; Protects credit data privacy and manages user consent

(define-data-var contract-owner principal tx-sender)

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u5001))
(define-constant ERR_CONSENT_REQUIRED (err u5002))
(define-constant ERR_CONSENT_EXPIRED (err u5003))
(define-constant ERR_INVALID_REQUEST (err u5004))

;; Consent types
(define-constant CONSENT_DATA_COLLECTION u1)
(define-constant CONSENT_SCORE_CALCULATION u2)
(define-constant CONSENT_LENDER_SHARING u3)

;; User consent registry
(define-map user-consents
  { user: principal, consent-type: uint }
  {
    granted: bool,
    granted-at: uint,
    expires-at: uint,
    purpose: (string-ascii 200)
  }
)

;; Data access logs
(define-map access-logs
  { accessor: principal, user: principal, timestamp: uint }
  {
    access-type: uint,
    purpose: (string-ascii 100),
    data-accessed: (list 5 uint)
  }
)

;; Privacy settings
(define-map privacy-settings
  principal
  {
    data-retention-days: uint,
    allow-score-sharing: bool,
    require-explicit-consent: bool
  }
)

;; Grant consent
(define-public (grant-consent (consent-type uint) (duration-days uint) (purpose (string-ascii 200)))
  (let (
    (expires-at (+ block-height (* duration-days u144))) ;; ~144 blocks per day
  )
    (map-set user-consents
      { user: tx-sender, consent-type: consent-type }
      {
        granted: true,
        granted-at: block-height,
        expires-at: expires-at,
        purpose: purpose
      }
    )
    (ok true)
  )
)

;; Revoke consent
(define-public (revoke-consent (consent-type uint))
  (begin
    (map-set user-consents
      { user: tx-sender, consent-type: consent-type }
      {
        granted: false,
        granted-at: block-height,
        expires-at: block-height,
        purpose: ""
      }
    )
    (ok true)
  )
)

;; Check if user has valid consent
(define-read-only (has-valid-consent (user principal) (consent-type uint))
  (match (map-get? user-consents { user: user, consent-type: consent-type })
    consent-data (and
      (get granted consent-data)
      (> (get expires-at consent-data) block-height)
    )
    false
  )
)

;; Log data access
(define-public (log-data-access
  (user principal)
  (access-type uint)
  (purpose (string-ascii 100))
  (data-accessed (list 5 uint)))
  (begin
    ;; Check consent before logging access
    (asserts! (has-valid-consent user access-type) ERR_CONSENT_REQUIRED)

    (map-set access-logs
      { accessor: tx-sender, user: user, timestamp: block-height }
      {
        access-type: access-type,
        purpose: purpose,
        data-accessed: data-accessed
      }
    )
    (ok true)
  )
)

;; Set privacy settings
(define-public (set-privacy-settings
  (retention-days uint)
  (allow-sharing bool)
  (require-explicit bool))
  (begin
    (map-set privacy-settings tx-sender {
      data-retention-days: retention-days,
      allow-score-sharing: allow-sharing,
      require-explicit-consent: require-explicit
    })
    (ok true)
  )
)

;; Get user's privacy settings
(define-read-only (get-privacy-settings (user principal))
  (default-to
    { data-retention-days: u365, allow-score-sharing: false, require-explicit-consent: true }
    (map-get? privacy-settings user)
  )
)

;; Get consent details
(define-read-only (get-consent-details (user principal) (consent-type uint))
  (map-get? user-consents { user: user, consent-type: consent-type })
)

;; Get access logs for user
(define-read-only (get-access-log (accessor principal) (user principal) (timestamp uint))
  (map-get? access-logs { accessor: accessor, user: user, timestamp: timestamp })
)
