;; Quality Verification Contract
;; Validates printed component specifications and quality metrics

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_COMPONENT_NOT_FOUND (err u401))
(define-constant ERR_ALREADY_VERIFIED (err u402))
(define-constant ERR_INVALID_MEASUREMENTS (err u403))
(define-constant ERR_JOB_NOT_COMPLETED (err u404))

;; Quality verification data structure
(define-map quality-reports
  { report-id: uint }
  {
    job-id: uint,
    inspector: principal,
    measurements: {
      actual-dimensions: { x: uint, y: uint, z: uint },
      weight: uint,
      surface-quality: uint,
      dimensional-accuracy: uint
    },
    defects: (list 5 (string-ascii 64)),
    passed: bool,
    verified: bool,
    verifier: (optional principal),
    notes: (string-ascii 256),
    created-at: uint
  }
)

(define-data-var report-counter uint u0)

;; Submit quality report
(define-public (submit-quality-report
  (job-id uint)
  (measurements { actual-dimensions: { x: uint, y: uint, z: uint }, weight: uint, surface-quality: uint, dimensional-accuracy: uint })
  (defects (list 5 (string-ascii 64)))
  (passed bool)
  (notes (string-ascii 256)))
  (let ((report-id (+ (var-get report-counter) u1)))
    ;; Validate measurements
    (asserts! (and
      (> (get x (get actual-dimensions measurements)) u0)
      (> (get y (get actual-dimensions measurements)) u0)
      (> (get z (get actual-dimensions measurements)) u0)
      (> (get weight measurements) u0)
      (<= (get surface-quality measurements) u100)
      (<= (get dimensional-accuracy measurements) u100)) ERR_INVALID_MEASUREMENTS)

    (map-set quality-reports
      { report-id: report-id }
      {
        job-id: job-id,
        inspector: tx-sender,
        measurements: measurements,
        defects: defects,
        passed: passed,
        verified: false,
        verifier: none,
        notes: notes,
        created-at: block-height
      })

    (var-set report-counter report-id)
    (ok report-id)))

;; Verify quality report
(define-public (verify-quality-report (report-id uint))
  (let ((report (unwrap! (map-get? quality-reports { report-id: report-id }) ERR_COMPONENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get verified report)) ERR_ALREADY_VERIFIED)

    (map-set quality-reports
      { report-id: report-id }
      (merge report { verified: true, verifier: (some tx-sender) }))

    (ok true)))

;; Get quality report
(define-read-only (get-quality-report (report-id uint))
  (map-get? quality-reports { report-id: report-id }))

;; Check if component passed quality check
(define-read-only (component-passed-quality (report-id uint))
  (match (map-get? quality-reports { report-id: report-id })
    report (and (get passed report) (get verified report))
    false))

;; Get quality score based on measurements
(define-read-only (get-quality-score (report-id uint))
  (match (map-get? quality-reports { report-id: report-id })
    report (let ((measurements (get measurements report)))
      (/ (+ (get surface-quality measurements) (get dimensional-accuracy measurements)) u2))
    u0))

;; Get reports count
(define-read-only (get-report-count)
  (var-get report-counter))
