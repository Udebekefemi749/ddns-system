;; Domain Resolver Contract
;; Manages domain-to-address resolution and various DNS record types
;; Works in conjunction with domain-registry contract

;; Error constants
(define-constant err-domain-not-found (err u200))
(define-constant err-unauthorized (err u201))
(define-constant err-invalid-record-type (err u202))
(define-constant err-record-not-found (err u203))
(define-constant err-invalid-address (err u204))
(define-constant err-domain-expired (err u205))
(define-constant err-record-exists (err u206))
(define-constant err-invalid-ttl (err u207))
(define-constant err-contract-paused (err u208))

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant max-record-value-length u512)
(define-constant min-ttl u300) ;; 5 minutes
(define-constant max-ttl u86400) ;; 24 hours
(define-constant default-ttl u3600) ;; 1 hour

;; Record type constants
(define-constant RECORD_TYPE_A u1) ;; IPv4 address
(define-constant RECORD_TYPE_AAAA u2) ;; IPv6 address
(define-constant RECORD_TYPE_CNAME u3) ;; Canonical name
(define-constant RECORD_TYPE_TXT u4) ;; Text record
(define-constant RECORD_TYPE_MX u5) ;; Mail exchange
(define-constant RECORD_TYPE_NS u6) ;; Name server
(define-constant RECORD_TYPE_PTR u7) ;; Pointer record
(define-constant RECORD_TYPE_STX u8) ;; Stacks address

;; Contract state variables
(define-data-var contract-paused bool false)
(define-data-var total-records uint u0)
(define-data-var default-resolver principal tx-sender)

;; Main resolution mapping: domain -> record type -> record data
(define-map domain-records
  { domain-name: (string-ascii 63), record-type: uint }
  {
    value: (string-ascii 512),
    ttl: uint,
    created-at: uint,
    updated-at: uint,
    priority: (optional uint)
  }
)

;; Domain-specific resolver assignments
(define-map domain-resolvers
  { domain-name: (string-ascii 63) }
  { resolver: principal }
)

;; Record type metadata
(define-map record-type-info
  { record-type: uint }
  {
    name: (string-ascii 20),
    description: (string-ascii 100),
    active: bool
  }
)

;; Subdomain support
(define-map subdomain-records
  { domain-name: (string-ascii 63), subdomain: (string-ascii 63), record-type: uint }
  {
    value: (string-ascii 512),
    ttl: uint,
    created-at: uint,
    updated-at: uint
  }
)

;; Reverse DNS mapping (IP to domain)
(define-map reverse-dns
  { ip-address: (string-ascii 45) }
  {
    domain-name: (string-ascii 63),
    created-at: uint
  }
)

;; Domain statistics
(define-map domain-stats
  { domain-name: (string-ascii 63) }
  {
    total-records: uint,
    last-query: uint,
    query-count: uint
  }
)

;; Helper functions
(define-private (is-valid-record-type (record-type uint))
  (and (>= record-type u1) (<= record-type u8))
)

(define-private (is-valid-ttl (ttl uint))
  (and (>= ttl min-ttl) (<= ttl max-ttl))
)

(define-private (is-domain-owner (domain-name (string-ascii 63)) (caller principal))
  ;; In a real implementation, this would call the domain-registry contract
  ;; For this implementation, we'll use a simplified check
  true
)

(define-private (is-domain-expired (domain-name (string-ascii 63)))
  ;; In a real implementation, this would call the domain-registry contract
  ;; For this implementation, we'll assume domains don't expire
  false
)

(define-private (update-domain-stats (domain-name (string-ascii 63)))
  (let (
    (current-stats (default-to
      { total-records: u0, last-query: u0, query-count: u0 }
      (map-get? domain-stats { domain-name: domain-name })
    ))
  )
    (map-set domain-stats
      { domain-name: domain-name }
      (merge current-stats {
        last-query: stacks-block-height,
        query-count: (+ (get query-count current-stats) u1)
      })
    )
  )
)

(define-private (increment-record-count (domain-name (string-ascii 63)))
  (let (
    (current-stats (default-to
      { total-records: u0, last-query: u0, query-count: u0 }
      (map-get? domain-stats { domain-name: domain-name })
    ))
  )
    (map-set domain-stats
      { domain-name: domain-name }
      (merge current-stats {
        total-records: (+ (get total-records current-stats) u1)
      })
    )
  )
)

