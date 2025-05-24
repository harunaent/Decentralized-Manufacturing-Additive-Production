;; Material Certification Contract
;; Records and manages approved printing materials

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_MATERIAL_NOT_FOUND (err u201))
(define-constant ERR_ALREADY_CERTIFIED (err u202))
(define-constant ERR_INVALID_PROPERTIES (err u203))

;; Material certification data structure
(define-map materials
  { material-id: uint }
  {
    name: (string-ascii 64),
    type: (string-ascii 32),
    supplier: principal,
    batch-number: (string-ascii 32),
    properties: {
      melting-point: uint,
      density: uint,
      tensile-strength: uint,
      flexibility: uint
    },
    safety-rating: (string-ascii 16),
    certified: bool,
    certifier: (optional principal),
    expiry-block: uint,
    created-at: uint
  }
)

(define-data-var material-counter uint u0)

;; Register new material for certification
(define-public (register-material
  (name (string-ascii 64))
  (type (string-ascii 32))
  (batch-number (string-ascii 32))
  (properties { melting-point: uint, density: uint, tensile-strength: uint, flexibility: uint })
  (safety-rating (string-ascii 16))
  (validity-blocks uint))
  (let ((material-id (+ (var-get material-counter) u1)))
    (asserts! (and
      (> (get melting-point properties) u0)
      (> (get density properties) u0)
      (> (get tensile-strength properties) u0)
      (<= (get flexibility properties) u100)) ERR_INVALID_PROPERTIES)

    (map-set materials
      { material-id: material-id }
      {
        name: name,
        type: type,
        supplier: tx-sender,
        batch-number: batch-number,
        properties: properties,
        safety-rating: safety-rating,
        certified: false,
        certifier: none,
        expiry-block: (+ block-height validity-blocks),
        created-at: block-height
      })

    (var-set material-counter material-id)
    (ok material-id)))

;; Certify material
(define-public (certify-material (material-id uint))
  (let ((material (unwrap! (map-get? materials { material-id: material-id }) ERR_MATERIAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get certified material)) ERR_ALREADY_CERTIFIED)

    (map-set materials
      { material-id: material-id }
      (merge material { certified: true, certifier: (some tx-sender) }))

    (ok true)))

;; Get material details
(define-read-only (get-material (material-id uint))
  (map-get? materials { material-id: material-id }))

;; Check if material is certified and valid
(define-read-only (is-material-valid (material-id uint))
  (match (map-get? materials { material-id: material-id })
    material (and
      (get certified material)
      (> (get expiry-block material) block-height))
    false))

;; Get materials count
(define-read-only (get-material-count)
  (var-get material-counter))
