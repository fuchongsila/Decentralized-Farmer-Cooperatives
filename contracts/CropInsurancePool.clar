;; Crop Insurance Pool Contract
;; Enables cooperative members to pool funds for crop insurance and file claims

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_ALREADY_EXISTS (err u202))
(define-constant ERR_INSUFFICIENT_FUNDS (err u203))
(define-constant ERR_CLAIM_PERIOD_ENDED (err u204))
(define-constant ERR_ALREADY_VOTED (err u205))
(define-constant ERR_NOT_MEMBER (err u206))
(define-constant ERR_INVALID_AMOUNT (err u207))
(define-constant ERR_CLAIM_NOT_APPROVED (err u208))

(define-data-var claim-id-counter uint u0)

;; Insurance pool data per cooperative
(define-map insurance-pools
  uint ;; coop-id
  {
    total-fund: uint,
    total-premiums-collected: uint,
    total-claims-paid: uint,
    active-claims: uint
  }
)

;; Individual member crop coverage
(define-map crop-coverage
  { coop-id: uint, member: principal }
  {
    coverage-amount: uint,
    premium-paid: uint,
    crop-type: (string-ascii 30),
    coverage-start: uint,
    coverage-end: uint,
    is-active: bool
  }
)

;; Insurance claims tracking
(define-map insurance-claims
  uint ;; claim-id
  {
    coop-id: uint,
    claimant: principal,
    claim-amount: uint,
    loss-type: (string-ascii 50),
    description: (string-ascii 200),
    evidence-hash: (string-ascii 64),
    claim-date: uint,
    voting-end: uint,
    yes-votes: uint,
    no-votes: uint,
    total-voting-power: uint,
    approved: bool,
    paid: bool,
    created-at: uint
  }
)