;; Initialize record types
(map-set record-type-info { record-type: RECORD_TYPE_A }
  { name: "A", description: "IPv4 address record", active: true })
(map-set record-type-info { record-type: RECORD_TYPE_AAAA }
  { name: "AAAA", description: "IPv6 address record", active: true })
(map-set record-type-info { record-type: RECORD_TYPE_CNAME }
  { name: "CNAME", description: "Canonical name record", active: true })
(map-set record-type-info { record-type: RECORD_TYPE_TXT }
  { name: "TXT", description: "Text record", active: true })
(map-set record-type-info { record-type: RECORD_TYPE_MX }
  { name: "MX", description: "Mail exchange record", active: true })
(map-set record-type-info { record-type: RECORD_TYPE_STX }
  { name: "STX", description: "Stacks address record", active: true })

;; Public functions for record management
(define-public (set-record
  (domain-name (string-ascii 63))
  (record-type uint)
  (value (string-ascii 512))
  (ttl uint)
  (priority (optional uint))
)
  (begin
    ;; Validation checks
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-valid-record-type record-type) err-invalid-record-type)
    (asserts! (is-valid-ttl ttl) err-invalid-ttl)
    (asserts! (is-domain-owner domain-name tx-sender) err-unauthorized)
    (asserts! (not (is-domain-expired domain-name)) err-domain-expired)
    (asserts! (> (len value) u0) err-invalid-address)
    
    ;; Set the record
    (map-set domain-records
      { domain-name: domain-name, record-type: record-type }
      {
        value: value,
        ttl: ttl,
        created-at: (default-to stacks-block-height 
          (get created-at (map-get? domain-records { domain-name: domain-name, record-type: record-type }))),
        updated-at: stacks-block-height,
        priority: priority
      }
    )
    
    ;; Update statistics
    (increment-record-count domain-name)
    (var-set total-records (+ (var-get total-records) u1))
    
    (ok true)
  )
)

(define-public (set-address-record (domain-name (string-ascii 63)) (ip-address (string-ascii 45)))
  (begin
    (try! (set-record domain-name RECORD_TYPE_A ip-address default-ttl none))
    
    ;; Also set reverse DNS
    (map-set reverse-dns
      { ip-address: ip-address }
      {
        domain-name: domain-name,
        created-at: stacks-block-height
      }
    )
    
    (ok true)
  )
)

(define-public (set-stx-address (domain-name (string-ascii 63)) (stx-address (string-ascii 512)))
  (set-record domain-name RECORD_TYPE_STX stx-address default-ttl none)
)

(define-public (set-text-record (domain-name (string-ascii 63)) (text-value (string-ascii 512)))
  (set-record domain-name RECORD_TYPE_TXT text-value default-ttl none)
)

(define-public (set-mx-record
  (domain-name (string-ascii 63))
  (mail-server (string-ascii 512))
  (priority uint)
)
  (set-record domain-name RECORD_TYPE_MX mail-server default-ttl (some priority))
)

(define-public (set-cname-record (domain-name (string-ascii 63)) (canonical-name (string-ascii 512)))
  (set-record domain-name RECORD_TYPE_CNAME canonical-name default-ttl none)
)

(define-public (delete-record (domain-name (string-ascii 63)) (record-type uint))
  (begin
    ;; Validation checks
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-valid-record-type record-type) err-invalid-record-type)
    (asserts! (is-domain-owner domain-name tx-sender) err-unauthorized)
    
    ;; Check if record exists
    (asserts! (is-some (map-get? domain-records { domain-name: domain-name, record-type: record-type }))
      err-record-not-found)
    
    ;; Delete the record
    (map-delete domain-records { domain-name: domain-name, record-type: record-type })
    
    (ok true)
  )
)

(define-public (set-subdomain-record
  (domain-name (string-ascii 63))
  (subdomain (string-ascii 63))
  (record-type uint)
  (value (string-ascii 512))
  (ttl uint)
)
  (begin
    ;; Validation checks
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-valid-record-type record-type) err-invalid-record-type)
    (asserts! (is-valid-ttl ttl) err-invalid-ttl)
    (asserts! (is-domain-owner domain-name tx-sender) err-unauthorized)
    (asserts! (> (len value) u0) err-invalid-address)
    
    ;; Set the subdomain record
    (map-set subdomain-records
      { domain-name: domain-name, subdomain: subdomain, record-type: record-type }
      {
        value: value,
        ttl: ttl,
        created-at: stacks-block-height,
        updated-at: stacks-block-height
      }
    )
    
    (ok true)
  )
)

