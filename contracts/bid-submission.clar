;; Bid Submission Contract
;; Handles secure, time-stamped proposal submissions

(define-data-var last-bid-id uint u0)

;; Define bid data structure
(define-map bids
  { bid-id: uint }
  {
    rfp-id: uint,
    bidder: principal,
    amount: uint,
    proposal-hash: (buff 32), ;; Hash of the detailed proposal document
    submitted-at: uint,
    status: (string-ascii 20)
  }
)

;; Index to track bids by RFP
(define-map rfp-bids
  { rfp-id: uint }
  { bid-ids: (list 100 uint) }
)

;; Submit a bid for an RFP
(define-public (submit-bid
    (rfp-id uint)
    (amount uint)
    (proposal-hash (buff 32)))
  (let
    ((new-id (+ (var-get last-bid-id) u1))
     (current-bids (default-to { bid-ids: (list) } (map-get? rfp-bids { rfp-id: rfp-id }))))

    ;; Update last bid ID
    (var-set last-bid-id new-id)

    ;; Store the bid
    (map-set bids
      { bid-id: new-id }
      {
        rfp-id: rfp-id,
        bidder: tx-sender,
        amount: amount,
        proposal-hash: proposal-hash,
        submitted-at: block-height,
        status: "SUBMITTED"
      }
    )

    ;; Update the RFP-bids index
    (map-set rfp-bids
      { rfp-id: rfp-id }
      { bid-ids: (unwrap! (as-max-len? (append (get bid-ids current-bids) new-id) u100) (err u500)) }
    )

    ;; Return the new bid ID
    (ok new-id)
  )
)

;; Get bid details
(define-read-only (get-bid (bid-id uint))
  (map-get? bids { bid-id: bid-id })
)

;; Get all bids for an RFP
(define-read-only (get-bids-for-rfp (rfp-id uint))
  (map-get? rfp-bids { rfp-id: rfp-id })
)

;; Check if a bid can be modified (only before deadline)
(define-read-only (can-modify-bid (bid-id uint))
  (is-some (map-get? bids { bid-id: bid-id }))
)

;; Update a bid (only allowed before deadline)
(define-public (update-bid
    (bid-id uint)
    (amount uint)
    (proposal-hash (buff 32)))
  (let
    ((bid (unwrap! (map-get? bids { bid-id: bid-id }) (err u404))))

    ;; Only the original bidder can update
    (asserts! (is-eq tx-sender (get bidder bid)) (err u403))

    ;; Update the bid
    (map-set bids
      { bid-id: bid-id }
      (merge bid {
        amount: amount,
        proposal-hash: proposal-hash,
        submitted-at: block-height
      })
    )

    (ok true)
  )
)

;; Withdraw a bid (only allowed before deadline)
(define-public (withdraw-bid (bid-id uint))
  (let
    ((bid (unwrap! (map-get? bids { bid-id: bid-id }) (err u404))))

    ;; Only the original bidder can withdraw
    (asserts! (is-eq tx-sender (get bidder bid)) (err u403))

    ;; Update the bid status to WITHDRAWN
    (map-set bids
      { bid-id: bid-id }
      (merge bid { status: "WITHDRAWN" })
    )

    (ok true)
  )
)
