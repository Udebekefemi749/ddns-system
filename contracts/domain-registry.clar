;; Domain Registry Contract
;; Manages domain registration, ownership, renewal, and transfers

;; Error constants
(define-constant err-owner-only (err u100))
(define-constant err-domain-not-found (err u101))
(define-constant err-domain-exists (err u102))
(define-constant err-invalid-domain-length (err u103))
(define-constant err-domain-expired (err u104))
(define-constant err-insufficient-payment (err u105))
(define-constant err-transfer-not-authorized (err u106))
(define-constant err-invalid-expiration (err u107))
(define-constant err-invalid-characters (err u108))
(define-constant err-domain-locked (err u109))
(define-constant err-renewal-too-early (err u110))

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant min-domain-length u3)
(define-constant max-domain-length u63)
(define-constant max-registration-period u3650) ;; 10 years in days
(define-constant min-registration-period u30) ;; 30 days minimum
(define-constant base-registration-fee u1000000) ;; 1 STX in microSTX
(define-constant renewal-discount-rate u80) ;; 20% discount for renewals

;; Data structures
(define-map domains
  { domain-name: (string-ascii 63) }
  {
    owner: principal,
    registered-at: uint,
    expires-at: uint,
    last-updated: uint,
    transfer-locked: bool,
    metadata: (string-utf8 256)
  }
)

(define-map domain-transfer-requests
  { domain-name: (string-ascii 63) }
  {
    from-owner: principal,
    to-owner: principal,
    requested-at: uint,
    expires-at: uint
  }
)

(define-map user-domain-count
  { user: principal }
  { count: uint }
)

;; Contract variables
(define-data-var total-domains-registered uint u0)
(define-data-var base-fee uint base-registration-fee)
(define-data-var contract-paused bool false)

;; Helper functions
(define-private (is-valid-domain-name (domain-name (string-ascii 63)))
  (let ((name-length (len domain-name)))
    (and
      (>= name-length min-domain-length)
      (<= name-length max-domain-length)
      (is-valid-ascii-chars domain-name)
    )
  )
)

(define-private (is-valid-ascii-chars (domain-name (string-ascii 63)))
  ;; For simplicity, allowing alphanumeric and hyphens
  ;; In production, would implement proper ASCII validation
  true
)

(define-private (calculate-registration-fee (domain-name (string-ascii 63)) (registration-period uint))
  (let (
    (name-length (len domain-name))
    (length-multiplier (if (<= name-length u4) u5 
                       (if (<= name-length u6) u3 
                       (if (<= name-length u10) u2 u1))))
  )
    (* (* (var-get base-fee) length-multiplier) registration-period)
  )
)

(define-private (is-domain-expired (domain-name (string-ascii 63)))
  (match (map-get? domains { domain-name: domain-name })
    domain-info (> stacks-block-height (get expires-at domain-info))
    true
  )
)

(define-private (increment-user-domain-count (user principal))
  (let (
    (current-count (default-to u0 (get count (map-get? user-domain-count { user: user }))))
  )
    (map-set user-domain-count 
      { user: user }
      { count: (+ current-count u1) }
    )
  )
)

(define-private (decrement-user-domain-count (user principal))
  (let (
    (current-count (default-to u0 (get count (map-get? user-domain-count { user: user }))))
  )
    (if (> current-count u0)
      (map-set user-domain-count 
        { user: user }
        { count: (- current-count u1) }
      )
      true
    )
  )
)

;; Public functions
(define-public (register-domain (domain-name (string-ascii 63)) (registration-period uint) (metadata (string-utf8 256)))
  (let (
    (registration-fee (calculate-registration-fee domain-name registration-period))
    (expires-at (+ stacks-block-height registration-period))
  )
    ;; Validation checks
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-valid-domain-name domain-name) err-invalid-domain-length)
    (asserts! (>= registration-period min-registration-period) err-invalid-expiration)
    (asserts! (<= registration-period max-registration-period) err-invalid-expiration)
    (asserts! (is-none (map-get? domains { domain-name: domain-name })) err-domain-exists)
    
    ;; Process payment (simplified - in production would handle STX transfer)
    ;; (try! (stx-transfer? registration-fee tx-sender contract-owner))
    
    ;; Register the domain
    (map-set domains
      { domain-name: domain-name }
      {
        owner: tx-sender,
        registered-at: stacks-block-height,
        expires-at: expires-at,
        last-updated: stacks-block-height,
        transfer-locked: false,
        metadata: metadata
      }
    )
    
    ;; Update counters
    (increment-user-domain-count tx-sender)
    (var-set total-domains-registered (+ (var-get total-domains-registered) u1))
    
    (ok domain-name)
  )
)

(define-public (renew-domain (domain-name (string-ascii 63)) (additional-period uint))
  (let (
    (domain-info (unwrap! (map-get? domains { domain-name: domain-name }) err-domain-not-found))
    (renewal-fee (* (calculate-registration-fee domain-name additional-period) renewal-discount-rate))
    (new-expires-at (+ (get expires-at domain-info) additional-period))
  )
    ;; Validation checks
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq tx-sender (get owner domain-info)) err-owner-only)
    (asserts! (>= additional-period min-registration-period) err-invalid-expiration)
    (asserts! (<= additional-period max-registration-period) err-invalid-expiration)
    
    ;; Process payment (simplified)
    ;; (try! (stx-transfer? renewal-fee tx-sender contract-owner))
    
    ;; Update domain expiration
    (map-set domains
      { domain-name: domain-name }
      (merge domain-info {
        expires-at: new-expires-at,
        last-updated: stacks-block-height
      })
    )
    
    (ok new-expires-at)
  )
)

