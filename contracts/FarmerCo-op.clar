(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_VOTING_CLOSED (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_NOT_MEMBER (err u106))
(define-constant ERR_INVALID_AMOUNT (err u107))

(define-data-var coop-id-counter uint u0)
(define-data-var proposal-id-counter uint u0)

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

(define-private (get-total-shares (coop-id uint))
  (fold calculate-total-shares (list tx-sender) u0)
)

(define-private (calculate-total-shares (member principal) (acc uint))
  (match (map-get? coop-members { coop-id: u1, member: member })
    member-data (+ acc (get shares member-data))
    acc
  )
)
