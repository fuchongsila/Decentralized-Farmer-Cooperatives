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
(define-constant ERR_MILESTONE_NOT_FOUND (err u211))
(define-constant ERR_PROJECT_NOT_FOUND (err u212))
(define-constant ERR_MILESTONE_COMPLETED (err u213))
(define-constant ERR_NOT_PROJECT_OWNER (err u214))
(define-constant ERR_MILESTONE_NOT_COMPLETED (err u215))
(define-constant ERR_ALREADY_RELEASED (err u216))
(define-constant ERR_PROJECT_CLOSED (err u217))

(define-data-var coop-id-counter uint u0)
(define-data-var proposal-id-counter uint u0)
(define-data-var claim-id-counter uint u0)
(define-data-var project-id-counter uint u0)
(define-data-var milestone-id-counter uint u0)

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

(define-map funded-projects
  uint
  {
    coop-id: uint,
    project-owner: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    total-budget: uint,
    total-milestones: uint,
    completed-milestones: uint,
    released-amount: uint,
    is-active: bool,
    created-at: uint
  }
)

(define-map project-milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    budget: uint,
    is-completed: bool,
    is-approved: bool,
    is-released: bool,
    completion-date: uint,
    approval-votes: uint,
    rejection-votes: uint,
    voting-end: uint
  }
)

(define-map milestone-votes
  { project-id: uint, milestone-id: uint, voter: principal }
  { approved: bool, voting-power: uint }
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
  (let
    ((existing (map-get? equipment-coops id)))
    (begin
      (asserts! (is-eq tx-sender (var-get equipment-contract-owner)) (err ERR_UNAUTH))
      (asserts! (is-none existing) (err ERR_EXISTS_EQ))
      (map-set equipment-coops id {treasury:treasury, fee-bps:fee-bps, active:active})
      (ok true)
    )
  )
)
(define-public (set-equipment-coop-active (id uint) (active bool))
  (let
    ((coop-data (unwrap! (map-get? equipment-coops id) (err ERR_NOT_FOUND_EQ))))
    (begin
      (asserts! (is-eq tx-sender (var-get equipment-contract-owner)) (err ERR_UNAUTH))
      (map-set equipment-coops id {treasury:(get treasury coop-data), fee-bps:(get fee-bps coop-data), active:active})
      (ok true)
    )
  )
)
(define-public (join-equipment-coop (coop-id uint))
  (let
    ((coop-data (unwrap! (map-get? equipment-coops coop-id) (err ERR_NOT_FOUND_EQ))))
    (if (get active coop-data)
      (begin (map-set equipment-member-coop tx-sender coop-id) (ok true))
      (err ERR_COOP_INACTIVE)
    )
  )
)
(define-public (list-equipment (name (string-ascii 48)) (rate uint) (period uint))
  (let
    ((cid (unwrap! (map-get? equipment-member-coop tx-sender) (err ERR_NOT_MEMBER_EQ)))
     (new-id (var-get next-eq-id)))
    (begin
      (map-set eqs new-id {owner:tx-sender, coop-id:cid, rate:rate, period:period, status:EQ_ACTIVE, name:name})
      (var-set next-eq-id (+ new-id u1))
      (ok new-id)
    )
  )
)
(define-public (set-eq-status (eq-id uint) (status uint))
  (let
    ((e (unwrap! (map-get? eqs eq-id) (err ERR_NOT_FOUND_EQ))))
    (if (is-eq (get owner e) tx-sender)
      (begin (map-set eqs eq-id {owner:(get owner e), coop-id:(get coop-id e), rate:(get rate e), period:(get period e), status:status, name:(get name e)}) (ok true))
      (err ERR_UNAUTH)
    )
  )
)
(define-public (set-slot (eq-id uint) (slot-id uint) (open bool))
  (let
    ((e (unwrap! (map-get? eqs eq-id) (err ERR_NOT_FOUND_EQ))))
    (if (is-eq (get owner e) tx-sender)
      (begin (map-set slots {eq-id:eq-id, slot-id:slot-id} open) (ok true))
      (err ERR_UNAUTH)
    )
  )
)
(define-public (request-book (eq-id uint) (slot-id uint) (amount uint))
  (let
    ((eq (unwrap! (map-get? eqs eq-id) (err ERR_NOT_FOUND_EQ)))
     (sl (unwrap! (map-get? slots {eq-id:eq-id, slot-id:slot-id}) (err ERR_NOT_FOUND_EQ)))
     (rc (unwrap! (map-get? equipment-member-coop tx-sender) (err ERR_NOT_MEMBER_EQ)))
     (bid (var-get next-book-id))
     (owner (get owner eq))
     (oc (get coop-id eq)))
    (begin
      (asserts! (is-eq (get status eq) EQ_ACTIVE) (err ERR_BAD_STATUS))
      (asserts! sl (err ERR_SLOT_CLOSED))
      (map-set books bid {eq-id:eq-id, slot-id:slot-id, renter:tx-sender, owner:owner, owner-coop:oc, renter-coop:rc, amount:amount, status:BK_PENDING})
      (var-set next-book-id (+ bid u1))
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set escrows bid amount)
      (map-set slots {eq-id:eq-id, slot-id:slot-id} false)
      (ok bid)
    )
  )
)
(define-public (accept-book (booking-id uint))
  (let
    ((b (unwrap! (map-get? books booking-id) (err ERR_NOT_FOUND_EQ))))
    (begin
      (asserts! (is-eq (get owner b) tx-sender) (err ERR_UNAUTH))
      (asserts! (is-eq (get status b) BK_PENDING) (err ERR_BAD_STATUS))
      (map-set books booking-id {eq-id:(get eq-id b), slot-id:(get slot-id b), renter:(get renter b), owner:(get owner b), owner-coop:(get owner-coop b), renter-coop:(get renter-coop b), amount:(get amount b), status:BK_ACCEPTED})
      (ok true)
    )
  )
)
(define-public (start-book (booking-id uint))
  (let
    ((b (unwrap! (map-get? books booking-id) (err ERR_NOT_FOUND_EQ))))
    (begin
      (asserts! (or (is-eq (get owner b) tx-sender) (is-eq (get renter b) tx-sender)) (err ERR_UNAUTH))
      (asserts! (is-eq (get status b) BK_ACCEPTED) (err ERR_BAD_STATUS))
      (map-set books booking-id {eq-id:(get eq-id b), slot-id:(get slot-id b), renter:(get renter b), owner:(get owner b), owner-coop:(get owner-coop b), renter-coop:(get renter-coop b), amount:(get amount b), status:BK_LIVE})
      (ok true)
    )
  )
)
(define-public (return-book (booking-id uint))
  (let
    ((b (unwrap! (map-get? books booking-id) (err ERR_NOT_FOUND_EQ))))
    (begin
      (asserts! (is-eq (get renter b) tx-sender) (err ERR_UNAUTH))
      (asserts! (is-eq (get status b) BK_LIVE) (err ERR_BAD_STATUS))
      (map-set books booking-id {eq-id:(get eq-id b), slot-id:(get slot-id b), renter:(get renter b), owner:(get owner b), owner-coop:(get owner-coop b), renter-coop:(get renter-coop b), amount:(get amount b), status:BK_RETURNED})
      (ok true)
    )
  )
)
(define-private (payout (amt uint) (to principal))
  (stx-transfer? amt (as-contract tx-sender) to))
