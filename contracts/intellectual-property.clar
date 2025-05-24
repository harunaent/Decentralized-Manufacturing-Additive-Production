;; Intellectual Property Contract
;; Manages design rights, licensing, and royalty distribution

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_IP_NOT_FOUND (err u501))
(define-constant ERR_LICENSE_EXPIRED (err u502))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u503))
(define-constant ERR_ALREADY_LICENSED (err u504))

;; IP registration data structure
(define-map ip-registry
  { ip-id: uint }
  {
    owner: principal,
    design-id: uint,
    title: (string-ascii 128),
    description: (string-ascii 256),
    license-type: (string-ascii 32),
    royalty-rate: uint,
    exclusive: bool,
    transferable: bool,
    registered-at: uint,
    expires-at: (optional uint)
  }
)

;; License agreements
(define-map licenses
  { license-id: uint }
  {
    ip-id: uint,
    licensee: principal,
    granted-by: principal,
    license-fee: uint,
    royalty-rate: uint,
    exclusive: bool,
    granted-at: uint,
    expires-at: uint,
    active: bool
  }
)

;; Royalty payments tracking
(define-map royalty-payments
  { payment-id: uint }
  {
    ip-id: uint,
    payer: principal,
    recipient: principal,
    amount: uint,
    job-id: uint,
    paid-at: uint
  }
)

(define-data-var ip-counter uint u0)
(define-data-var license-counter uint u0)
(define-data-var payment-counter uint u0)

;; Register intellectual property
(define-public (register-ip
  (design-id uint)
  (title (string-ascii 128))
  (description (string-ascii 256))
  (license-type (string-ascii 32))
  (royalty-rate uint)
  (exclusive bool)
  (transferable bool)
  (validity-blocks (optional uint)))
  (let ((ip-id (+ (var-get ip-counter) u1)))
    (asserts! (<= royalty-rate u10000) ERR_UNAUTHORIZED) ;; Max 100% (in basis points)

    (map-set ip-registry
      { ip-id: ip-id }
      {
        owner: tx-sender,
        design-id: design-id,
        title: title,
        description: description,
        license-type: license-type,
        royalty-rate: royalty-rate,
        exclusive: exclusive,
        transferable: transferable,
        registered-at: block-height,
        expires-at: (match validity-blocks
          blocks (some (+ block-height blocks))
          none)
      })

    (var-set ip-counter ip-id)
    (ok ip-id)))

;; Grant license
(define-public (grant-license
  (ip-id uint)
  (licensee principal)
  (license-fee uint)
  (exclusive bool)
  (duration-blocks uint))
  (let ((ip (unwrap! (map-get? ip-registry { ip-id: ip-id }) ERR_IP_NOT_FOUND))
        (license-id (+ (var-get license-counter) u1)))
    (asserts! (is-eq tx-sender (get owner ip)) ERR_UNAUTHORIZED)

    ;; Check if IP is still valid
    (match (get expires-at ip)
      expiry (asserts! (> expiry block-height) ERR_LICENSE_EXPIRED)
      true)

    (map-set licenses
      { license-id: license-id }
      {
        ip-id: ip-id,
        licensee: licensee,
        granted-by: tx-sender,
        license-fee: license-fee,
        royalty-rate: (get royalty-rate ip),
        exclusive: exclusive,
        granted-at: block-height,
        expires-at: (+ block-height duration-blocks),
        active: true
      })

    (var-set license-counter license-id)
    (ok license-id)))

;; Pay royalty
(define-public (pay-royalty (ip-id uint) (job-id uint) (amount uint))
  (let ((ip (unwrap! (map-get? ip-registry { ip-id: ip-id }) ERR_IP_NOT_FOUND))
        (payment-id (+ (var-get payment-counter) u1)))

    ;; Calculate royalty amount
    (let ((royalty-amount (/ (* amount (get royalty-rate ip)) u10000)))
      (asserts! (>= amount royalty-amount) ERR_INSUFFICIENT_PAYMENT)

      (map-set royalty-payments
        { payment-id: payment-id }
        {
          ip-id: ip-id,
          payer: tx-sender,
          recipient: (get owner ip),
          amount: royalty-amount,
          job-id: job-id,
          paid-at: block-height
        })

      (var-set payment-counter payment-id)
      (ok payment-id))))

;; Transfer IP ownership
(define-public (transfer-ip (ip-id uint) (new-owner principal))
  (let ((ip (unwrap! (map-get? ip-registry { ip-id: ip-id }) ERR_IP_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner ip)) ERR_UNAUTHORIZED)
    (asserts! (get transferable ip) ERR_UNAUTHORIZED)

    (map-set ip-registry
      { ip-id: ip-id }
      (merge ip { owner: new-owner }))

    (ok true)))

;; Get IP details
(define-read-only (get-ip (ip-id uint))
  (map-get? ip-registry { ip-id: ip-id }))

;; Get license details
(define-read-only (get-license (license-id uint))
  (map-get? licenses { license-id: license-id }))

;; Check if license is valid
(define-read-only (is-license-valid (license-id uint))
  (match (map-get? licenses { license-id: license-id })
    license (and
      (get active license)
      (> (get expires-at license) block-height))
    false))

;; Get total royalty payments for IP
(define-read-only (get-total-royalties (ip-id uint))
  ;; Simplified - in real implementation would iterate through payments
  u0)

;; Get counters
(define-read-only (get-ip-count)
  (var-get ip-counter))

(define-read-only (get-license-count)
  (var-get license-counter))

(define-read-only (get-payment-count)
  (var-get payment-counter))
