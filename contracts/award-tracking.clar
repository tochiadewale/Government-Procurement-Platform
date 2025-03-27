;; Award Tracking Contract
;; Records contract recipients and payment milestones

(define-data-var contract-owner principal tx-sender)

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

;; Define award data structure
(define-map awards
  { rfp-id: uint }
  {
    winning-bid-id: uint,
    awarded-at: uint,
    awarded-by: principal,
    contract-amount: uint,
    contract-start: uint,
    contract-end: uint,
    status: (string-ascii 20)
  }
)

;; Define milestone data structure
(define-map milestones
  { milestone-id: uint }
  {
    rfp-id: uint,
    description: (string-ascii 256),
    amount: uint,
    due-date: uint,
    completed-at: uint,
    status: (string-ascii 20),
    verified-by: (optional principal)
  }
)

;; Index to track milestones by RFP
(define-map rfp-milestones
  { rfp-id: uint }
  { milestone-ids: (list 20 uint) }
)

;; Data var to track last milestone ID
(define-data-var last-milestone-id uint u0)

;; Award a contract to a winning bid
(define-public (award-contract
    (rfp-id uint)
    (winning-bid-id uint)
    (contract-start uint)
    (contract-end uint)
    (contract-amount uint))
  (begin
    ;; Only allow authorized personnel to award contracts
    (asserts! (is-authorized-entity tx-sender) (err u403))

    ;; Store the award
    (map-set awards
      { rfp-id: rfp-id }
      {
        winning-bid-id: winning-bid-id,
        awarded-at: block-height,
        awarded-by: tx-sender,
        contract-amount: contract-amount,
        contract-start: contract-start,
        contract-end: contract-end,
        status: "AWARDED"
      }
    )

    (ok true)
  )
)

;; Add a payment milestone to a contract
(define-public (add-milestone
    (rfp-id uint)
    (description (string-ascii 256))
    (amount uint)
    (due-date uint))
  (let
    ((new-id (+ (var-get last-milestone-id) u1))
     (award (unwrap! (map-get? awards { rfp-id: rfp-id }) (err u404)))
     (current-milestones (default-to { milestone-ids: (list) } (map-get? rfp-milestones { rfp-id: rfp-id }))))

    ;; Only allow authorized personnel to add milestones
    (asserts! (is-authorized-entity tx-sender) (err u403))

    ;; Ensure due date is before contract end
    (asserts! (<= due-date (get contract-end award)) (err u400))

    ;; Update last milestone ID
    (var-set last-milestone-id new-id)

    ;; Store the milestone
    (map-set milestones
      { milestone-id: new-id }
      {
        rfp-id: rfp-id,
        description: description,
        amount: amount,
        due-date: due-date,
        completed-at: u0,
        status: "PENDING",
        verified-by: none
      }
    )

    ;; Update the RFP-milestones index
    (map-set rfp-milestones
      { rfp-id: rfp-id }
      { milestone-ids: (unwrap! (as-max-len? (append (get milestone-ids current-milestones) new-id) u20) (err u500)) }
    )

    ;; Return the new milestone ID
    (ok new-id)
  )
)

;; Mark a milestone as completed
(define-public (complete-milestone (milestone-id uint))
  (let
    ((milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) (err u404))))

    ;; Update the milestone
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone {
        completed-at: block-height,
        status: "COMPLETED"
      })
    )

    (ok true)
  )
)

;; Verify a completed milestone
(define-public (verify-milestone (milestone-id uint))
  (let
    ((milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) (err u404))))

    ;; Only allow authorized personnel to verify milestones
    (asserts! (is-authorized-entity tx-sender) (err u403))

    ;; Ensure milestone is marked as completed
    (asserts! (is-eq (get status milestone) "COMPLETED") (err u400))

    ;; Update the milestone
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone {
        status: "VERIFIED",
        verified-by: (some tx-sender)
      })
    )

    (ok true)
  )
)

;; Get award details for an RFP
(define-read-only (get-award (rfp-id uint))
  (map-get? awards { rfp-id: rfp-id })
)

;; Get milestone details
(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones { milestone-id: milestone-id })
)

;; Get all milestones for an RFP
(define-read-only (get-milestones-for-rfp (rfp-id uint))
  (map-get? rfp-milestones { rfp-id: rfp-id })
)

;; Helper function to check if user is authorized
(define-read-only (is-authorized-entity (user principal))
  (is-some (map-get? authorized-entities { entity: user }))
)

;; Add an authorized entity
(define-public (add-authorized-entity (entity principal) (role (string-ascii 20)))
  (begin
    ;; Only contract owner can add authorized entities
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))

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
    ;; Only contract owner can remove authorized entities
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))

    ;; Remove entity
    (map-delete authorized-entities { entity: entity })

    (ok true)
  )
)