(define-private (upd-rep (u principal) (d-inc uint) (c-inc uint))
  (let ((r (default-to {done: u0, cancel: u0, score: u0} (map-get? reps u))))
    (begin
      (map-set reps u {
        done: (+ (get done r) d-inc),
        cancel: (+ (get cancel r) c-inc),
        score: (+ (get score r) d-inc)
      })
      (ok true)
    )
  )
)
(define-public (verify-return (booking-id uint))
  (let
    ((b (unwrap! (map-get? books booking-id) (err ERR_NOT_FOUND_EQ)))
     (amt (default-to u0 (map-get? escrows booking-id)))
     (oc (get owner-coop b))
     (rc (get renter-coop b))
     (co (unwrap! (map-get? equipment-coops oc) (err ERR_NOT_FOUND_EQ)))
     (fee-bps (get fee-bps co))
     (owner-fee-share (/ (* amt fee-bps) BPS))
     (owner-coop-share (/ (* owner-fee-share SPLIT) BPS))
     (renter-coop-share (- owner-fee-share owner-coop-share))
     (to-owner (- amt owner-fee-share)))
    (begin
      (asserts! (is-eq (get owner b) tx-sender) (err ERR_UNAUTH))
      (asserts! (is-eq (get status b) BK_RETURNED) (err ERR_BAD_STATUS))
      (try! (payout to-owner (get owner b)))
      (try! (payout owner-coop-share (get treasury co)))
      (match (map-get? equipment-coops rc)
        rcx (try! (payout renter-coop-share (get treasury rcx)))
        true
      )
      (map-delete escrows booking-id)
      (map-set books booking-id {eq-id:(get eq-id b), slot-id:(get slot-id b), renter:(get renter b), owner:(get owner b), owner-coop:(get owner-coop b), renter-coop:(get renter-coop b), amount:(get amount b), status:BK_VERIFIED})
      (unwrap-panic (upd-rep (get renter b) u1 u0))
      (unwrap-panic (upd-rep (get owner b) u1 u0))
      (ok true)
    )
  )
)
(define-public (cancel-book (booking-id uint))
  (let
    ((b (unwrap! (map-get? books booking-id) (err ERR_NOT_FOUND_EQ)))
     (amt (default-to u0 (map-get? escrows booking-id)))
     (eq-id (get eq-id b))
     (slot-id (get slot-id b)))
    (begin
      (asserts! (is-eq (get renter b) tx-sender) (err ERR_UNAUTH))
      (asserts! (is-eq (get status b) BK_PENDING) (err ERR_BAD_STATUS))
      (try! (as-contract (stx-transfer? amt tx-sender tx-sender)))
      (map-delete escrows booking-id)
      (map-set books booking-id {eq-id:eq-id, slot-id:slot-id, renter:(get renter b), owner:(get owner b), owner-coop:(get owner-coop b), renter-coop:(get renter-coop b), amount:(get amount b), status:BK_CANCELED})
      (map-set slots {eq-id:eq-id, slot-id:slot-id} true)
      (unwrap-panic (upd-rep (get renter b) u0 u1))
      (ok true)
    )
  )
)
(define-read-only (get-equipment (eq-id uint))
  (map-get? eqs eq-id))
