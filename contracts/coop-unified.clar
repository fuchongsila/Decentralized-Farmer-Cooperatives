(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_VOTING_CLOSED (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_NOT_MEMBER (err u106))
(define-constant ERR_INVALID_AMOUNT (err u107))
(define-constant ERR_CLAIM_PERIOD_ENDED (err u204))
(define-constant ERR_CLAIM_NOT_APPROVED (err u208))
(define-constant ERR_REP_NOT_FOUND (err u209))
(define-constant ERR_INVALID_SCORE (err u210))

(define-data-var coop-id-counter uint u0)
(define-data-var proposal-id-counter uint u0)
(define-data-var claim-id-counter uint u0)

(define-map cooperatives
  uint
  {
    name: (string-ascii 50),
    founder: principal,
    total-members: uint,
    total-resources: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map coop-members
  { coop-id: uint, member: principal }
  {
    shares: uint,
    joined-at: uint,
    resources-contributed: uint,
    is-active: bool
  }
)

(define-map coop-resources
  uint
  {
    available-funds: uint,
    equipment-value: uint,
    land-size: uint
  }
)

(define-map proposals
  uint
  {
    coop-id: uint,
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    proposal-type: (string-ascii 20),
    voting-end: uint,
    yes-votes: uint,
    no-votes: uint,
    total-votes: uint,
    executed: bool,
    created-at: uint
  }
)

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

(define-map profit-distribution
  { coop-id: uint, member: principal }
  { total-earned: uint, last-claim: uint }
)

(define-map insurance-pools
  uint
  {
    total-fund: uint,
    total-premiums-collected: uint,
    total-claims-paid: uint,
    active-claims: uint
  }
)

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

(define-map insurance-claims
  uint
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

(define-map claim-votes
  { claim-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

;; Farmer Reputation and Reliability Scoring System
;; Tracks farmer performance metrics including completed tasks, reliability score, and participation history
(define-map farmer-reputation
  principal
  {
    reliability-score: uint,
    tasks-completed: uint,
    tasks-failed: uint,
    last-updated: uint,
    participation-count: uint
  }
)

(define-map farmer-ratings
  { rater: principal, rated: principal }
  {
    rating: uint,
    comment: (string-ascii 200),
    timestamp: uint
  }
)

(define-public (create-cooperative (name (string-ascii 50)))
  (let
    (
      (new-id (+ (var-get coop-id-counter) u1))
      (current-block stacks-block-height)
    )
    (map-set cooperatives new-id
      {
        name: name,
        founder: tx-sender,
        total-members: u1,
        total-resources: u0,
        created-at: current-block,
        is-active: true
      }
    )
    (map-set coop-members { coop-id: new-id, member: tx-sender }
      {
        shares: u100,
        joined-at: current-block,
        resources-contributed: u0,
        is-active: true
      }
    )
    (map-set coop-resources new-id
      {
        available-funds: u0,
        equipment-value: u0,
        land-size: u0
      }
    )
    (var-set coop-id-counter new-id)
    (ok new-id)
  )
)

(define-public (join-cooperative (coop-id uint) (initial-contribution uint))
  (let
    (
      (coop-data (unwrap! (map-get? cooperatives coop-id) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (member-exists (map-get? coop-members { coop-id: coop-id, member: tx-sender }))
    )
    (asserts! (get is-active coop-data) ERR_NOT_FOUND)
    (asserts! (is-none member-exists) ERR_ALREADY_EXISTS)
    (asserts! (> initial-contribution u0) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? initial-contribution tx-sender (as-contract tx-sender)))
    
    (map-set coop-members { coop-id: coop-id, member: tx-sender }
      {
        shares: u50,
        joined-at: current-block,
        resources-contributed: initial-contribution,
        is-active: true
      }
    )
    (map-set cooperatives coop-id
      (merge coop-data { total-members: (+ (get total-members coop-data) u1) })
    )
    (let
      ((resources (unwrap! (map-get? coop-resources coop-id) ERR_NOT_FOUND)))
      (map-set coop-resources coop-id
        (merge resources { available-funds: (+ (get available-funds resources) initial-contribution) })
      )
    )
    (ok true)
  )
)

(define-public (contribute-resources (coop-id uint) (amount uint) (resource-type (string-ascii 20)))
  (let
    (
      (member-data (unwrap! (map-get? coop-members { coop-id: coop-id, member: tx-sender }) ERR_NOT_MEMBER))
      (resources (unwrap! (map-get? coop-resources coop-id) ERR_NOT_FOUND))
    )
    (asserts! (get is-active member-data) ERR_NOT_MEMBER)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (if (is-eq resource-type "funds")
      (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set coop-resources coop-id
          (merge resources { available-funds: (+ (get available-funds resources) amount) })
        )
      )
      (if (is-eq resource-type "equipment")
        (map-set coop-resources coop-id
          (merge resources { equipment-value: (+ (get equipment-value resources) amount) })
        )
        (map-set coop-resources coop-id
          (merge resources { land-size: (+ (get land-size resources) amount) })
        )
      )
    )
    
    (map-set coop-members { coop-id: coop-id, member: tx-sender }
      (merge member-data 
        { 
          resources-contributed: (+ (get resources-contributed member-data) amount),
          shares: (+ (get shares member-data) (/ amount u10))
        }
      )
    )
    (ok true)
  )
)

(define-public (create-proposal (coop-id uint) (title (string-ascii 100)) (description (string-ascii 500)) (amount uint) (proposal-type (string-ascii 20)))
  (let
    (
      (member-data (unwrap! (map-get? coop-members { coop-id: coop-id, member: tx-sender }) ERR_NOT_MEMBER))
      (new-proposal-id (+ (var-get proposal-id-counter) u1))
      (current-block stacks-block-height)
      (voting-end (+ current-block u144))
    )
    (asserts! (get is-active member-data) ERR_NOT_MEMBER)
    
    (map-set proposals new-proposal-id
      {
        coop-id: coop-id,
        proposer: tx-sender,
        title: title,
        description: description,
        amount: amount,
        proposal-type: proposal-type,
        voting-end: voting-end,
        yes-votes: u0,
        no-votes: u0,
        total-votes: u0,
        executed: false,
        created-at: current-block
      }
    )
    (var-set proposal-id-counter new-proposal-id)
    (ok new-proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let
    (
      (proposal-data (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND))
      (member-data (unwrap! (map-get? coop-members { coop-id: (get coop-id proposal-data), member: tx-sender }) ERR_NOT_MEMBER))
      (current-block stacks-block-height)
      (existing-vote (map-get? proposal-votes { proposal-id: proposal-id, voter: tx-sender }))
    )
    (asserts! (get is-active member-data) ERR_NOT_MEMBER)
    (asserts! (< current-block (get voting-end proposal-data)) ERR_VOTING_CLOSED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    
    (let ((voting-power (get shares member-data)))
      (map-set proposal-votes { proposal-id: proposal-id, voter: tx-sender }
        { vote: vote, voting-power: voting-power }
      )
      (map-set proposals proposal-id
        (merge proposal-data
          {
            yes-votes: (if vote (+ (get yes-votes proposal-data) voting-power) (get yes-votes proposal-data)),
            no-votes: (if vote (get no-votes proposal-data) (+ (get no-votes proposal-data) voting-power)),
            total-votes: (+ (get total-votes proposal-data) voting-power)
          }
        )
      )
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal-data (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (resources (unwrap! (map-get? coop-resources (get coop-id proposal-data)) ERR_NOT_FOUND))
    )
    (asserts! (>= current-block (get voting-end proposal-data)) ERR_VOTING_CLOSED)
    (asserts! (not (get executed proposal-data)) ERR_ALREADY_EXISTS)
    (asserts! (> (get yes-votes proposal-data) (get no-votes proposal-data)) ERR_UNAUTHORIZED)
    
    (if (is-eq (get proposal-type proposal-data) "funding")
      (begin
        (asserts! (>= (get available-funds resources) (get amount proposal-data)) ERR_INSUFFICIENT_FUNDS)
        (try! (as-contract (stx-transfer? (get amount proposal-data) tx-sender (get proposer proposal-data))))
        (map-set coop-resources (get coop-id proposal-data)
          (merge resources { available-funds: (- (get available-funds resources) (get amount proposal-data)) })
        )
      )
      true
    )
    
    (map-set proposals proposal-id
      (merge proposal-data { executed: true })
    )
    (ok true)
  )
)

(define-public (distribute-profits (coop-id uint) (total-profit uint))
  (let
    (
      (coop-data (unwrap! (map-get? cooperatives coop-id) ERR_NOT_FOUND))
      (member-data (unwrap! (map-get? coop-members { coop-id: coop-id, member: tx-sender }) ERR_NOT_MEMBER))
    )
    (asserts! (is-eq tx-sender (get founder coop-data)) ERR_UNAUTHORIZED)
    (asserts! (> total-profit u0) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? total-profit tx-sender (as-contract tx-sender)))
    
    (let ((resources (unwrap! (map-get? coop-resources coop-id) ERR_NOT_FOUND)))
      (map-set coop-resources coop-id
        (merge resources { available-funds: (+ (get available-funds resources) total-profit) })
      )
    )
    (ok true)
  )
)

(define-public (claim-profit-share (coop-id uint))
  (let
    (
      (member-data (unwrap! (map-get? coop-members { coop-id: coop-id, member: tx-sender }) ERR_NOT_MEMBER))
      (coop-data (unwrap! (map-get? cooperatives coop-id) ERR_NOT_FOUND))
      (resources (unwrap! (map-get? coop-resources coop-id) ERR_NOT_FOUND))
      (total-shares (get-total-shares coop-id))
      (member-share-ratio (/ (* (get shares member-data) u100) total-shares))
      (available-for-distribution (/ (get available-funds resources) u2))
      (member-earning (/ (* available-for-distribution member-share-ratio) u100))
    )
    (asserts! (get is-active member-data) ERR_NOT_MEMBER)
    (asserts! (> member-earning u0) ERR_INSUFFICIENT_FUNDS)
    
    (try! (as-contract (stx-transfer? member-earning tx-sender tx-sender)))
    
    (map-set coop-resources coop-id
      (merge resources { available-funds: (- (get available-funds resources) member-earning) })
    )
    
    (let ((distribution-data (default-to { total-earned: u0, last-claim: u0 } 
                             (map-get? profit-distribution { coop-id: coop-id, member: tx-sender }))))
      (map-set profit-distribution { coop-id: coop-id, member: tx-sender }
        {
          total-earned: (+ (get total-earned distribution-data) member-earning),
          last-claim: stacks-block-height
        }
      )
    )
    (ok member-earning)
  )
)

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

(define-public (register-crop-coverage 
  (coop-id uint) 
  (coverage-amount uint) 
  (crop-type (string-ascii 30))
  (coverage-months uint))
  (let
    (
      (current-block stacks-block-height)
      (coverage-end (+ current-block (* coverage-months u720)))
      (premium (/ coverage-amount u20))
      (pool-data (unwrap! (map-get? insurance-pools coop-id) ERR_NOT_FOUND))
    )
    (asserts! (> coverage-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= coverage-amount u1000000) ERR_INVALID_AMOUNT)
    
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
      (voting-end (+ current-block u144))
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
    (asserts! (>= (get total-voting-power claim-data) u2) ERR_UNAUTHORIZED)
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

(define-read-only (get-cooperative (coop-id uint))
  (map-get? cooperatives coop-id)
)

(define-read-only (get-member-info (coop-id uint) (member principal))
  (map-get? coop-members { coop-id: coop-id, member: member })
)

(define-read-only (get-coop-resources (coop-id uint))
  (map-get? coop-resources coop-id)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-profit-distribution (coop-id uint) (member principal))
  (map-get? profit-distribution { coop-id: coop-id, member: member })
)

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
  (/ coverage-amount u20)
)

;; Record a completed task for a farmer, increasing their reliability score
;; Callable only by cooperative founders or authorized members
(define-public (record-task-completion (farmer principal) (coop-id uint))
  (let
    (
      (coop-data (unwrap! (map-get? cooperatives coop-id) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (rep-data (default-to 
        { reliability-score: u50, tasks-completed: u0, tasks-failed: u0, last-updated: current-block, participation-count: u0 }
        (map-get? farmer-reputation farmer)
      ))
    )
    (asserts! (is-eq tx-sender (get founder coop-data)) ERR_UNAUTHORIZED)
    
    (map-set farmer-reputation farmer
      {
        reliability-score: (+ (get reliability-score rep-data) u5),
        tasks-completed: (+ (get tasks-completed rep-data) u1),
        tasks-failed: (get tasks-failed rep-data),
        last-updated: current-block,
        participation-count: (+ (get participation-count rep-data) u1)
      }
    )
    (ok true)
  )
)

;; Record a failed or incomplete task for a farmer, decreasing their reliability score
(define-public (record-task-failure (farmer principal) (coop-id uint))
  (let
    (
      (coop-data (unwrap! (map-get? cooperatives coop-id) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (rep-data (default-to 
        { reliability-score: u50, tasks-completed: u0, tasks-failed: u0, last-updated: current-block, participation-count: u0 }
        (map-get? farmer-reputation farmer)
      ))
      (new-score (if (>= (get reliability-score rep-data) u3) (- (get reliability-score rep-data) u3) u0))
    )
    (asserts! (is-eq tx-sender (get founder coop-data)) ERR_UNAUTHORIZED)
    
    (map-set farmer-reputation farmer
      {
        reliability-score: new-score,
        tasks-completed: (get tasks-completed rep-data),
        tasks-failed: (+ (get tasks-failed rep-data) u1),
        last-updated: current-block,
        participation-count: (+ (get participation-count rep-data) u1)
      }
    )
    (ok true)
  )
)

;; Submit a rating for another farmer (1-10 scale)
;; Only cooperative members can rate each other
(define-public (submit-farmer-rating (rated-farmer principal) (rating uint) (comment (string-ascii 200)) (coop-id uint))
  (let
    (
      (member-data (unwrap! (map-get? coop-members { coop-id: coop-id, member: tx-sender }) ERR_NOT_MEMBER))
      (current-block stacks-block-height)
    )
    (asserts! (get is-active member-data) ERR_NOT_MEMBER)
    (asserts! (and (>= rating u1) (<= rating u10)) ERR_INVALID_SCORE)
    (asserts! (not (is-eq tx-sender rated-farmer)) ERR_UNAUTHORIZED)
    
    (map-set farmer-ratings { rater: tx-sender, rated: rated-farmer }
      {
        rating: rating,
        comment: comment,
        timestamp: current-block
      }
    )
    (ok true)
  )
)

;; Initialize or reset a farmer's reputation profile
(define-public (initialize-farmer-reputation (farmer principal))
  (let
    (
      (current-block stacks-block-height)
    )
    (map-set farmer-reputation farmer
      {
        reliability-score: u50,
        tasks-completed: u0,
        tasks-failed: u0,
        last-updated: current-block,
        participation-count: u0
      }
    )
    (ok true)
  )
)

;; Get a farmer's reputation profile
(define-read-only (get-farmer-reputation (farmer principal))
  (map-get? farmer-reputation farmer)
)

;; Get a rating submitted by one farmer for another
(define-read-only (get-farmer-rating (rater principal) (rated principal))
  (map-get? farmer-ratings { rater: rater, rated: rated })
)

;; Calculate average reliability score from recent ratings
;; Returns average rating or 0 if no ratings exist
(define-read-only (get-average-rating (farmer principal))
  (let
    (
      (default-rep { reliability-score: u0, tasks-completed: u0, tasks-failed: u0, last-updated: u0, participation-count: u0 })
      (rep-data (default-to default-rep (map-get? farmer-reputation farmer)))
    )
    (if (> (get participation-count rep-data) u0)
      (/ (get reliability-score rep-data) (get participation-count rep-data))
      u0
    )
  )
)

(define-private (get-total-shares (coop-id uint))
  (fold calculate-total-shares (list tx-sender) u0)
)

(define-private (calculate-total-shares (member principal) (acc uint))
  (match (map-get? coop-members { coop-id: u1, member: member })
    member-data (+ acc (get shares member-data))
    acc
  )
)

(define-data-var equipment-contract-owner principal tx-sender)
(define-constant BPS u10000)
(define-constant SPLIT u5000)
(define-constant ERR_UNAUTH u300)
(define-constant ERR_NOT_FOUND_EQ u301)
(define-constant ERR_EXISTS_EQ u302)
(define-constant ERR_BAD_STATUS u303)
(define-constant ERR_NOT_MEMBER_EQ u304)
(define-constant ERR_COOP_INACTIVE u305)
(define-constant ERR_SLOT_CLOSED u306)
(define-constant ERR_STX u307)
(define-map equipment-coops uint {treasury: principal, fee-bps: uint, active: bool})
(define-map equipment-member-coop principal uint)
(define-data-var next-eq-id uint u1)
(define-map eqs uint {owner: principal, coop-id: uint, rate: uint, period: uint, status: uint, name: (string-ascii 48)})
(define-map slots {eq-id: uint, slot-id: uint} bool)
(define-data-var next-book-id uint u1)
(define-map books uint {eq-id: uint, slot-id: uint, renter: principal, owner: principal, owner-coop: uint, renter-coop: uint, amount: uint, status: uint})
(define-map escrows uint uint)
(define-map reps principal {done: uint, cancel: uint, score: uint})
(define-constant EQ_ACTIVE u1)
(define-constant EQ_INACTIVE u2)
(define-constant BK_PENDING u1)
(define-constant BK_ACCEPTED u2)
(define-constant BK_LIVE u3)
(define-constant BK_RETURNED u4)
(define-constant BK_VERIFIED u5)
(define-constant BK_CANCELED u6)
(define-public (create-equipment-coop (id uint) (treasury principal) (fee-bps uint) (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get equipment-contract-owner)) ERR_UNAUTH)
    (match (map-get? equipment-coops id)
      (some val) (err ERR_EXISTS_EQ)
      none (begin (map-set equipment-coops id {treasury:treasury, fee-bps:fee-bps, active:active}) (ok true))))
(define-public (set-equipment-coop-active (id uint) (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get equipment-contract-owner)) ERR_UNAUTH)
    (match (map-get? equipment-coops id)
      c (begin (map-set equipment-coops id {treasury:(get treasury c), fee-bps:(get fee-bps c), active:active}) (ok true))
      none (err ERR_NOT_FOUND_EQ))))
(define-public (join-equipment-coop (coop-id uint))
  (match (map-get? equipment-coops coop-id)
    c (if (get active c)
           (begin (map-set equipment-member-coop tx-sender coop-id) (ok true))
           (err ERR_COOP_INACTIVE))
    none (err ERR_NOT_FOUND_EQ)))
(define-public (list-equipment (name (string-ascii 48)) (rate uint) (period uint))
  (match (map-get? equipment-member-coop tx-sender)
    cid (let ((new-id (var-get next-eq-id)))
         (begin
           (map-set eqs new-id {owner:tx-sender, coop-id:cid, rate:rate, period:period, status:EQ_ACTIVE, name:name})
           (var-set next-eq-id (+ new-id u1))
           (ok new-id)))
    none (err ERR_NOT_MEMBER_EQ)))
(define-public (set-eq-status (eq-id uint) (status uint))
  (match (map-get? eqs eq-id)
    e (if (is-eq (get owner e) tx-sender)
           (begin (map-set eqs eq-id {owner:(get owner e), coop-id:(get coop-id e), rate:(get rate e), period:(get period e), status:status, name:(get name e)}) (ok true))
           (err ERR_UNAUTH))
    none (err ERR_NOT_FOUND_EQ)))
(define-public (set-slot (eq-id uint) (slot-id uint) (open bool))
  (match (map-get? eqs eq-id)
    e (if (is-eq (get owner e) tx-sender)
           (begin (map-set slots {eq-id:eq-id, slot-id:slot-id} open) (ok true))
           (err ERR_UNAUTH))
    none (err ERR_NOT_FOUND_EQ)))
(define-public (request-book (eq-id uint) (slot-id uint) (amount uint))
  (let ((e (map-get? eqs eq-id)) (s (map-get? slots {eq-id:eq-id, slot-id:slot-id})))
    (match e
      eq (if (is-eq (get status eq) EQ_ACTIVE)
              (match s
                sl (if (get open sl)
                        (match (map-get? equipment-member-coop tx-sender)
                          rc (let ((bid (var-get next-book-id)) (owner (get owner eq)) (oc (get coop-id eq)))
                               (begin
                                 (map-set books {id:bid} {eq-id:eq-id, slot-id:slot-id, renter:tx-sender, owner:owner, owner-coop:oc, renter-coop:rc, amount:amount, status:BK_PENDING})
                                 (var-set next-book-id (+ bid u1))
                                 (asserts! (is-ok (stx-transfer? amount tx-sender (as-contract tx-sender))) ERR_STX)
                                 (map-set escrows {id:bid} {amt:amount})
                                 (map-set slots {eq-id:eq-id, slot-id:slot-id} {open:false})
                                 (ok bid)))
                          none (err ERR_NOT_MEMBER_EQ))
                        (err ERR_SLOT_CLOSED))
                none (err ERR_NOT_FOUND_EQ))
             (err ERR_BAD_STATUS))
      none (err ERR_NOT_FOUND_EQ))))
(define-public (accept-book (booking-id uint))
  (match (map-get? books booking-id)
    b (if (is-eq (get owner b) tx-sender)
           (if (is-eq (get status b) BK_PENDING)
               (begin (map-set books {id:booking-id} {eq-id:(get eq-id b), slot-id:(get slot-id b), renter:(get renter b), owner:(get owner b), owner-coop:(get owner-coop b), renter-coop:(get renter-coop b), amount:(get amount b), status:BK_ACCEPTED}) (ok true))
               (err ERR_BAD_STATUS))
           (err ERR_UNAUTH))
    none (err ERR_NOT_FOUND_EQ)))
(define-public (start-book (booking-id uint))
  (match (map-get? books booking-id)
    b (if (or (is-eq (get owner b) tx-sender) (is-eq (get renter b) tx-sender))
           (if (is-eq (get status b) BK_ACCEPTED)
               (begin (map-set books {id:booking-id} {eq-id:(get eq-id b), slot-id:(get slot-id b), renter:(get renter b), owner:(get owner b), owner-coop:(get owner-coop b), renter-coop:(get renter-coop b), amount:(get amount b), status:BK_LIVE}) (ok true))
               (err ERR_BAD_STATUS))
           (err ERR_UNAUTH))
    none (err ERR_NOT_FOUND_EQ)))
(define-public (return-book (booking-id uint))
  (match (map-get? books booking-id)
    b (if (is-eq (get renter b) tx-sender)
           (if (is-eq (get status b) BK_LIVE)
               (begin (map-set books {id:booking-id} {eq-id:(get eq-id b), slot-id:(get slot-id b), renter:(get renter b), owner:(get owner b), owner-coop:(get owner-coop b), renter-coop:(get renter-coop b), amount:(get amount b), status:BK_RETURNED}) (ok true))
               (err ERR_BAD_STATUS))
           (err ERR_UNAUTH))
    none (err ERR_NOT_FOUND_EQ)))
(define-private (payout (amt uint) (to principal))
  (stx-transfer? amt (as-contract tx-sender) to))
(define-private (upd-rep (u principal) (d-inc uint) (c-inc uint))
  (let ((r (map-get? reps u)))
    (match r
      x (begin (map-set reps u {done:(+ (get done x) d-inc), cancel:(+ (get cancel x) c-inc), score:(+ (get score x) d-inc)}) (ok true))
      none (begin (map-set reps u {done:d-inc, cancel:c-inc, score:d-inc}) (ok true))))
(define-public (verify-return (booking-id uint))
  (match (map-get? books booking-id)
    b (if (is-eq (get owner b) tx-sender)
           (if (is-eq (get status b) BK_RETURNED)
               (let ((amt (default-to u0 (default-to u0 (map-get? escrows booking-id)))) (oc (get owner-coop b)) (rc (get renter-coop b)))
                 (match (map-get? equipment-coops oc)
                   co (let ((fee-bps (get fee-bps co)) (owner-fee-share (/ (* amt fee-bps) BPS)) (owner-coop-share (/ (* owner-fee-share SPLIT) BPS)) (renter-coop-share (- owner-fee-share owner-coop-share)) (to-owner (- amt owner-fee-share)))
                         (begin
                           (asserts! (is-ok (payout to-owner (get owner b))) ERR_STX)
                           (asserts! (is-ok (payout owner-coop-share (get treasury co))) ERR_STX)
                           (match (map-get? equipment-coops rc)
                             rcx (asserts! (is-ok (payout renter-coop-share (get treasury rcx))) ERR_STX)
                             none (ok true))
                           (map-delete escrows {id:booking-id})
                           (map-set books booking-id {eq-id:(get eq-id b), slot-id:(get slot-id b), renter:(get renter b), owner:(get owner b), owner-coop:(get owner-coop b), renter-coop:(get renter-coop b), amount:(get amount b), status:BK_VERIFIED})
                           (unwrap-panic (upd-rep (get renter b) u1 u0))
                           (unwrap-panic (upd-rep (get owner b) u1 u0))
                           (ok true)))
                   none (err ERR_NOT_FOUND_EQ)))
               (err ERR_BAD_STATUS))
           (err ERR_UNAUTH))
    none (err ERR_NOT_FOUND_EQ)))
(define-public (cancel-book (booking-id uint))
  (match (map-get? books booking-id)
    b (if (is-eq (get renter b) tx-sender)
           (if (is-eq (get status b) BK_PENDING)
               (let ((amt (default-to u0 (map-get? escrows booking-id))) (eq-id (get eq-id b)) (slot-id (get slot-id b)))
                 (begin
                   (asserts! (is-ok (stx-transfer? amt (as-contract tx-sender) tx-sender)) ERR_STX)
                   (map-delete escrows booking-id)
                   (map-set books booking-id {eq-id:eq-id, slot-id:slot-id, renter:(get renter b), owner:(get owner b), owner-coop:(get owner-coop b), renter-coop:(get renter-coop b), amount:(get amount b), status:BK_CANCELED})
                   (map-set slots {eq-id:eq-id, slot-id:slot-id} {open:true})
                   (unwrap-panic (upd-rep (get renter b) u0 u1))
                   (ok true)))
               (err ERR_BAD_STATUS))
           (err ERR_UNAUTH))
    none (err ERR_NOT_FOUND_EQ)))
(define-read-only (get-equipment (eq-id uint))
  (map-get? eqs eq-id))
(define-read-only (get-slot (eq-id uint) (slot-id uint))
  (map-get? slots {eq-id:eq-id, slot-id:slot-id}))
(define-read-only (get-booking (booking-id uint))
  (map-get? books booking-id))
(define-read-only (get-reputation (user principal))
  (map-get? reps user))

;; FARMER REPUTATION AND RELIABILITY SCORING SYSTEM
;; Tracks farmer performance metrics including completed tasks, reliability score, and participation history

;; Initialize a farmer's reputation profile with default values
;; Initial reliability score starts at 50 (medium)
(define-public (initialize-farmer-reputation (farmer principal))
  (let
    (
      (current-block stacks-block-height)
    )
    (map-set farmer-reputation farmer
      {
        reliability-score: u50,
        tasks-completed: u0,
        tasks-failed: u0,
        last-updated: current-block,
        participation-count: u0
      }
    )
    (ok true)
  )
)

;; Record a successfully completed task for a farmer
;; Increases reliability score by 5 points and increments task counter
(define-public (record-task-completion (farmer principal))
  (let
    (
      (current-block stacks-block-height)
      (rep-data (default-to 
        { reliability-score: u50, tasks-completed: u0, tasks-failed: u0, last-updated: current-block, participation-count: u0 }
        (map-get? farmer-reputation farmer)
      ))
    )
    
    (map-set farmer-reputation farmer
      {
        reliability-score: (+ (get reliability-score rep-data) u5),
        tasks-completed: (+ (get tasks-completed rep-data) u1),
        tasks-failed: (get tasks-failed rep-data),
        last-updated: current-block,
        participation-count: (+ (get participation-count rep-data) u1)
      }
    )
    (ok true)
  )
)

;; Record a failed or incomplete task for a farmer
;; Decreases reliability score by 3 points and increments failure counter
(define-public (record-task-failure (farmer principal))
  (let
    (
      (current-block stacks-block-height)
      (rep-data (default-to 
        { reliability-score: u50, tasks-completed: u0, tasks-failed: u0, last-updated: current-block, participation-count: u0 }
        (map-get? farmer-reputation farmer)
      ))
      (new-score (if (>= (get reliability-score rep-data) u3) (- (get reliability-score rep-data) u3) u0))
    )
    
    (map-set farmer-reputation farmer
      {
        reliability-score: new-score,
        tasks-completed: (get tasks-completed rep-data),
        tasks-failed: (+ (get tasks-failed rep-data) u1),
        last-updated: current-block,
        participation-count: (+ (get participation-count rep-data) u1)
      }
    )
    (ok true)
  )
)

;; Submit a rating for another farmer (1-10 scale)
;; One rating per rater-rated pair; updates existing rating if already rated
(define-public (submit-farmer-rating (rated-farmer principal) (rating uint) (comment (string-ascii 200)))
  (let
    (
      (current-block stacks-block-height)
    )
    (asserts! (and (>= rating u1) (<= rating u10)) ERR_INVALID_SCORE)
    (asserts! (not (is-eq tx-sender rated-farmer)) ERR_UNAUTHORIZED)
    
    (map-set farmer-ratings { rater: tx-sender, rated: rated-farmer }
      {
        rating: rating,
        comment: comment,
        timestamp: current-block
      }
    )
    (ok true)
  )
)

;; Get a farmer's current reputation profile
;; Returns None if the farmer has no profile yet
(define-read-only (get-farmer-reputation (farmer principal))
  (map-get? farmer-reputation farmer)
)

;; Get a rating submitted by one farmer for another
;; Returns None if no rating exists between the two farmers
(define-read-only (get-farmer-rating (rater principal) (rated principal))
  (map-get? farmer-ratings { rater: rater, rated: rated })
)

;; Calculate average reliability score for a farmer
;; Returns the reliability score divided by participation count
;; Returns 0 if no participation yet
(define-read-only (get-average-reliability-score (farmer principal))
  (let
    (
      (default-rep { reliability-score: u0, tasks-completed: u0, tasks-failed: u0, last-updated: u0, participation-count: u0 })
      (rep-data (default-to default-rep (map-get? farmer-reputation farmer)))
    )
    (if (> (get participation-count rep-data) u0)
      (/ (get reliability-score rep-data) (get participation-count rep-data))
      u0
    )
  )
)

;; Calculate success rate for a farmer
;; Returns tasks completed / total tasks, or 0 if no tasks
(define-read-only (get-farmer-success-rate (farmer principal))
  (let
    (
      (default-rep { reliability-score: u0, tasks-completed: u0, tasks-failed: u0, last-updated: u0, participation-count: u0 })
      (rep-data (default-to default-rep (map-get? farmer-reputation farmer)))
      (total-tasks (+ (get tasks-completed rep-data) (get tasks-failed rep-data)))
    )
    (if (> total-tasks u0)
      (/ (* (get tasks-completed rep-data) u100) total-tasks)
      u0
    )
  )
)