;; Track votes on insurance claims
(define-map claim-votes
  { claim-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

;; Contribute funds to cooperative insurance pool
(define-public (contribute-to-insurance (coop-id uint) (amount uint))
  (let
    (
      (pool-data (default-to 
        { total-fund: u0, total-premiums-collected: u0, total-claims-paid: u0, active-claims: u0 }
        (map-get? insurance-pools coop-id)
      ))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set insurance-pools coop-id
      (merge pool-data { total-fund: (+ (get total-fund pool-data) amount) })
    )
    (ok true)
  )
)

;; Register crop coverage for insurance
(define-public (register-crop-coverage 
  (coop-id uint) 
  (coverage-amount uint) 
  (crop-type (string-ascii 30))
  (coverage-months uint))
  (let
    (
      (current-block stacks-block-height)
      (coverage-end (+ current-block (* coverage-months u720))) ;; ~30 days per month
      (premium (/ coverage-amount u20)) ;; 5% premium rate
      (pool-data (unwrap! (map-get? insurance-pools coop-id) ERR_NOT_FOUND))
    )
    (asserts! (> coverage-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= coverage-amount u1000000) ERR_INVALID_AMOUNT) ;; Max 1M STX coverage
    
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    (map-set crop-coverage { coop-id: coop-id, member: tx-sender }
      {
        coverage-amount: coverage-amount,
        premium-paid: premium,
        crop-type: crop-type,
        coverage-start: current-block,
        coverage-end: coverage-end,
        is-active: true
      }
    )
    
    (map-set insurance-pools coop-id
      (merge pool-data 
        { 
          total-fund: (+ (get total-fund pool-data) premium),
          total-premiums-collected: (+ (get total-premiums-collected pool-data) premium)
        }
      )
    )
    (ok coverage-end)
  )
)

;; File an insurance claim for crop losses
(define-public (file-insurance-claim
  (coop-id uint)
  (claim-amount uint)
  (loss-type (string-ascii 50))
  (description (string-ascii 200))
  (evidence-hash (string-ascii 64)))
  (let
    (
      (coverage-data (unwrap! (map-get? crop-coverage { coop-id: coop-id, member: tx-sender }) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (new-claim-id (+ (var-get claim-id-counter) u1))
      (voting-end (+ current-block u144)) ;; 24 hours voting period
      (pool-data (unwrap! (map-get? insurance-pools coop-id) ERR_NOT_FOUND))
    )
    (asserts! (get is-active coverage-data) ERR_NOT_FOUND)
    (asserts! (< current-block (get coverage-end coverage-data)) ERR_CLAIM_PERIOD_ENDED)
    (asserts! (<= claim-amount (get coverage-amount coverage-data)) ERR_INVALID_AMOUNT)
    (asserts! (> claim-amount u0) ERR_INVALID_AMOUNT)
    
    (map-set insurance-claims new-claim-id
      {
        coop-id: coop-id,
        claimant: tx-sender,
        claim-amount: claim-amount,
        loss-type: loss-type,
        description: description,
        evidence-hash: evidence-hash,
        claim-date: current-block,
        voting-end: voting-end,
        yes-votes: u0,
        no-votes: u0,
        total-voting-power: u0,
        approved: false,
        paid: false,
        created-at: current-block
      }
    )
    
    (map-set insurance-pools coop-id
      (merge pool-data { active-claims: (+ (get active-claims pool-data) u1) })
    )
    
    (var-set claim-id-counter new-claim-id)
    (ok new-claim-id)
  )
)

;; Vote on insurance claim validity
(define-public (vote-on-claim (claim-id uint) (vote bool))
  (let
    (
      (claim-data (unwrap! (map-get? insurance-claims claim-id) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (existing-vote (map-get? claim-votes { claim-id: claim-id, voter: tx-sender }))
    )
    (asserts! (< current-block (get voting-end claim-data)) ERR_CLAIM_PERIOD_ENDED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (not (is-eq tx-sender (get claimant claim-data))) ERR_UNAUTHORIZED)
    
    ;; Use simple voting power of 1 per member for insurance claims
    (let ((voting-power u1))
      (map-set claim-votes { claim-id: claim-id, voter: tx-sender }
        { vote: vote, voting-power: voting-power }
      )
      (map-set insurance-claims claim-id
        (merge claim-data
          {
            yes-votes: (if vote (+ (get yes-votes claim-data) voting-power) (get yes-votes claim-data)),
            no-votes: (if vote (get no-votes claim-data) (+ (get no-votes claim-data) voting-power)),
            total-voting-power: (+ (get total-voting-power claim-data) voting-power)
          }
        )
      )
    )
    (ok true)
  )
)

;; Execute approved insurance claim payout
(define-public (execute-claim-payout (claim-id uint))
  (let
    (
      (claim-data (unwrap! (map-get? insurance-claims claim-id) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (pool-data (unwrap! (map-get? insurance-pools (get coop-id claim-data)) ERR_NOT_FOUND))
    )
    (asserts! (>= current-block (get voting-end claim-data)) ERR_CLAIM_PERIOD_ENDED)
    (asserts! (not (get paid claim-data)) ERR_ALREADY_EXISTS)
    (asserts! (> (get yes-votes claim-data) (get no-votes claim-data)) ERR_CLAIM_NOT_APPROVED)
    (asserts! (>= (get total-voting-power claim-data) u2) ERR_UNAUTHORIZED) ;; Minimum 2 votes required
    (asserts! (>= (get total-fund pool-data) (get claim-amount claim-data)) ERR_INSUFFICIENT_FUNDS)
    
    (try! (as-contract (stx-transfer? (get claim-amount claim-data) tx-sender (get claimant claim-data))))
    
    (map-set insurance-claims claim-id
      (merge claim-data { approved: true, paid: true })
    )
    
    (map-set insurance-pools (get coop-id claim-data)
      (merge pool-data 
        {
          total-fund: (- (get total-fund pool-data) (get claim-amount claim-data)),
          total-claims-paid: (+ (get total-claims-paid pool-data) (get claim-amount claim-data)),
          active-claims: (- (get active-claims pool-data) u1)
        }
      )
    )
    (ok (get claim-amount claim-data))
  )
)

;; Read-only functions
(define-read-only (get-insurance-pool (coop-id uint))
  (map-get? insurance-pools coop-id)
)

(define-read-only (get-member-coverage (coop-id uint) (member principal))
  (map-get? crop-coverage { coop-id: coop-id, member: member })
)

(define-read-only (get-insurance-claim (claim-id uint))
  (map-get? insurance-claims claim-id)
)

(define-read-only (get-claim-vote (claim-id uint) (voter principal))
  (map-get? claim-votes { claim-id: claim-id, voter: voter })
)

(define-read-only (calculate-premium (coverage-amount uint))
  (/ coverage-amount u20) ;; 5% premium rate
)