(define-public (set-domain-resolver (domain-name (string-ascii 63)) (resolver principal))
  (begin
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-domain-owner domain-name tx-sender) err-unauthorized)
    
    (map-set domain-resolvers
      { domain-name: domain-name }
      { resolver: resolver }
    )
    
    (ok true)
  )
)

;; Read-only functions for domain resolution
(define-read-only (resolve-domain (domain-name (string-ascii 63)) (record-type uint))
  (map-get? domain-records { domain-name: domain-name, record-type: record-type })
)

(define-read-only (get-address (domain-name (string-ascii 63)))
  (match (resolve-domain domain-name RECORD_TYPE_A)
    record-info (some (get value record-info))
    none
  )
)

(define-read-only (get-stx-address (domain-name (string-ascii 63)))
  (match (resolve-domain domain-name RECORD_TYPE_STX)
    record-info (some (get value record-info))
    none
  )
)

(define-read-only (get-text-record (domain-name (string-ascii 63)))
  (match (resolve-domain domain-name RECORD_TYPE_TXT)
    record-info (some (get value record-info))
    none
  )
)

(define-read-only (get-mx-record (domain-name (string-ascii 63)))
  (resolve-domain domain-name RECORD_TYPE_MX)
)

(define-read-only (get-cname-record (domain-name (string-ascii 63)))
  (match (resolve-domain domain-name RECORD_TYPE_CNAME)
    record-info (some (get value record-info))
    none
  )
)

(define-read-only (resolve-subdomain
  (domain-name (string-ascii 63))
  (subdomain (string-ascii 63))
  (record-type uint)
)
  (map-get? subdomain-records {
    domain-name: domain-name,
    subdomain: subdomain,
    record-type: record-type
  })
)

(define-read-only (reverse-resolve (ip-address (string-ascii 45)))
  (map-get? reverse-dns { ip-address: ip-address })
)

(define-read-only (get-domain-resolver (domain-name (string-ascii 63)))
  (match (map-get? domain-resolvers { domain-name: domain-name })
    resolver-info (some (get resolver resolver-info))
    (some (var-get default-resolver))
  )
)

(define-read-only (get-all-records (domain-name (string-ascii 63)))
  {
    a-record: (resolve-domain domain-name RECORD_TYPE_A),
    aaaa-record: (resolve-domain domain-name RECORD_TYPE_AAAA),
    cname-record: (resolve-domain domain-name RECORD_TYPE_CNAME),
    txt-record: (resolve-domain domain-name RECORD_TYPE_TXT),
    mx-record: (resolve-domain domain-name RECORD_TYPE_MX),
    stx-record: (resolve-domain domain-name RECORD_TYPE_STX)
  }
)

(define-read-only (get-domain-stats (domain-name (string-ascii 63)))
  (map-get? domain-stats { domain-name: domain-name })
)

(define-read-only (get-record-type-info (record-type uint))
  (map-get? record-type-info { record-type: record-type })
)

(define-read-only (get-contract-stats)
  {
    total-records: (var-get total-records),
    default-resolver: (var-get default-resolver),
    is-paused: (var-get contract-paused)
  }
)

;; Utility functions
(define-read-only (is-record-expired (domain-name (string-ascii 63)) (record-type uint))
  (match (resolve-domain domain-name record-type)
    record-info
      (> stacks-block-height (+ (get updated-at record-info) (get ttl record-info)))
    true
  )
)

;; Admin functions (only contract owner)
(define-public (pause-contract (paused bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (var-set contract-paused paused)
    (ok paused)
  )
)

(define-public (set-default-resolver (new-resolver principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (var-set default-resolver new-resolver)
    (ok true)
  )
)

(define-public (add-record-type
  (record-type uint)
  (name (string-ascii 20))
  (description (string-ascii 100))
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (> record-type u8) err-invalid-record-type) ;; New types must be > 8
    
    (map-set record-type-info
      { record-type: record-type }
      {
        name: name,
        description: description,
        active: true
      }
    )
    
    (ok true)
  )
)

