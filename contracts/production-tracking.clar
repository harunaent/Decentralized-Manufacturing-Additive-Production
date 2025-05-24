;; Production Tracking Contract
;; Monitors additive manufacturing process and job status

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_JOB_NOT_FOUND (err u301))
(define-constant ERR_INVALID_STATUS (err u302))
(define-constant ERR_INVALID_DESIGN (err u303))
(define-constant ERR_INVALID_MATERIAL (err u304))

;; Production job statuses
(define-constant STATUS_QUEUED u1)
(define-constant STATUS_PRINTING u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_FAILED u4)
(define-constant STATUS_CANCELLED u5)

;; Production job data structure
(define-map production-jobs
  { job-id: uint }
  {
    design-id: uint,
    material-id: uint,
    operator: principal,
    printer-id: (string-ascii 32),
    status: uint,
    start-block: (optional uint),
    end-block: (optional uint),
    estimated-duration: uint,
    actual-duration: (optional uint),
    layer-count: uint,
    current-layer: uint,
    failure-reason: (optional (string-ascii 128)),
    created-at: uint
  }
)

(define-data-var job-counter uint u0)

;; Create new production job
(define-public (create-job
  (design-id uint)
  (material-id uint)
  (printer-id (string-ascii 32))
  (estimated-duration uint)
  (layer-count uint))
  (let ((job-id (+ (var-get job-counter) u1)))
    ;; Validate design and material (simplified - in real implementation would call other contracts)
    (asserts! (> design-id u0) ERR_INVALID_DESIGN)
    (asserts! (> material-id u0) ERR_INVALID_MATERIAL)
    (asserts! (> layer-count u0) ERR_INVALID_STATUS)

    (map-set production-jobs
      { job-id: job-id }
      {
        design-id: design-id,
        material-id: material-id,
        operator: tx-sender,
        printer-id: printer-id,
        status: STATUS_QUEUED,
        start-block: none,
        end-block: none,
        estimated-duration: estimated-duration,
        actual-duration: none,
        layer-count: layer-count,
        current-layer: u0,
        failure-reason: none,
        created-at: block-height
      })

    (var-set job-counter job-id)
    (ok job-id)))

;; Start production job
(define-public (start-job (job-id uint))
  (let ((job (unwrap! (map-get? production-jobs { job-id: job-id }) ERR_JOB_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get operator job)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status job) STATUS_QUEUED) ERR_INVALID_STATUS)

    (map-set production-jobs
      { job-id: job-id }
      (merge job {
        status: STATUS_PRINTING,
        start-block: (some block-height)
      }))

    (ok true)))

;; Update job progress
(define-public (update-progress (job-id uint) (current-layer uint))
  (let ((job (unwrap! (map-get? production-jobs { job-id: job-id }) ERR_JOB_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get operator job)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status job) STATUS_PRINTING) ERR_INVALID_STATUS)
    (asserts! (<= current-layer (get layer-count job)) ERR_INVALID_STATUS)

    (map-set production-jobs
      { job-id: job-id }
      (merge job { current-layer: current-layer }))

    (ok true)))

;; Complete production job
(define-public (complete-job (job-id uint))
  (let ((job (unwrap! (map-get? production-jobs { job-id: job-id }) ERR_JOB_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get operator job)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status job) STATUS_PRINTING) ERR_INVALID_STATUS)

    (let ((duration (match (get start-block job)
      start-block (- block-height start-block)
      u0)))

      (map-set production-jobs
        { job-id: job-id }
        (merge job {
          status: STATUS_COMPLETED,
          end-block: (some block-height),
          actual-duration: (some duration),
          current-layer: (get layer-count job)
        }))

      (ok true))))

;; Fail production job
(define-public (fail-job (job-id uint) (reason (string-ascii 128)))
  (let ((job (unwrap! (map-get? production-jobs { job-id: job-id }) ERR_JOB_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get operator job)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status job) STATUS_PRINTING) ERR_INVALID_STATUS)

    (map-set production-jobs
      { job-id: job-id }
      (merge job {
        status: STATUS_FAILED,
        end-block: (some block-height),
        failure-reason: (some reason)
      }))

    (ok true)))

;; Get job details
(define-read-only (get-job (job-id uint))
  (map-get? production-jobs { job-id: job-id }))

;; Get job progress percentage
(define-read-only (get-job-progress (job-id uint))
  (match (map-get? production-jobs { job-id: job-id })
    job (if (> (get layer-count job) u0)
      (/ (* (get current-layer job) u100) (get layer-count job))
      u0)
    u0))

;; Get jobs count
(define-read-only (get-job-count)
  (var-get job-counter))
