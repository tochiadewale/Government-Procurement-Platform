;; Evaluation Criteria Contract
;; Defines and applies objective assessment rules

(define-data-var contract-owner principal tx-sender)

;; Define evaluators
(define-map evaluators
  { evaluator: principal }
  { department: (string-ascii 128) }
)

;; Initialize contract owner as evaluator
(map-set evaluators
  { evaluator: tx-sender }
  { department: "ADMIN" }
)

;; Define criteria data structure
(define-map evaluation-criteria
  { rfp-id: uint }
  {
    technical-weight: uint,
    price-weight: uint,
    experience-weight: uint,
    timeline-weight: uint
  }
)

;; Define evaluation results
(define-map evaluation-results
  { bid-id: uint }
  {
    technical-score: uint,
    price-score: uint,
    experience-score: uint,
    timeline-score: uint,
    total-score: uint,
    evaluator: principal,
    evaluated-at: uint
  }
)

;; Set evaluation criteria for an RFP
(define-public (set-criteria
    (rfp-id uint)
    (technical-weight uint)
    (price-weight uint)
    (experience-weight uint)
    (timeline-weight uint))
  (begin
    ;; Only allow evaluators to set criteria
    (asserts! (is-evaluator tx-sender) (err u403))

    ;; Ensure weights add up to 100
    (asserts! (is-eq (+ (+ (+ technical-weight price-weight) experience-weight) timeline-weight) u100) (err u400))

    ;; Store the criteria
    (map-set evaluation-criteria
      { rfp-id: rfp-id }
      {
        technical-weight: technical-weight,
        price-weight: price-weight,
        experience-weight: experience-weight,
        timeline-weight: timeline-weight
      }
    )

    (ok true)
  )
)

;; Get evaluation criteria for an RFP
(define-read-only (get-criteria (rfp-id uint))
  (map-get? evaluation-criteria { rfp-id: rfp-id })
)

;; Evaluate a bid
(define-public (evaluate-bid
    (bid-id uint)
    (technical-score uint)
    (price-score uint)
    (experience-score uint)
    (timeline-score uint))
  (let
    ((criteria (unwrap! (map-get? evaluation-criteria { rfp-id: u1 }) (err u404))))

    ;; Only allow evaluators to submit scores
    (asserts! (is-evaluator tx-sender) (err u403))

    ;; Ensure scores are between 0 and 100
    (asserts! (and (<= technical-score u100) (<= price-score u100)
                  (<= experience-score u100) (<= timeline-score u100))
              (err u400))

    ;; Calculate weighted total score
    (let
      ((weighted-technical (* technical-score (get technical-weight criteria)))
       (weighted-price (* price-score (get price-weight criteria)))
       (weighted-experience (* experience-score (get experience-weight criteria)))
       (weighted-timeline (* timeline-score (get timeline-weight criteria)))
       (total-score (+ (+ (+ weighted-technical weighted-price)
                         weighted-experience)
                      weighted-timeline)))

      ;; Store the evaluation results
      (map-set evaluation-results
        { bid-id: bid-id }
        {
          technical-score: technical-score,
          price-score: price-score,
          experience-score: experience-score,
          timeline-score: timeline-score,
          total-score: total-score,
          evaluator: tx-sender,
          evaluated-at: block-height
        }
      )

      (ok total-score)
    )
  )
)

;; Get evaluation results for a bid
(define-read-only (get-evaluation (bid-id uint))
  (map-get? evaluation-results { bid-id: bid-id })
)

;; Helper function to check if user is an evaluator
(define-read-only (is-evaluator (user principal))
  (is-some (map-get? evaluators { evaluator: user }))
)

;; Add an evaluator
(define-public (add-evaluator (evaluator principal) (department (string-ascii 128)))
  (begin
    ;; Only contract owner can add evaluators
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))

    ;; Add evaluator
    (map-set evaluators
      { evaluator: evaluator }
      { department: department }
    )

    (ok true)
  )
)

;; Remove an evaluator
(define-public (remove-evaluator (evaluator principal))
  (begin
    ;; Only contract owner can remove evaluators
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))

    ;; Remove evaluator
    (map-delete evaluators { evaluator: evaluator })

    (ok true)
  )
)
