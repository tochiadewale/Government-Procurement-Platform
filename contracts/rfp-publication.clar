;; RFP Publication Contract
;; Manages public procurement opportunities

(define-data-var last-rfp-id uint u0)
(define-data-var contract-owner principal tx-sender)

;; Define RFP data structure
(define-map rfps
  { rfp-id: uint }
  {
    title: (string-ascii 256),
    description: (string-ascii 1024),
    department: (string-ascii 128),
    budget: uint,
    deadline: uint,
    status: (string-ascii 20),
    created-by: principal,
    created-at: uint
  }
)

;; Define authorized entities
(define-map authorized-entities
  { entity: principal }
  { role: (string-ascii 20) }
)

;; Initialize contract owner as authorized
(map-set authorized-entities
  { entity: tx-sender }
  { role: "ADMIN" }
)

;; Publish a new RFP
(define-public (publish-rfp
    (title (string-ascii 256))
    (description (string-ascii 1024))
    (department (string-ascii 128))
    (budget uint)
    (deadline uint))
  (let
    ((new-id (+ (var-get last-rfp-id) u1)))

    ;; Only allow authorized government entities to publish RFPs
    (asserts! (is-authorized-entity tx-sender) (err u403))

    ;; Ensure deadline is in the future
    (asserts! (> deadline block-height) (err u400))

    ;; Update last RFP ID
    (var-set last-rfp-id new-id)

    ;; Store the RFP
    (map-set rfps
      { rfp-id: new-id }
      {
        title: title,
        description: description,
        department: department,
        budget: budget,
        deadline: deadline,
        status: "OPEN",
        created-by: tx-sender,
        created-at: block-height
      }
    )

    ;; Return the new RFP ID
    (ok new-id)
  )
)

;; Update RFP status (e.g., from OPEN to CLOSED)
(define-public (update-rfp-status (rfp-id uint) (new-status (string-ascii 20)))
  (let
    ((rfp (unwrap! (map-get? rfps { rfp-id: rfp-id }) (err u404))))

    ;; Only allow the creator or authorized admin to update
    (asserts! (or
                (is-eq tx-sender (get created-by rfp))
                (is-admin tx-sender))
              (err u403))

    ;; Update the status
    (map-set rfps
      { rfp-id: rfp-id }
      (merge rfp { status: new-status })
    )

    (ok true)
  )
)

;; Get RFP details
(define-read-only (get-rfp (rfp-id uint))
  (map-get? rfps { rfp-id: rfp-id })
)

;; Get the total number of RFPs
(define-read-only (get-rfp-count)
  (var-get last-rfp-id)
)

;; Helper functions for authorization
(define-read-only (is-authorized-entity (user principal))
  (is-some (map-get? authorized-entities { entity: user }))
)

(define-read-only (is-admin (user principal))
  (let ((role-data (default-to { role: "" } (map-get? authorized-entities { entity: user }))))
    (is-eq (get role role-data) "ADMIN")
  )
)

;; Add an authorized entity
(define-public (add-authorized-entity (entity principal) (role (string-ascii 20)))
  (begin
    ;; Only admin can add authorized entities
    (asserts! (is-admin tx-sender) (err u403))

    ;; Add entity
    (map-set authorized-entities
      { entity: entity }
      { role: role }
    )

    (ok true)
  )
)

;; Remove an authorized entity
(define-public (remove-authorized-entity (entity principal))
  (begin
    ;; Only admin can remove authorized entities
    (asserts! (is-admin tx-sender) (err u403))

    ;; Remove entity
    (map-delete authorized-entities { entity: entity })

    (ok true)
  )
)
