;; Data Provider Verification Contract
;; Validates and manages alternative credit data providers

(define-data-var contract-owner principal tx-sender)

;; Provider status constants
(define-constant PROVIDER_PENDING u0)
(define-constant PROVIDER_VERIFIED u1)
(define-constant PROVIDER_SUSPENDED u2)

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_PROVIDER_NOT_FOUND (err u1002))
(define-constant ERR_INVALID_STATUS (err u1003))

;; Data provider registry
(define-map providers
  principal
  {
    status: uint,
    reputation-score: uint,
    data-types: (list 10 (string-ascii 50)),
    verified-at: uint
  }
)

;; Provider application data
(define-map provider-applications
  principal
  {
    company-name: (string-ascii 100),
    data-sources: (list 5 (string-ascii 100)),
    applied-at: uint
  }
)

;; Register as a data provider
(define-public (apply-as-provider (company-name (string-ascii 100)) (data-sources (list 5 (string-ascii 100))))
  (begin
    (map-set provider-applications tx-sender {
      company-name: company-name,
      data-sources: data-sources,
      applied-at: block-height
    })
    (ok true)
  )
)

;; Verify a data provider (admin only)
(define-public (verify-provider (provider principal) (data-types (list 10 (string-ascii 50))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set providers provider {
      status: PROVIDER_VERIFIED,
      reputation-score: u100,
      data-types: data-types,
      verified-at: block-height
    })
    (ok true)
  )
)

;; Update provider reputation
(define-public (update-reputation (provider principal) (new-score uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (match (map-get? providers provider)
      provider-data (begin
        (map-set providers provider (merge provider-data { reputation-score: new-score }))
        (ok true)
      )
      ERR_PROVIDER_NOT_FOUND
    )
  )
)

;; Get provider info
(define-read-only (get-provider-info (provider principal))
  (map-get? providers provider)
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider principal))
  (match (map-get? providers provider)
    provider-data (is-eq (get status provider-data) PROVIDER_VERIFIED)
    false
  )
)