(define-read-only (get-slot (eq-id uint) (slot-id uint))
  (map-get? slots {eq-id:eq-id, slot-id:slot-id}))
(define-read-only (get-booking (booking-id uint))
  (map-get? books booking-id))
(define-read-only (get-reputation (user principal))
  (map-get? reps user)
)

(define-public (create-funded-project 
  (coop-id uint) 
  (title (string-ascii 100)) 
  (description (string-ascii 500)) 
  (total-budget uint)
  (total-milestones uint))
  (let
    (
      (member-data (unwrap! (map-get? coop-members { coop-id: coop-id, member: tx-sender }) ERR_NOT_MEMBER))
      (resources (unwrap! (map-get? coop-resources coop-id) ERR_NOT_FOUND))
      (new-project-id (+ (var-get project-id-counter) u1))
      (current-block stacks-block-height)
    )
    (asserts! (get is-active member-data) ERR_NOT_MEMBER)
    (asserts! (> total-budget u0) ERR_INVALID_AMOUNT)
    (asserts! (> total-milestones u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (get available-funds resources) total-budget) ERR_INSUFFICIENT_FUNDS)
    (map-set coop-resources coop-id
      (merge resources { available-funds: (- (get available-funds resources) total-budget) })
    )
    (map-set funded-projects new-project-id
      {
        coop-id: coop-id,
        project-owner: tx-sender,
        title: title,
        description: description,
        total-budget: total-budget,
        total-milestones: total-milestones,
        completed-milestones: u0,
        released-amount: u0,
        is-active: true,
        created-at: current-block
      }
    )
    (var-set project-id-counter new-project-id)
    (ok new-project-id)
  )
)

(define-public (add-project-milestone
  (project-id uint)
  (description (string-ascii 200))
  (budget uint))
  (let
    (
      (project-data (unwrap! (map-get? funded-projects project-id) ERR_PROJECT_NOT_FOUND))
      (current-block stacks-block-height)
      (new-milestone-id (+ (var-get milestone-id-counter) u1))
      (voting-end (+ current-block u144))
    )
    (asserts! (is-eq tx-sender (get project-owner project-data)) ERR_NOT_PROJECT_OWNER)
    (asserts! (get is-active project-data) ERR_PROJECT_CLOSED)
    (asserts! (> budget u0) ERR_INVALID_AMOUNT)
    (map-set project-milestones { project-id: project-id, milestone-id: new-milestone-id }
      {
        description: description,
        budget: budget,
        is-completed: false,
        is-approved: false,
        is-released: false,
        completion-date: u0,
        approval-votes: u0,
        rejection-votes: u0,
        voting-end: voting-end
      }
    )
    (var-set milestone-id-counter new-milestone-id)
    (ok new-milestone-id)
  )
)