(define-public (transfer-domain (domain-name (string-ascii 63)) (new-owner principal))
  (let (
    (domain-info (unwrap! (map-get? domains { domain-name: domain-name }) err-domain-not-found))
  )
    ;; Validation checks
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq tx-sender (get owner domain-info)) err-owner-only)
    (asserts! (not (get transfer-locked domain-info)) err-domain-locked)
    (asserts! (not (is-domain-expired domain-name)) err-domain-expired)
    
    ;; Update domain ownership
    (map-set domains
      { domain-name: domain-name }
      (merge domain-info {
        owner: new-owner,
        last-updated: stacks-block-height
      })
    )
    
    ;; Update user domain counts
    (decrement-user-domain-count tx-sender)
    (increment-user-domain-count new-owner)
    
    (ok true)
  )
)

(define-public (request-domain-transfer (domain-name (string-ascii 63)) (to-owner principal))
  (let (
    (domain-info (unwrap! (map-get? domains { domain-name: domain-name }) err-domain-not-found))
    (transfer-expires-at (+ stacks-block-height u144)) ;; 24 hours
  )
    ;; Validation checks
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq tx-sender (get owner domain-info)) err-owner-only)
    (asserts! (not (is-domain-expired domain-name)) err-domain-expired)
    
    ;; Create transfer request
    (map-set domain-transfer-requests
      { domain-name: domain-name }
      {
        from-owner: tx-sender,
        to-owner: to-owner,
        requested-at: stacks-block-height,
        expires-at: transfer-expires-at
      }
    )
    
    (ok true)
  )
)

(define-public (accept-domain-transfer (domain-name (string-ascii 63)))
  (let (
    (transfer-request (unwrap! (map-get? domain-transfer-requests { domain-name: domain-name }) err-transfer-not-authorized))
    (domain-info (unwrap! (map-get? domains { domain-name: domain-name }) err-domain-not-found))
  )
    ;; Validation checks
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq tx-sender (get to-owner transfer-request)) err-transfer-not-authorized)
    (asserts! (<= stacks-block-height (get expires-at transfer-request)) err-transfer-not-authorized)
    (asserts! (not (is-domain-expired domain-name)) err-domain-expired)
    
    ;; Execute transfer
    (map-set domains
      { domain-name: domain-name }
      (merge domain-info {
        owner: tx-sender,
        last-updated: stacks-block-height
      })
    )
    
    ;; Update user domain counts
    (decrement-user-domain-count (get from-owner transfer-request))
    (increment-user-domain-count tx-sender)
    
    ;; Remove transfer request
    (map-delete domain-transfer-requests { domain-name: domain-name })
    
    (ok true)
  )
)

(define-public (update-domain-metadata (domain-name (string-ascii 63)) (new-metadata (string-utf8 256)))
  (let (
    (domain-info (unwrap! (map-get? domains { domain-name: domain-name }) err-domain-not-found))
  )
    ;; Validation checks
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq tx-sender (get owner domain-info)) err-owner-only)
    (asserts! (not (is-domain-expired domain-name)) err-domain-expired)
    
    ;; Update metadata
    (map-set domains
      { domain-name: domain-name }
      (merge domain-info {
        metadata: new-metadata,
        last-updated: stacks-block-height
      })
    )
    
    (ok true)
  )
)

(define-public (set-domain-lock (domain-name (string-ascii 63)) (locked bool))
  (let (
    (domain-info (unwrap! (map-get? domains { domain-name: domain-name }) err-domain-not-found))
  )
    ;; Validation checks
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq tx-sender (get owner domain-info)) err-owner-only)
    (asserts! (not (is-domain-expired domain-name)) err-domain-expired)
    
    ;; Update lock status
    (map-set domains
      { domain-name: domain-name }
      (merge domain-info {
        transfer-locked: locked,
        last-updated: stacks-block-height
      })
    )
    
    (ok locked)
  )
)

;; Read-only functions
(define-read-only (get-domain-info (domain-name (string-ascii 63)))
  (map-get? domains { domain-name: domain-name })
)

(define-read-only (is-domain-available (domain-name (string-ascii 63)))
  (or
    (is-none (map-get? domains { domain-name: domain-name }))
    (is-domain-expired domain-name)
  )
)

(define-read-only (get-domain-owner (domain-name (string-ascii 63)))
  (match (map-get? domains { domain-name: domain-name })
    domain-info (some (get owner domain-info))
    none
  )
)

(define-read-only (get-user-domain-count (user principal))
  (default-to u0 (get count (map-get? user-domain-count { user: user })))
)

(define-read-only (get-transfer-request (domain-name (string-ascii 63)))
  (map-get? domain-transfer-requests { domain-name: domain-name })
)

(define-read-only (get-registration-fee (domain-name (string-ascii 63)) (registration-period uint))
  (calculate-registration-fee domain-name registration-period)
)

(define-read-only (get-renewal-fee (domain-name (string-ascii 63)) (additional-period uint))
  (* (calculate-registration-fee domain-name additional-period) renewal-discount-rate)
)

(define-read-only (get-contract-stats)
  {
    total-domains: (var-get total-domains-registered),
    base-fee: (var-get base-fee),
    is-paused: (var-get contract-paused)
  }
)

;; Admin functions (only contract owner)
(define-public (set-base-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set base-fee new-fee)
    (ok true)
  )
)

(define-public (pause-contract (paused bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused paused)
    (ok paused)
  )
)


