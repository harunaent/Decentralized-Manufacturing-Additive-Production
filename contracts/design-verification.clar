;; Design Verification Contract
;; Validates 3D printing specifications and design parameters

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_DESIGN_NOT_FOUND (err u101))
(define-constant ERR_INVALID_PARAMETERS (err u102))
(define-constant ERR_ALREADY_VERIFIED (err u103))

;; Design specification data structure
(define-map designs
  { design-id: uint }
  {
    creator: principal,
    name: (string-ascii 64),
    version: (string-ascii 16),
    file-hash: (string-ascii 64),
    dimensions: { x: uint, y: uint, z: uint },
    material-type: (string-ascii 32),
    layer-height: uint,
    infill-percentage: uint,
    print-temperature: uint,
    verified: bool,
    verifier: (optional principal),
    created-at: uint
  }
)

(define-data-var design-counter uint u0)

;; Submit new design for verification
(define-public (submit-design
  (name (string-ascii 64))
  (version (string-ascii 16))
  (file-hash (string-ascii 64))
  (dimensions { x: uint, y: uint, z: uint })
  (material-type (string-ascii 32))
  (layer-height uint)
  (infill-percentage uint)
  (print-temperature uint))
  (let ((design-id (+ (var-get design-counter) u1)))
    (asserts! (and
      (> (get x dimensions) u0)
      (> (get y dimensions) u0)
      (> (get z dimensions) u0)
      (<= infill-percentage u100)
      (> print-temperature u0)) ERR_INVALID_PARAMETERS)

    (map-set designs
      { design-id: design-id }
      {
        creator: tx-sender,
        name: name,
        version: version,
        file-hash: file-hash,
        dimensions: dimensions,
        material-type: material-type,
        layer-height: layer-height,
        infill-percentage: infill-percentage,
        print-temperature: print-temperature,
        verified: false,
        verifier: none,
        created-at: block-height
      })

    (var-set design-counter design-id)
    (ok design-id)))

;; Verify design specifications
(define-public (verify-design (design-id uint))
  (let ((design (unwrap! (map-get? designs { design-id: design-id }) ERR_DESIGN_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get verified design)) ERR_ALREADY_VERIFIED)

    (map-set designs
      { design-id: design-id }
      (merge design { verified: true, verifier: (some tx-sender) }))

    (ok true)))

;; Get design details
(define-read-only (get-design (design-id uint))
  (map-get? designs { design-id: design-id }))

;; Check if design is verified
(define-read-only (is-design-verified (design-id uint))
  (match (map-get? designs { design-id: design-id })
    design (get verified design)
    false))

;; Get total designs count
(define-read-only (get-design-count)
  (var-get design-counter))