(define-public (submit-milestone-completion
  (project-id uint)
  (milestone-id uint))
  (let
    (
      (project-data (unwrap! (map-get? funded-projects project-id) ERR_PROJECT_NOT_FOUND))
      (milestone-data (unwrap! (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get project-owner project-data)) ERR_NOT_PROJECT_OWNER)
    (asserts! (get is-active project-data) ERR_PROJECT_CLOSED)
    (asserts! (not (get is-completed milestone-data)) ERR_MILESTONE_COMPLETED)
    (map-set project-milestones { project-id: project-id, milestone-id: milestone-id }
      (merge milestone-data 
        {
          is-completed: true,
          completion-date: current-block
        }
      )
    )
    (ok true)
  )
)

(define-public (vote-on-milestone
  (project-id uint)
  (milestone-id uint)
  (approve bool))
  (let
    (
      (project-data (unwrap! (map-get? funded-projects project-id) ERR_PROJECT_NOT_FOUND))
      (milestone-data (unwrap! (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (member-data (unwrap! (map-get? coop-members { coop-id: (get coop-id project-data), member: tx-sender }) ERR_NOT_MEMBER))
      (current-block stacks-block-height)
      (existing-vote (map-get? milestone-votes { project-id: project-id, milestone-id: milestone-id, voter: tx-sender }))
    )
    (asserts! (get is-active member-data) ERR_NOT_MEMBER)
    (asserts! (get is-completed milestone-data) ERR_MILESTONE_NOT_COMPLETED)
    (asserts! (< current-block (get voting-end milestone-data)) ERR_VOTING_CLOSED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (let ((voting-power (get shares member-data)))
      (map-set milestone-votes { project-id: project-id, milestone-id: milestone-id, voter: tx-sender }
        { approved: approve, voting-power: voting-power }
      )
      (map-set project-milestones { project-id: project-id, milestone-id: milestone-id }
        (merge milestone-data
          {
            approval-votes: (if approve (+ (get approval-votes milestone-data) voting-power) (get approval-votes milestone-data)),
            rejection-votes: (if approve (get rejection-votes milestone-data) (+ (get rejection-votes milestone-data) voting-power))
          }
        )
      )
    )
    (ok true)
  )
)

(define-public (release-milestone-payment
  (project-id uint)
  (milestone-id uint))
  (let
    (
      (project-data (unwrap! (map-get? funded-projects project-id) ERR_PROJECT_NOT_FOUND))
      (milestone-data (unwrap! (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (get is-active project-data) ERR_PROJECT_CLOSED)
    (asserts! (get is-completed milestone-data) ERR_MILESTONE_NOT_COMPLETED)
    (asserts! (not (get is-released milestone-data)) ERR_ALREADY_RELEASED)
    (asserts! (>= current-block (get voting-end milestone-data)) ERR_VOTING_CLOSED)
    (asserts! (> (get approval-votes milestone-data) (get rejection-votes milestone-data)) ERR_CLAIM_NOT_APPROVED)
    (try! (as-contract (stx-transfer? (get budget milestone-data) tx-sender (get project-owner project-data))))
    (map-set project-milestones { project-id: project-id, milestone-id: milestone-id }
      (merge milestone-data 
        {
          is-approved: true,
          is-released: true
        }
      )
    )
    (map-set funded-projects project-id
      (merge project-data
        {
          completed-milestones: (+ (get completed-milestones project-data) u1),
          released-amount: (+ (get released-amount project-data) (get budget milestone-data))
        }
      )
    )
    (ok (get budget milestone-data))
  )
)

(define-public (close-project (project-id uint))
  (let
    (
      (project-data (unwrap! (map-get? funded-projects project-id) ERR_PROJECT_NOT_FOUND))
      (remaining-budget (- (get total-budget project-data) (get released-amount project-data)))
      (resources (unwrap! (map-get? coop-resources (get coop-id project-data)) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get project-owner project-data)) ERR_NOT_PROJECT_OWNER)
    (asserts! (get is-active project-data) ERR_PROJECT_CLOSED)
    (if (> remaining-budget u0)
      (map-set coop-resources (get coop-id project-data)
        (merge resources { available-funds: (+ (get available-funds resources) remaining-budget) })
      )
      true
    )
    (map-set funded-projects project-id
      (merge project-data { is-active: false })
    )
    (ok remaining-budget)
  )
)

(define-read-only (get-funded-project (project-id uint))
  (map-get? funded-projects project-id)
)

(define-read-only (get-project-milestone (project-id uint) (milestone-id uint))
  (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-vote (project-id uint) (milestone-id uint) (voter principal))
  (map-get? milestone-votes { project-id: project-id, milestone-id: milestone-id, voter: voter })
)

(define-read-only (get-project-progress (project-id uint))
  (match (map-get? funded-projects project-id)
    project-data (ok {
      completed: (get completed-milestones project-data),
      total: (get total-milestones project-data),
      released: (get released-amount project-data),
      budget: (get total-budget project-data),
      percentage: (if (> (get total-milestones project-data) u0)
        (/ (* (get completed-milestones project-data) u100) (get total-milestones project-data))
        u0)
    })
    ERR_PROJECT_NOT_FOUND
  )
)
